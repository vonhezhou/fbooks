import 'dart:ui';
import 'dart:developer' as developer;

/// 软件路径指标：不包含触摸硬件采样和屏幕扫描输出。
class InputLatencyProbe {
  ({Duration eventTime, int dispatchMicros, Stopwatch receipt, int move})?
  _pending;
  final _painted =
      <
        int,
        ({
          int eventMicros,
          int dispatchMicros,
          int move,
          double dispatchMs,
          double? progress,
          String? renderer,
        })
      >{};
  final _firstFrames = <Map<String, Object>>[];
  final _slowFrames = <Map<String, Object>>[];
  final _dispatchFirstFrames = <Map<String, Object>>[];
  final _dispatchSlowFrames = <Map<String, Object>>[];
  final _dispatchToPaint = <double>[];
  final _eventToRaster = <double>[];
  final _dispatchToRaster = <double>[];
  final _clockPairs = <Map<String, int>>[];
  int dispatchClockMismatches = 0;
  int moves = 0;
  int coalesced = 0;
  int clockMismatches = 0;

  void record(Duration eventTime, {int? dispatchMicros}) {
    moves++;
    if (_pending != null) coalesced++;
    _pending = (
      eventTime: eventTime,
      dispatchMicros: dispatchMicros ?? developer.Timeline.now,
      receipt: Stopwatch()..start(),
      move: moves,
    );
  }

  void markPaint(int frameNumber, {double? progress, String? renderer}) {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    final dispatchMs = pending.receipt.elapsedMicroseconds / 1000;
    _dispatchToPaint.add(dispatchMs);
    _painted[frameNumber] = (
      eventMicros: pending.eventTime.inMicroseconds,
      dispatchMicros: pending.dispatchMicros,
      move: pending.move,
      dispatchMs: dispatchMs,
      progress: progress,
      renderer: renderer,
    );
  }

  void frames(List<FrameTiming> frames) {
    for (final frame in frames) {
      final input = _painted.remove(frame.frameNumber);
      if (input == null) continue;
      final rasterMicros = frame.timestampInMicroseconds(
        FramePhase.rasterFinish,
      );
      final dispatchElapsed = (rasterMicros - input.dispatchMicros) / 1000;
      final elapsed = (rasterMicros - input.eventMicros) / 1000;
      final dispatchValid =
          input.dispatchMicros > 0 &&
          dispatchElapsed >= 0 &&
          dispatchElapsed <= 1000;
      final eventValid =
          input.eventMicros > 0 && elapsed >= 0 && elapsed <= 1000;
      // 两个原点独立验证；事件时钟失配不能让有效的分发慢帧明细也消失。
      if (dispatchValid) {
        _dispatchToRaster.add(dispatchElapsed);
      } else {
        dispatchClockMismatches++;
      }
      if (eventValid) {
        _eventToRaster.add(elapsed);
      } else {
        clockMismatches++;
      }
      if (_clockPairs.length < 12) {
        _clockPairs.add({
          'event_us': input.eventMicros,
          'dispatch_timeline_us': input.dispatchMicros,
          'raster_finish_us': rasterMicros,
        });
      }
      final sample = <String, Object>{
        'frame_number': frame.frameNumber,
        'pointer_move': input.move,
        if (input.progress != null) 'progress_at_paint': input.progress!,
        if (input.renderer != null) 'renderer': input.renderer!,
        if (eventValid) 'event_to_raster_finish_ms': elapsed,
        if (dispatchValid) 'dispatch_to_raster_finish_ms': dispatchElapsed,
        'dispatch_to_paint_ms': input.dispatchMs,
        'build_ms': frame.buildDuration.inMicroseconds / 1000,
        'raster_ms': frame.rasterDuration.inMicroseconds / 1000,
        'build_finish_to_raster_start_ms':
            (frame.timestampInMicroseconds(FramePhase.rasterStart) -
                frame.timestampInMicroseconds(FramePhase.buildFinish)) /
            1000,
        'vsync_to_build_start_ms':
            (frame.timestampInMicroseconds(FramePhase.buildStart) -
                frame.timestampInMicroseconds(FramePhase.vsyncStart)) /
            1000,
      };
      if (eventValid) {
        _retainFrame(
          sample,
          'event_to_raster_finish_ms',
          _firstFrames,
          _slowFrames,
        );
      }
      if (dispatchValid) {
        _retainFrame(
          sample,
          'dispatch_to_raster_finish_ms',
          _dispatchFirstFrames,
          _dispatchSlowFrames,
        );
      }
    }
  }

  // 仅保留开头和最慢的各 12 帧，避免诊断记录随持续拖动增长。
  static void _retainFrame(
    Map<String, Object> sample,
    String metric,
    List<Map<String, Object>> first,
    List<Map<String, Object>> slow,
  ) {
    if (first.length < 12) first.add(sample);
    if ((sample[metric]! as double) <= 20) return;
    slow.add(sample);
    slow.sort((a, b) => (b[metric]! as double).compareTo(a[metric]! as double));
    if (slow.length > 12) slow.removeLast();
  }

  Map<String, Object> get metrics => {
    'pointer_moves': moves,
    'coalesced_moves': coalesced,
    'clock_mismatches': clockMismatches,
    'dispatch_clock_mismatches': dispatchClockMismatches,
    'clock_pairs': List.of(_clockPairs),
    'unmatched_painted_frames': _painted.length,
    'dispatch_to_paint_ms': distribution(_dispatchToPaint),
    'event_to_raster_finish_ms': distribution(_eventToRaster),
    'dispatch_to_raster_finish_ms': distribution(_dispatchToRaster),
    'dispatch_metric_excludes': 'platform input queue before Dart dispatch, compositor presentation, display scanout',
    'dispatch_first_frames': List.of(_dispatchFirstFrames),
    'dispatch_slowest_frames_over_20ms': List.of(_dispatchSlowFrames),
    'first_frames': List.of(_firstFrames),
    'slowest_frames_over_20ms': List.of(_slowFrames),
    'excludes':
        'touch hardware sampling, compositor presentation, display scanout',
  };
}

Map<String, Object> distribution(List<double> values) {
  if (values.isEmpty) return {'samples': 0};
  final sorted = [...values]..sort();
  return {
    'samples': sorted.length,
    'p50': sorted[(sorted.length * 0.5).ceil() - 1],
    'p95': sorted[(sorted.length * 0.95).ceil() - 1],
    'p99': sorted[(sorted.length * 0.99).ceil() - 1],
    'max': sorted.last,
  };
}
