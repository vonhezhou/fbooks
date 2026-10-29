#!/usr/bin/env python3
"""为 Metal 原型准备独立 Apple 宿主；拒绝改动仓库平台工程。"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from run_metal_macos_lab import validate_host


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--platform', choices=['ios', 'macos'], required=True)
    parser.add_argument('--lab-directory')
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Pass --flutter')
    repository = Path(__file__).resolve().parents[2]
    root = Path(args.lab_directory).resolve() if args.lab_directory else Path(tempfile.mkdtemp(prefix='fbooks-metal-lab-'))
    if root == repository or repository in root.parents:
        parser.error('The dedicated host must be outside the repository')
    if args.lab_directory:
        try:
            validate_host(root, repository)
        except (OSError, ValueError) as error:
            parser.error(str(error))
    if not (root / args.platform).is_dir():
        subprocess.run([args.flutter, 'create', '--no-pub', '--platforms=' + args.platform,
                        '--org', 'com.github.vonhezhou.pagecurl', '--project-name', 'page_curl_metal_lab', str(root)], check=True)
    lab = Path(__file__).resolve().parent
    pubspec = root / 'pubspec.yaml'
    if not args.lab_directory:
        pubspec.write_text('''name: page_curl_metal_lab
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
  assets:
    - tool/page_curl_lab/metal/curl.metal
'''.replace('{repository}', str(repository)))
    else:
        spec = pubspec.read_text()
        if 'tool/page_curl_lab/metal/curl.metal' not in spec:
            spec = spec.replace('  uses-material-design: true', '  uses-material-design: true\n  assets:\n    - tool/page_curl_lab/metal/curl.metal')
            pubspec.write_text(spec)
    for name in ['shaders/curl.frag', 'metal/curl.metal']:
        target = root / 'tool/page_curl_lab' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(lab / name, target)
    runner = root / args.platform / 'Runner'
    for name in ['MetalCurlRenderer.swift', 'MetalCurlBridge.swift']:
        shutil.copyfile(lab / 'metal' / name, runner / name)
    if args.platform == 'ios':
        path = runner / 'AppDelegate.swift'
        text = path.read_text()
        if 'MetalCurlBridge.register' not in text:
            marker = 'GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)'
            if marker not in text:
                raise RuntimeError('Expected Flutter implicit-engine registration hook')
            text = text.replace(marker, marker + '\n    MetalCurlBridge.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "MetalCurlLab")!)')
        if 'isIdleTimerDisabled' not in text:
            text = text.replace('return super.application(', 'application.isIdleTimerDisabled = true\n    return super.application(')
        path.write_text(text)
    else:
        path = runner / 'MainFlutterWindow.swift'
        text = path.read_text()
        marker = 'RegisterGeneratedPlugins(registry: flutterViewController)'
        if 'MetalCurlBridge.register' not in text:
            if marker not in text:
                raise RuntimeError('Expected macOS plugin registration hook')
            text = text.replace(marker, marker + '\n    MetalCurlBridge.register(with: flutterViewController.registrar(forPlugin: "MetalCurlLab"))')
        path.write_text(text)
        # 专用宿主读取调用者提供的临时匿名输入，不改正式 App 的沙盒配置。
        import plistlib
        for name in ['DebugProfile.entitlements', 'Release.entitlements']:
            path = runner / name
            data = plistlib.loads(path.read_bytes())
            data['com.apple.security.app-sandbox'] = False
            path.write_bytes(plistlib.dumps(data))
    script = root / 'register_metal_sources.rb'
    script.write_text('''require 'xcodeproj'
p=Xcodeproj::Project.open(ARGV[0]);g=p.main_group['Runner'];t=p.targets.find{|t|t.name=='Runner'}
['MetalCurlRenderer.swift','MetalCurlBridge.swift'].each do |name|
 r=g.files.find{|r|r.path==name} || g.new_file(name)
 t.source_build_phase.add_file_reference(r) unless t.source_build_phase.files_references.include?(r)
end
p.save
''')
    subprocess.run(['ruby', str(script), str(root / args.platform / 'Runner.xcodeproj')], check=True)
    (root / 'lib/main.dart').write_text(f"import '{(lab / 'main.dart').as_uri()}' as lab;\nFuture<void> main() => lab.main();\n")
    (root / 'test/widget_test.dart').unlink(missing_ok=True)
    smoke = (lab / 'metal_smoke.dart.source').read_text()
    for placeholder, name in [('__LAB_MAIN_URI__', 'main.dart'), ('__LAB_METAL_URI__', 'metal_curl.dart'),
                              ('__LAB_SOURCES_URI__', 'page_sources.dart'), ('__LAB_REAL_URI__', 'real_page_source.dart')]:
        smoke = smoke.replace(placeholder, (lab / name).as_uri())
    (root / 'integration_test').mkdir(exist_ok=True)
    (root / 'integration_test/metal_smoke_test.dart').write_text(smoke)
    canvas_smoke = (lab / 'simulator_smoke.dart.source').read_text()
    for placeholder, name in [('__LAB_MAIN_URI__', 'main.dart'), ('__LAB_PAINTER_URI__', 'curl_shader_painter.dart'),
                              ('__LAB_MESH_URI__', 'curl_painter.dart'), ('__LAB_SOURCES_URI__', 'page_sources.dart'),
                              ('__LAB_REAL_URI__', 'real_page_source.dart')]:
        canvas_smoke = canvas_smoke.replace(placeholder, (lab / name).as_uri())
    (root / 'integration_test/page_curl_smoke_test.dart').write_text(canvas_smoke)
    (root / 'test_driver').mkdir(exist_ok=True)
    (root / 'test_driver/integration_test.dart').write_text("import 'package:integration_test/integration_test_driver.dart';\nFuture<void> main() => integrationDriver();\n")
    environment = dict(os.environ)
    environment.setdefault('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn')
    subprocess.run([args.flutter, 'pub', 'get', '--offline'], cwd=root, env=environment, check=True)
    print('LAB_DIRECTORY=' + str(root))


if __name__ == '__main__':
    main()
