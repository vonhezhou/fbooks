#!/usr/bin/env python3
"""只在已准备的独立 macOS 宿主运行翻页对照；输入、截图和日志留在仓库外。"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid


def validate_host(host, repository):
    host, repository = Path(host).resolve(), Path(repository).resolve()
    if host == repository or repository in host.parents:
        raise ValueError('The host must be outside the repository')
    if not re.search(r'^name:\s*page_curl_(?:metal|device)_lab\s*$',
                     (host / 'pubspec.yaml').read_text(), re.MULTILINE):
        raise ValueError('Expected a dedicated page curl lab package')
    expected = (repository / 'tool/page_curl_lab/main.dart').as_uri()
    if expected not in (host / 'lib/main.dart').read_text():
        raise ValueError('The entrypoint does not reference this prototype')
    return host


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--lab-directory', required=True)
    parser.add_argument('--mode', choices=['benchmark', 'smoke', 'preview'], default='benchmark')
    for kind in ['epub', 'cbz', 'pdf']:
        parser.add_argument('--' + kind, required=True)
    parser.add_argument('--output')
    parser.add_argument('--renderer', choices=['auto', 'metal-compare', 'compare', 'metal', 'mesh', 'shader'],
                        default='auto')
    args = parser.parse_args()
    if args.mode == 'smoke' and args.renderer not in ['auto', 'mesh', 'shader', 'metal-compare']:
        parser.error('Smoke checks support auto, mesh, shader, or metal-compare')
    if not args.flutter:
        parser.error('Pass --flutter')
    repository = Path(__file__).resolve().parents[2]
    try:
        host = validate_host(args.lab_directory, repository)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    output = Path(args.output or tempfile.mkdtemp(prefix='fbooks-metal-macos-')).resolve()
    if output == repository or repository in output.parents:
        parser.error('Private input, screenshot and log output must be outside the repository')
    output.mkdir(parents=True, exist_ok=True)
    inputs = output / 'inputs'
    inputs.mkdir(exist_ok=True)
    for kind in ['epub', 'cbz', 'pdf']:
        source = Path(getattr(args, kind)).resolve()
        if not source.is_file():
            parser.error('Each readable input file is required')
        target = inputs / ('input.' + kind)
        if source != target:
            shutil.copyfile(source, target)
    capture = output / 'capture'
    run_id = str(uuid.uuid4())
    command = [args.flutter, 'drive' if args.mode == 'smoke' else 'run', '--profile', '--no-pub', '-d', 'macos']
    if args.mode == 'smoke':
        smoke_target = 'metal_smoke_test.dart' if args.renderer.startswith('metal') else 'page_curl_smoke_test.dart'
        command += ['--driver=test_driver/integration_test.dart', '--target=integration_test/' + smoke_target,
                    '--dart-define=CURL_SMOKE_RUN_ID=' + run_id,
                    '--dart-define=CURL_METAL_SMOKE_OUTPUT=' + str(capture),
                    '--dart-define=CURL_SMOKE_OUTPUT=' + str(capture),
                    '--dart-define=CURL_KEEP_VISIBLE=true',
                    '--dart-define=CURL_METAL_KEEP_VISIBLE=true']
    else:
        command += ['--target=lib/main.dart']
    command += ['--dart-define=CURL_RENDERER=' + args.renderer, '--dart-define=CURL_CAPTURE=false',
                '--dart-define=CURL_RUN_ID=' + run_id]
    for kind in ['epub', 'cbz', 'pdf']:
        command.append('--dart-define=CURL_' + kind.upper() + '_PATH=' + str(inputs / ('input.' + kind)))
    if args.mode == 'benchmark':
        command += ['--dart-define=CURL_BENCH=true', '--dart-define=CURL_BENCH_WIDTH=1000',
                    '--dart-define=CURL_BENCH_HEIGHT=600', '--dart-define=CURL_OUTPUT=' + str(capture)]
    environment = dict(os.environ)
    environment.setdefault('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn')
    collected = False
    with (output / 'console.log').open('w') as log:
        process = subprocess.Popen(command, cwd=host, env=environment, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 600
            while process.poll() is None:
                if args.mode != 'preview' and time.monotonic() > deadline:
                    raise RuntimeError('Dedicated lab run exceeded its build/test bound')
                if args.mode == 'smoke':
                    try:
                        report = json.loads((capture / 'results.json').read_text())
                    except (OSError, ValueError):
                        report = {}
                    if report.get('run_id') == run_id and report.get('status') in ['passed', 'failed']:
                        (capture / 'collected').touch()
                        collected = True
                time.sleep(.5)
            if process.returncode:
                raise RuntimeError('Dedicated lab failed; private logs retained')
            if args.mode == 'preview':
                return
            report = json.loads((capture / 'results.json').read_text())
            if args.mode == 'smoke':
                assert collected and report['status'] == 'passed' and len(report['cases']) == 6
            else:
                assert report['run_id'] == run_id and report['mode'] == 'profile'
                expected_renderers = ({'mesh', 'metal'} if args.renderer == 'metal-compare' else
                                      {'mesh', 'shader'} if args.renderer == 'compare' else {'mesh'} if args.renderer == 'auto' else {args.renderer})
                assert len(report['results']) == 6 * len(expected_renderers)
                assert {r['renderer'] for r in report['results']} == expected_renderers
                assert all(r['initial_preparation']['source_is_real'] and r['effective_logical_scale'] == 1
                           for r in report['results'])
            print('Dedicated macOS ' + args.mode + ' passed', flush=True)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()


if __name__ == '__main__':
    main()
