#!/usr/bin/env python3
"""生成独立的临时 Flutter 宿主，不改仓库平台文件或覆盖正式 App。"""
import argparse
from pathlib import Path
import shutil
import re
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Flutter is not on PATH; pass --flutter /path/to/flutter')
    root = Path(tempfile.mkdtemp(prefix='fbooks-curl-simulator-'))
    subprocess.run([args.flutter, 'create', '--no-pub', '--platforms=android,ios',
                    '--org', 'com.github.vonhezhou.pagecurl',
                    '--project-name', 'page_curl_device_lab', str(root)], check=True)
    repository = Path(__file__).resolve().parents[2]
    # html 0.15.7 移除了 flutter_html 仍在使用的选择器 API；复用正式工程锁定版本。
    html_version = re.search(r'(?ms)^  html:.*?^    version: "([^"]+)"',
                             (repository / 'pubspec.lock').read_text()).group(1)
    (root / 'pubspec.yaml').write_text('''name: page_curl_device_lab
version: 1.0.0+1
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  fbooks:
    path: {repository}
  path_provider: ^2.1.5
  html: {html_version}
  pdfrx: 2.4.8
  window_manager: 0.5.2
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
flutter:
  uses-material-design: true
  shaders:
    - tool/page_curl_lab/shaders/curl.frag
'''.replace('{repository}', str(repository)).replace('{html_version}', html_version))
    shader = Path(__file__).resolve().parent / 'shaders/curl.frag'
    destination = root / 'tool/page_curl_lab/shaders/curl.frag'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(shader, destination)
    # 仅独立测试 App 的前台窗口保持亮屏，不修改设备全局休眠设置。
    activity = root / 'android/app/src/main/kotlin/com/github/vonhezhou/pagecurl/page_curl_device_lab/MainActivity.kt'
    activity.write_text("""package com.github.vonhezhou.pagecurl.page_curl_device_lab

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
""")
    source = Path(__file__).resolve().with_name('main.dart').as_uri()
    (root / 'lib/main.dart').write_text(
        f"import '{source}' as lab;\nFuture<void> main() => lab.main();\n")
    # 计数器模板不再对应替换后的入口；宿主使用下面的专用集成测试。
    (root / 'test/widget_test.dart').unlink(missing_ok=True)
    smoke = Path(__file__).resolve().with_name('simulator_smoke.dart.source').read_text()
    for placeholder, name in [('__LAB_MAIN_URI__', 'main.dart'),
                              ('__LAB_PAINTER_URI__', 'curl_shader_painter.dart'),
                              ('__LAB_MESH_URI__', 'curl_painter.dart'),
                              ('__LAB_SOURCES_URI__', 'page_sources.dart'),
                              ('__LAB_REAL_URI__', 'real_page_source.dart')]:
        smoke = smoke.replace(placeholder, Path(__file__).resolve().with_name(name).as_uri())
    (root / 'integration_test').mkdir()
    (root / 'integration_test/page_curl_smoke_test.dart').write_text(smoke)
    bidirectional = Path(__file__).resolve().with_name('bidirectional_smoke.dart.source').read_text()
    for placeholder, name in [('__LAB_MAIN_URI__', 'main.dart'),
                              ('__LAB_MESH_URI__', 'curl_painter.dart'),
                              ('__LAB_GEOMETRY_URI__', 'curl_geometry.dart'),
                              ('__LAB_DRAG_URI__', 'curl_drag.dart')]:
        bidirectional = bidirectional.replace(placeholder, Path(__file__).resolve().with_name(name).as_uri())
    (root / 'integration_test/bidirectional_smoke_test.dart').write_text(bidirectional)

    subprocess.run([args.flutter, 'pub', 'get', '--offline'], cwd=root, check=True)
    print(f'LAB_DIRECTORY={root}', flush=True)
    print('Run from this directory: flutter run -d <simulator-id> '
          '--dart-define=CURL_SIMULATOR=true --dart-define=CURL_BENCH=true')


if __name__ == '__main__':
    main()
