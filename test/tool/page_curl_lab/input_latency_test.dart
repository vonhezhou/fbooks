import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/input_latency.dart';

FrameTiming frame(int vsync) => FrameTiming(
  frameNumber: vsync,
  vsyncStart: vsync,
  buildStart: vsync + 100,
  buildFinish: vsync + 1000,
  rasterStart: vsync + 1100,
  rasterFinish: vsync + 2000,
  rasterFinishWallTime: 1,
);

void main() {
  test('事件原点不同仍独立验证分发时钟，不校准出伪事件延迟', () {
    final probe = InputLatencyProbe();
    probe.record(const Duration(days: 1), dispatchMicros: 1000);
    probe.markPaint(1000);
    probe.frames([frame(1000)]);
    expect(probe.metrics['clock_mismatches'], 1);
    expect(probe.metrics['dispatch_clock_mismatches'], 0);
    expect((probe.metrics['event_to_raster_finish_ms']! as Map)['samples'], 0);
    expect((probe.metrics['dispatch_to_raster_finish_ms']! as Map)['p95'], 2);
    final first =
        (probe.metrics['dispatch_first_frames']! as List).single as Map;
    expect(first['dispatch_to_raster_finish_ms'], 2);
    expect(first.containsKey('event_to_raster_finish_ms'), false);
    expect(first['build_ms'], 0.9);
    expect(first['build_finish_to_raster_start_ms'], 0.1);
    expect(probe.metrics['first_frames'], isEmpty);
  });

  test('分发慢帧保留阶段和输入位置且只保存最慢的十二帧', () {
    final probe = InputLatencyProbe();
    for (var i = 1; i <= 20; i++) {
      probe.record(const Duration(days: 1), dispatchMicros: 1000);
      probe.markPaint(i, progress: 0.52, renderer: 'mesh');
      probe.frames([
        FrameTiming(
          frameNumber: i,
          vsyncStart: 1000,
          buildStart: 1100,
          buildFinish: 2100,
          rasterStart: 2200,
          rasterFinish: 22000 + i * 1000,
          rasterFinishWallTime: 1,
        ),
      ]);
    }
    final slow = probe.metrics['dispatch_slowest_frames_over_20ms']! as List;
    expect(slow.length, 12);
    expect((slow.first as Map)['pointer_move'], 20);
    expect((slow.last as Map)['pointer_move'], 9);
    expect((slow.first as Map)['dispatch_to_raster_finish_ms'], 41);
    expect((slow.first as Map)['raster_ms'], 39.8);
    expect((slow.first as Map)['renderer'], 'mesh');
    expect((slow.first as Map)['progress_at_paint'], 0.52);
    expect((probe.metrics['dispatch_first_frames']! as List).length, 12);
    expect(probe.metrics['slowest_frames_over_20ms'], isEmpty);
  });

  test('只将最新事件对应到实际绘制帧，不把合并事件当作额外样本', () {
    final probe = InputLatencyProbe();
    probe.record(const Duration(microseconds: 500));
    probe.record(const Duration(microseconds: 800));
    probe.markPaint(1000);
    probe.frames([frame(1000)]);
    expect(probe.metrics['coalesced_moves'], 1);
    final raster = probe.metrics['event_to_raster_finish_ms']! as Map;
    expect(raster['samples'], 1);
    expect(raster['p95'], 2.2);
  });
  test('无法匹配的帧和时间原点不一致的事件不生成伪延迟', () {
    final probe = InputLatencyProbe();
    probe.record(const Duration(days: 1));
    probe.markPaint(1000);
    probe.frames([frame(2000), frame(1000)]);
    expect(probe.metrics['clock_mismatches'], 1);
    expect((probe.metrics['event_to_raster_finish_ms']! as Map)['samples'], 0);
  });
  test('长尾记录保留输入序号及实际阶段耗时，不将后续卡顿误标为首帧', () {
    final probe = InputLatencyProbe();
    probe.record(const Duration(microseconds: 800));
    probe.markPaint(1000);
    probe.frames([frame(1000)]);
    probe.record(const Duration(microseconds: 2000));
    probe.markPaint(2000, progress: 0.52, renderer: 'shader');
    probe.frames([
      FrameTiming(
        frameNumber: 2000,
        vsyncStart: 2000,
        buildStart: 2100,
        buildFinish: 3100,
        rasterStart: 3200,
        rasterFinish: 45000,
        rasterFinishWallTime: 45000,
      ),
    ]);
    final slow =
        (probe.metrics['slowest_frames_over_20ms']! as List).single as Map;
    expect(slow['pointer_move'], 2);
    expect(slow['progress_at_paint'], 0.52);
    expect(slow['renderer'], 'shader');
    expect(slow['event_to_raster_finish_ms'], 43);
    expect(slow['build_ms'], 1);
    expect(slow['raster_ms'], 41.8);
    expect((probe.metrics['first_frames']! as List).length, 2);
  });
}
