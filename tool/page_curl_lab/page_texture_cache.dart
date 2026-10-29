import 'dart:async';
import 'dart:ui' as ui;

/// 只统计 RGBA 纹理；不包含解码器、PDFium 和 GPU 驱动的额外内存。
class PageTextureCache {
  PageTextureCache({
    required this.load,
    required this.bytesPerPage,
    required this.maxBytes,
  }) {
    if (bytesPerPage <= 0 || maxBytes < bytesPerPage) {
      throw ArgumentError('The budget must hold at least one texture');
    }
  }

  final Future<ui.Image> Function(int page) load;
  final int bytesPerPage;
  final int maxBytes;
  final _images = <int, ui.Image>{};
  final _pending = <int, Future<ui.Image>>{};
  Set<int> _pinned = {};
  Future<void> _tail = Future.value();
  bool _disposed = false;
  int peakBytes = 0;
  int hits = 0;
  int misses = 0;
  int evictions = 0;
  int prefetchFailures = 0;
  int get residentBytes => _images.length * bytesPerPage;
  int get length => _images.length;
  int get pendingCount => _pending.length;
  Future<void> get settled => _tail;

  void pin(Set<int> pages) {
    if (_disposed) throw StateError('Cache disposed');
    if (pages.length * bytesPerPage > maxBytes) {
      throw StateError('Pinned pages exceed texture budget');
    }
    _pinned = {...pages};
  }

  Future<ui.Image> get(int page) {
    if (_disposed) return Future.error(StateError('Cache disposed'));
    final cached = _images.remove(page);
    if (cached != null) {
      hits++;
      _images[page] = cached;
      return Future.value(cached);
    }
    final pending = _pending[page];
    if (pending != null) return pending;
    misses++;
    final result = Completer<ui.Image>();
    _pending[page] = result.future;
    // 串行解码，避免多个相邻页同时完成时产生不可控的瞬时纹理峰值。
    _tail = _tail.then((_) async {
      try {
        if (_disposed) throw StateError('Cache disposed');
        while (residentBytes + bytesPerPage > maxBytes) {
          final candidates = _images.keys.where(
            (key) => !_pinned.contains(key),
          );
          if (candidates.isEmpty) throw StateError('No evictable texture');
          _images.remove(candidates.first)!.dispose();
          evictions++;
        }
        final image = await load(page);
        if (_disposed) {
          image.dispose();
          throw StateError('Cache disposed during decode');
        }
        if (image.width * image.height * 4 != bytesPerPage) {
          image.dispose();
          throw StateError('Decoded texture does not match reserved size');
        }
        _images[page] = image;
        if (residentBytes > peakBytes) peakBytes = residentBytes;
        result.complete(image);
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _pending.remove(page);
      }
    });
    return result.future;
  }

  Future<void> prefetch(Iterable<int> pages) async {
    for (final page in pages) {
      if (_disposed) return;
      try {
        await get(page);
      } catch (_) {
        // 后台失败保留当前页，前台再次请求时可重试；失败计数写入评估结果。
        prefetchFailures++;
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _pinned.clear();
  }

  Map<String, Object> get metrics => {
    'resident_rgba_bytes': residentBytes,
    'peak_rgba_bytes': peakBytes,
    'budget_bytes': maxBytes,
    'cached_pages': length,
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'prefetch_failures': prefetchFailures,
  };
}
