import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/metal_frame_clock.dart';

FrameTiming frame(int number, {int start = 1000, int finish = 2000}) =>
    FrameTiming(
      frameNumber: number,
      vsyncStart: 0,
      buildStart: 100,
      buildFinish: 500,
      rasterStart: start,
      rasterFinish: finish,
      rasterFinishWallTime: 1,
    );
MetalFrameClock aligned() => MetalFrameClock()
  ..observe(
    sentDart: 4000,
    receivedNative: 9100,
    sentNative: 9200,
    receivedDart: 4300,
  )
  ..observe(
    sentDart: 8000,
    receivedNative: 13010,
    sentNative: 13020,
    receivedDart: 8030,
  );

void main() {
  test('不同原点通过往返区间求交，取纹理时刻落在唯一 raster 帧内', () {
    final clock = aligned();
    final target = frame(1);
    expect(clock.valid, true);
    expect(clock.lowerOffsetUS, -5011);
    expect(clock.upperOffsetUS, -4989);
    expect(clock.metrics['uncertainty_us'], 22);
    expect(clock.frameForCopy(6500, [target]), same(target));
  });
  test('误差区间跨越 raster 边界时拒绝生成延迟', () {
    final clock = aligned();
    expect(clock.frameForCopy(6000, [frame(1)]), isNull);
  });
  test('多个候选帧或不完整校准不强行选择匹配', () {
    expect(MetalFrameClock().frameForCopy(6500, [frame(1)]), isNull);
    expect(
      aligned().frameForCopy(6500, [
        frame(1),
        frame(2, start: 1400, finish: 1600),
      ]),
      isNull,
    );
  });
  test('前后校准区间矛盾时标记失效而非伪造固定偏移', () {
    final clock = aligned()
      ..observe(
        sentDart: 12000,
        receivedNative: 21000,
        sentNative: 21010,
        receivedDart: 12030,
      );
    expect(clock.valid, false);
    expect(clock.frameForCopy(6500, [frame(1)]), isNull);
  });
  test('原生处理时间大于完整往返时间时拒绝时钟样本', () {
    final clock = MetalFrameClock()
      ..observe(
        sentDart: 100,
        receivedNative: 500,
        sentNative: 1500,
        receivedDart: 200,
      );
    expect(clock.valid, false);
    expect(clock.frameForCopy(6500, [frame(1)]), isNull);
  });
}
