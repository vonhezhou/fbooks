import 'dart:ui';

/// 用请求/回复的时间区间约束偏移，不假设原生与 Dart 共用时钟原点。
class MetalFrameClock {
  int? lowerOffsetUS;
  int? upperOffsetUS;
  int observations = 0;
  bool valid = true;

  void observe({
    required int sentDart,
    required int receivedNative,
    required int sentNative,
    required int receivedDart,
  }) {
    observations++;
    if (receivedDart < sentDart || sentNative < receivedNative) {
      valid = false;
      return;
    }
    final lower = sentDart - receivedNative - 1;
    final upper = receivedDart - sentNative + 1;
    lowerOffsetUS = lowerOffsetUS == null || lower > lowerOffsetUS!
        ? lower
        : lowerOffsetUS;
    upperOffsetUS = upperOffsetUS == null || upper < upperOffsetUS!
        ? upper
        : upperOffsetUS;
    if (lowerOffsetUS! > upperOffsetUS!) valid = false;
  }

  FrameTiming? frameForCopy(int nativeUS, List<FrameTiming> frames) {
    if (!valid || lowerOffsetUS == null || upperOffsetUS == null) return null;
    final lower = nativeUS + lowerOffsetUS!, upper = nativeUS + upperOffsetUS!;
    FrameTiming? match;
    for (final frame in frames) {
      if (frame.timestampInMicroseconds(FramePhase.rasterStart) <= lower &&
          frame.timestampInMicroseconds(FramePhase.rasterFinish) >= upper) {
        if (match != null) return null;
        match = frame;
      }
    }
    return match;
  }

  Map<String, Object?> get metrics => {
    'valid': valid,
    'observations': observations,
    'lower_offset_us': lowerOffsetUS,
    'upper_offset_us': upperOffsetUS,
    'uncertainty_us': lowerOffsetUS == null
        ? null
        : upperOffsetUS! - lowerOffsetUS!,
    'method': 'Round-trip interval intersection before/after capture; only copies whose entire uncertainty interval lies inside one raster interval are matched.',
  };
}
