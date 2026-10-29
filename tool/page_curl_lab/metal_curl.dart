import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'input_latency.dart';
import 'metal_frame_clock.dart';

/// 独立实验的纹理桥；每个窗口上传一次图片，每帧只传标量参数。
class MetalCurlController {
  MetalCurlController({
    MethodChannel? channel,
    Future<String> Function()? loadShader,
  }) : _channel = channel ?? const MethodChannel('fbooks.page_curl/metal'),
       _loadShader =
           loadShader ??
           (() => rootBundle.loadString('tool/page_curl_lab/metal/curl.metal'));

  final MethodChannel _channel;
  final Future<String> Function() _loadShader;
  int? textureId;
  int _sequence = 0;
  int _generation = 0;
  bool _closed = false;
  Future<void>? _draining;
  ({double progress, double grabY, bool spread, bool rtl})? _pending;
  ({double progress, double grabY, bool spread, bool rtl})? _lastQueued;
  Size _size = Size.zero;
  int? _inputTime;
  int coalesced = 0;
  final _readyMS = <double>[];
  final _inputReadyMS = <double>[];
  final _readyRecords = <Map<String, Object>>[];
  MetalFrameClock _clock = MetalFrameClock();
  Object? error;
  double preparationMS = 0;

  void recordInput() => _inputTime = developer.Timeline.now;

  Future<void> prepare(
    List<ui.Image> images, {
    required Size size,
    required double pixelRatio,
    required bool spread,
    required bool rtl,
    required double progress,
  }) async {
    final watch = Stopwatch()..start();
    await settled;
    if (_closed) return;
    if (textureId == null) {
      final created = await _channel.invokeMapMethod<String, Object?>(
        'create',
        {
          'source': await _loadShader(),
          'keep_visible':
              const bool.fromEnvironment('CURL_BENCH') ||
              const bool.fromEnvironment('CURL_METAL_KEEP_VISIBLE'),
        },
      );
      final id = (created!['id']! as num).toInt();
      if (_closed) {
        await _channel.invokeMethod<void>('dispose', {'id': id});
        return;
      }
      textureId = id;
    }
    if (_closed) return;
    _size = size;
    final faces = <Map<String, Object>>[];
    for (final image in images) {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      faces.add({
        'width': image.width,
        'height': image.height,
        'rgba': bytes!.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ),
      });
    }
    if (_closed) return;
    await _channel.invokeMethod<void>('pages', {
      'id': textureId,
      'width': (size.width * pixelRatio).ceil(),
      'height': (size.height * pixelRatio).ceil(),
      'faces': faces,
    });
    if (_closed) return;
    _generation++;
    _lastQueued = null;
    // 真实提交各绘制阶段后恢复端点；首次编译、纹理上传和 GPU 准备均计入准备成本。
    if (_generation == 1) {
      for (final t in [0.005, 0.52]) {
        await _render((
          progress: t,
          grabY: 0.8,
          spread: spread,
          rtl: rtl,
        ), publish: false);
      }
    }
    await _render((progress: progress, grabY: 0.8, spread: spread, rtl: rtl));
    preparationMS = watch.elapsedMicroseconds / 1000;
  }

  Future<void> _render(
    ({double progress, double grabY, bool spread, bool rtl}) p, {
    bool publish = true,
  }) async {
    if (_closed) return;
    final sequence = ++_sequence;
    final start = developer.Timeline.now;
    final input = publish ? _inputTime : null;
    if (publish) _inputTime = null;
    final reply = await _channel.invokeMapMethod<String, Object?>('render', {
      'id': textureId,
      'sequence': sequence,
      'publish': publish,
      'shape': [
        _size.width / (p.spread ? 2 : 1),
        _size.height,
        p.progress,
        p.grabY,
      ],
      'options': [p.spread ? 1.0 : 0.0, p.rtl ? 1.0 : 0.0],
    });
    if (_closed) return;
    if (reply?['accepted'] != true) {
      throw StateError('Metal renderer rejected a frame');
    }
    if (_readyMS.length < 6000) {
      final ready = developer.Timeline.now;
      final elapsed = (ready - start) / 1000;
      _readyMS.add(elapsed);
      _readyRecords.add({
        'sequence': sequence,
        'channel_to_ready_ms': elapsed,
        'request_us': start,
        'dispatch_us': ?input,
        if (input != null) 'dispatch_to_ready_ms': (ready - input) / 1000,
      });
      if (input != null) _inputReadyMS.add((ready - input) / 1000);
    }
  }

  void enqueue({
    required double progress,
    required double grabY,
    required bool spread,
    required bool rtl,
  }) {
    if (_closed || textureId == null) return;
    final p = (progress: progress, grabY: grabY, spread: spread, rtl: rtl);
    if (_lastQueued == p) return;
    _lastQueued = p;
    if (_pending != null) coalesced++;
    _pending = p;
    _draining ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null && !_closed) {
        final next = _pending!;
        _pending = null;
        await _render(next);
      }
    } catch (e) {
      error = e;
      _pending = null;
    } finally {
      _draining = null;
    }
  }

  Future<void> get settled async {
    while (_draining != null) {
      await _draining;
    }
    if (error != null) throw StateError('Metal rendering failed: $error');
  }

  Future<void> calibrateClock({bool reset = false}) async {
    if (reset) _clock = MetalFrameClock();
    for (var i = 0; i < 7; i++) {
      final sent = developer.Timeline.now;
      final native = await _channel.invokeMapMethod<String, Object?>('clock');
      final received = developer.Timeline.now;
      _clock.observe(
        sentDart: sent,
        receivedNative: (native!['received_native_us']! as num).toInt(),
        sentNative: (native['sent_native_us']! as num).toInt(),
        receivedDart: received,
      );
    }
  }

  Future<Map<String, Object?>> metrics({
    bool reset = false,
    List<ui.FrameTiming>? frames,
  }) async {
    await settled;
    if (frames != null) await calibrateClock();
    final native = await _channel.invokeMapMethod<String, Object?>('metrics', {
      'id': textureId,
      'reset': reset,
    });
    final copies = <int, double>{
      for (final value in (native?['first_copies'] as List? ?? const []))
        ((value as Map)['sequence'] as num).toInt():
            (value['ready_to_first_copy_ms'] as num).toDouble(),
    };
    final requestToCopy = <double>[];
    final dispatchToCopy = <double>[];
    for (final row in _readyRecords) {
      final copy = copies[row['sequence']];
      if (copy == null) continue;
      // 通道回复到 Dart 晚于 GPU 完成。相加得到上界，避免跨时钟原点伪校准。
      requestToCopy.add((row['channel_to_ready_ms']! as double) + copy);
      final input = row['dispatch_to_ready_ms'] as double?;
      if (input != null) dispatchToCopy.add(input + copy);
    }
    final requestRaster = <double>[], dispatchRaster = <double>[];
    final records = {for (final row in _readyRecords) row['sequence']: row};
    var unmatchedCopies = 0;
    for (final copy in (native?['first_copies'] as List? ?? const [])) {
      final value = copy as Map;
      final row = records[(value['sequence'] as num).toInt()];
      final time = value['native_copy_us'] as num?;
      final frame = time == null || frames == null
          ? null
          : _clock.frameForCopy(time.toInt(), frames);
      if (row == null || frame == null) {
        unmatchedCopies++;
        continue;
      }
      final finish = frame.timestampInMicroseconds(ui.FramePhase.rasterFinish);
      final start = row['request_us']! as int;
      if (finish < start) {
        unmatchedCopies++;
        continue;
      }
      requestRaster.add((finish - start) / 1000);
      final dispatch = row['dispatch_us'] as int?;
      if (dispatch != null && dispatch <= finish) {
        dispatchRaster.add((finish - dispatch) / 1000);
      }
    }
    final result = <String, Object?>{
      ...?native,
      'channel_to_texture_ready_ms': distribution(_readyMS),
      'dispatch_to_texture_ready_ms': distribution(_inputReadyMS),
      'request_to_flutter_copy_upper_ms': distribution(requestToCopy),
      'dispatch_to_flutter_copy_upper_ms': distribution(dispatchToCopy),
      'input_updates_without_observed_copy':
          _inputReadyMS.length - dispatchToCopy.length,
      'coalesced_updates': coalesced,
      'page_upload_and_preparation_ms': preparationMS,
      'generation': _generation,
      'clock_alignment': _clock.metrics,
      'request_to_flutter_raster_finish_ms': distribution(requestRaster),
      'dispatch_to_flutter_raster_finish_ms': distribution(dispatchRaster),
      'copies_without_unambiguous_frame': unmatchedCopies,
      'limitations': 'Texture ready is not display presentation. Copy bounds join request IDs and add two same-clock durations; they overestimate by reply delivery time and end at Flutter texture acquisition, not screen presentation. Unsampled/coalesced updates remain counted. FrameTiming covers Flutter work only.',
    };
    if (reset) {
      _readyMS.clear();
      _inputReadyMS.clear();
      _readyRecords.clear();
      coalesced = 0;
      _inputTime = null;
    }
    return result;
  }

  Future<Map<String, Object?>> snapshot() async {
    await settled;
    return (await _channel.invokeMapMethod<String, Object?>('snapshot', {
      'id': textureId,
    }))!;
  }

  Future<void> dispose() async {
    _closed = true;
    _pending = null;
    await _draining;
    if (textureId != null) {
      await _channel.invokeMethod<void>('dispose', {'id': textureId});
    }
    textureId = null;
  }
}

class MetalCurlSurface extends StatefulWidget {
  const MetalCurlSurface({
    super.key,
    required this.controller,
    required this.progress,
    required this.grabY,
    required this.spread,
    required this.rtl,
    required this.size,
  });
  final MetalCurlController controller;
  final double progress, grabY;
  final bool spread, rtl;
  final Size size;
  @override
  State<MetalCurlSurface> createState() => _MetalCurlSurfaceState();
}

class _MetalCurlSurfaceState extends State<MetalCurlSurface> {
  void _queue() => widget.controller.enqueue(
    progress: widget.progress,
    grabY: widget.grabY,
    spread: widget.spread,
    rtl: widget.rtl,
  );
  @override
  void initState() {
    super.initState();
    _queue();
  }

  @override
  void didUpdateWidget(MetalCurlSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _queue();
  }

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: widget.size,
    child: Texture(
      textureId: widget.controller.textureId!,
      filterQuality: FilterQuality.medium,
    ),
  );
}
