import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/renderer_selection.dart';

void main() {
  test('iOS 和 macOS 默认网格，Android 默认 shader，未验证平台保守用网格', () {
    for (final platform in TargetPlatform.values) {
      expect(
        resolveCurlBackend(CurlRendererChoice.automatic, platform),
        platform == TargetPlatform.android
            ? CurlBackend.shader
            : CurlBackend.mesh,
      );
    }
  });

  test('用户显式选择覆盖平台默认', () {
    for (final platform in TargetPlatform.values) {
      expect(
        resolveCurlBackend(CurlRendererChoice.mesh, platform),
        CurlBackend.mesh,
      );
      expect(
        resolveCurlBackend(CurlRendererChoice.shader, platform),
        CurlBackend.shader,
      );
    }
  });
}
