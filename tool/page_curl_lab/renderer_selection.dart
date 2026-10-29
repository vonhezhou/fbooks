import 'package:flutter/foundation.dart';

/// 可交互原型只提供这两个后端；原生 Metal 仍由显式实验参数进入。
enum CurlBackend { mesh, shader }

enum CurlRendererChoice { automatic, mesh, shader }

/// 未验证的平台保守使用网格；Android 的已测 shader 路径保留为默认。
CurlBackend defaultCurlBackend(TargetPlatform platform) =>
    platform == TargetPlatform.android ? CurlBackend.shader : CurlBackend.mesh;

CurlBackend resolveCurlBackend(
  CurlRendererChoice choice,
  TargetPlatform platform,
) => switch (choice) {
  CurlRendererChoice.automatic => defaultCurlBackend(platform),
  CurlRendererChoice.mesh => CurlBackend.mesh,
  CurlRendererChoice.shader => CurlBackend.shader,
};
