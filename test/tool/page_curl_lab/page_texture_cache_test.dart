import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/page_texture_cache.dart';

Future<ui.Image> image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffeeddbb), ui.BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(8, 8);
  } finally {
    picture.dispose();
  }
}

void main() {
  test('并发相邻页请求去重，受保护页不会被 LRU 淘汰', () async {
    var loads = 0;
    final cache = PageTextureCache(
      load: (_) async {
        loads++;
        return image();
      },
      bytesPerPage: 256,
      maxBytes: 1024,
    );
    addTearDown(cache.dispose);
    final first = cache.get(0);
    final duplicate = cache.get(0);
    expect(identical(first, duplicate), true);
    await first;
    cache.pin({0});
    for (var i = 1; i < 8; i++) {
      await cache.get(i);
    }
    final before = loads;
    await cache.get(0);
    expect(loads, before);
    expect(cache.peakBytes, lessThanOrEqualTo(cache.maxBytes));
    expect(cache.evictions, 4);
  });
  test('单页两张可见纹理可在三页预算内前进和回退', () async {
    final loaded = <int>[];
    final cache = PageTextureCache(
      load: (page) async {
        loaded.add(page);
        return image();
      },
      bytesPerPage: 256,
      maxBytes: 768,
    );
    addTearDown(cache.dispose);
    cache.pin({0, 1});
    final first = await cache.get(0);
    final next = await cache.get(1);
    expect(loaded, [0, 1]);
    cache.pin({0, 1, 2});
    await cache.get(2);
    expect(identical(await cache.get(1), next), true);
    cache.pin({1, 2});
    await cache.prefetch([3]);
    expect(first.debugDisposed, true);
    expect(next.debugDisposed, false);
    cache.pin({0, 1, 2});
    await cache.get(0);
    cache.pin({0, 1});
    expect(cache.peakBytes, 768);
    expect(cache.prefetchFailures, 0);
  });
  test('两页窗口准备相邻页失败时保留原有可见纹理并允许重试', () async {
    var failNext = true;
    final cache = PageTextureCache(
      load: (page) {
        if (page == 2 && failNext) throw StateError('decode');
        return image();
      },
      bytesPerPage: 256,
      maxBytes: 768,
    );
    addTearDown(cache.dispose);
    cache.pin({0, 1});
    final first = await cache.get(0);
    final second = await cache.get(1);
    cache.pin({0, 1, 2});
    await expectLater(cache.get(2), throwsStateError);
    cache.pin({0, 1});
    expect(identical(await cache.get(0), first), true);
    expect(identical(await cache.get(1), second), true);
    expect(first.debugDisposed || second.debugDisposed, false);
    failNext = false;
    cache.pin({0, 1, 2});
    await cache.get(2);
    expect(cache.residentBytes, 768);
  });
  test('连续前进和后退维持纹理上限', () async {
    final cache = PageTextureCache(
      load: (_) => image(),
      bytesPerPage: 256,
      maxBytes: 2048,
    );
    addTearDown(cache.dispose);
    for (final anchor in [0, 2, 4, 6, 8, 10, 8, 6, 4, 2, 0]) {
      final pages = {for (var i = 0; i < 4; i++) anchor + i};
      cache.pin(pages);
      for (final page in pages) {
        await cache.get(page);
      }
      await cache.prefetch([anchor + 4, anchor + 5]);
      expect(cache.residentBytes, lessThanOrEqualTo(2048));
    }
    expect(cache.evictions, greaterThan(0));
  });
  test('解码失败不污染缓存，之后可以重试', () async {
    var fails = true;
    final cache = PageTextureCache(
      load: (_) {
        if (fails) throw StateError('decode');
        return image();
      },
      bytesPerPage: 256,
      maxBytes: 1024,
    );
    addTearDown(cache.dispose);
    await expectLater(cache.get(0), throwsStateError);
    expect(cache.residentBytes, 0);
    fails = false;
    await cache.get(0);
    expect(cache.residentBytes, 256);
    expect(cache.pendingCount, 0);
  });
  test('销毁时未完成的解码结果被释放，不重新进入缓存', () async {
    final started = Completer<void>();
    final decoded = Completer<ui.Image>();
    final cache = PageTextureCache(
      load: (_) {
        started.complete();
        return decoded.future;
      },
      bytesPerPage: 256,
      maxBytes: 1024,
    );
    final pending = cache.get(0);
    final error = expectLater(pending, throwsStateError);
    await started.future;
    cache.dispose();
    var settled = false;
    final drained = cache.settled.then((_) => settled = true);
    await Future<void>.delayed(Duration.zero);
    expect(settled, false);
    decoded.complete(await image());
    await drained;
    expect(settled, true);
    await error;
    expect(cache.residentBytes, 0);
  });
  test('超额固定页和尺寸不符的纹理明确失败', () async {
    final cache = PageTextureCache(
      load: (_) => image(),
      bytesPerPage: 512,
      maxBytes: 2048,
    );
    addTearDown(cache.dispose);
    expect(() => cache.pin({0, 1, 2, 3, 4}), throwsStateError);
    await expectLater(cache.get(0), throwsStateError);
    expect(cache.residentBytes, 0);
  });
}
