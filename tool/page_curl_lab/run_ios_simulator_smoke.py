#!/usr/bin/env python3
"""在指定的专用 iOS 模拟器运行独立宿主；实书和截图只进入私有测试目录。"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

BUNDLE = 'com.github.vonhezhou.pagecurl.pageCurlDeviceLab'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--lab-directory', required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--epub', required=True)
    parser.add_argument('--cbz', required=True)
    parser.add_argument('--pdf', required=True)
    parser.add_argument('--output')
    parser.add_argument('--renderer', choices=['mesh', 'shader'], default='shader')
    args = parser.parse_args()
    inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True))
    booted = {device['udid'] for devices in inventory['devices'].values() for device in devices
              if device.get('state') == 'Booted' and device.get('isAvailable', True)}
    if args.device not in booted:
        parser.error('Pass the UDID of a booted iOS simulator')
    inputs = {extension: Path(getattr(args, extension)) for extension in ('epub', 'cbz', 'pdf')}
    if not all(path.is_file() for path in inputs.values()):
        parser.error('All three readable input files are required')
    destination = Path(args.output or tempfile.mkdtemp(prefix='fbooks-ios-smoke-'))
    repository = Path(__file__).resolve().parents[2]
    if destination.resolve() == repository or repository in destination.resolve().parents:
        parser.error('Private screenshots and console logs must be written outside the repository')
    destination.mkdir(parents=True, exist_ok=True)
    run_id = str(uuid.uuid4())
    command = [args.flutter, 'test', '--no-pub', '-d', args.device,
               'integration_test/page_curl_smoke_test.dart', '--enable-impeller',
               '--dart-define=CURL_RENDERER=' + args.renderer, '--dart-define=CURL_SIMULATOR=true',
               '--dart-define=CURL_INPUT_DOCUMENTS=true', '--dart-define=CURL_SMOKE_RUN_ID=' + run_id]
    environment = dict(os.environ)
    environment.setdefault('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn')
    collected = False
    seeded = set()
    deadline = time.monotonic() + 600
    with (destination / 'console.log').open('w') as log:
        process = subprocess.Popen(command, cwd=args.lab_directory, env=environment,
                                   stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                if time.monotonic() > deadline:
                    raise RuntimeError('Simulator smoke run exceeded ten minutes including build')
                container = subprocess.run(['xcrun', 'simctl', 'get_app_container', args.device, BUNDLE, 'data'],
                                           capture_output=True, text=True)
                if container.returncode == 0:
                    root = Path(container.stdout.strip())
                    if root not in seeded:
                        documents = root / 'Documents'
                        documents.mkdir(exist_ok=True)
                        # 测试进程可能已经启动，先写临时文件再原子替换，避免读取半个 ZIP。
                        for extension, source in inputs.items():
                            temporary = documents / ('input.' + extension + '.partial')
                            shutil.copyfile(source, temporary)
                            temporary.replace(documents / ('input.' + extension))
                        seeded.add(root)
                    report_directory = root / 'tmp/curl-simulator-smoke'
                    report = report_directory / 'results.json'
                    try:
                        data = json.loads(report.read_text())
                    except (OSError, ValueError):
                        data = {}
                    if data.get('run_id') == run_id and data.get('status') in ('passed', 'failed') and not collected:
                        shutil.copytree(report_directory, destination / 'capture', dirs_exist_ok=True)
                        (report_directory / 'collected').touch()
                        collected = True
                        print('Collected simulator report: ' + data['status'], flush=True)
                time.sleep(.5)
            if process.returncode != 0:
                raise RuntimeError('Integration test failed; inspect the private console log and report')
            if not collected:
                raise RuntimeError('Test exited without an acknowledged simulator report')
            result = json.loads((destination / 'capture/results.json').read_text())
            if result.get('status') != 'passed' or len(result.get('cases', [])) != 6:
                raise RuntimeError('Expected six passing real-book/layout cases')
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
            # 只停止调用者指定的独立 App，不关闭模拟器或其他应用。
            subprocess.run(['xcrun', 'simctl', 'terminate', args.device, BUNDLE], capture_output=True)
    print('Six simulator cases passed; results saved to private output directory', flush=True)


if __name__ == '__main__':
    main()
