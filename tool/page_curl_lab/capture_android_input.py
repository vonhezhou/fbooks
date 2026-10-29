#!/usr/bin/env python3
"""向独立 Android 测试 App 注入手势并读取完整 JSON，避免 logcat 截断。"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--adb', required=True)
    parser.add_argument('--device', default='emulator-5554')
    parser.add_argument('--allow-physical', action='store_true')
    parser.add_argument('--log', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--renderer', choices=['mesh', 'shader'])
    parser.add_argument('--wake-device', action='store_true')
    args = parser.parse_args()
    if not args.device.startswith('emulator-') and not args.allow_physical:
        parser.error('Pass --allow-physical to explicitly target a physical device')
    command = [args.adb, '-s', args.device]
    package = 'com.github.vonhezhou.pagecurl.page_curl_device_lab'
    log = Path(args.log)

    def wait_for(marker, seconds):
        deadline = time.monotonic() + seconds
        while marker not in (log.read_text() if log.exists() else ''):
            if time.monotonic() > deadline:
                raise RuntimeError(f'Missing {marker}; inspect {log}')
            time.sleep(0.25)

    wait_for('A Dart VM Service', 60)
    if args.wake_device:
        # 等待测试 Activity 启动后再唤醒，避免安装期间回到锁屏而无法采样。
        subprocess.run(command + ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'], check=True)
        subprocess.run(command + ['shell', 'wm', 'dismiss-keyguard'], check=True)
    wait_for('CURL_INPUT_READY', 60)
    service = re.search(r'A Dart VM Service.*?(http://[^\s]+)', log.read_text()).group(1)

    def rpc(method, parameters=None):
        with urllib.request.urlopen(service + method + '?' + urllib.parse.urlencode(parameters or {}), timeout=10) as response:
            data = json.load(response)
        if 'error' in data:
            raise RuntimeError(data['error'])
        return data['result']

    isolate = rpc('getVM')['isolates'][0]['id']

    def status(**parameters):
        return rpc('ext.curl.status', {'isolateId': isolate, **parameters})

    if args.renderer:
        current = status(renderer=args.renderer)
        if current.get('renderer') != args.renderer or current.get('error'):
            raise RuntimeError(f'Renderer switch failed: {current}')

    if args.wake_device:
        # READY 可能先于锁屏退出；确认测试窗口已连续获得焦点再注入输入。
        deadline = time.monotonic() + 10
        focused_samples = 0
        while focused_samples < 2:
            window = subprocess.check_output(command + ['shell', 'dumpsys', 'window'], text=True)
            focus = re.search(r'mCurrentFocus=.*', window)
            focused = focus is not None and package in focus.group(0)
            unlocked = 'mDreamingLockscreen=true' not in window
            focused_samples = focused_samples + 1 if focused and unlocked else 0
            if time.monotonic() > deadline:
                raise RuntimeError('Test app did not get foreground focus after wake')
            time.sleep(.1)

    display = subprocess.check_output(command + ['shell', 'wm', 'size'], text=True)
    width, height = map(int, re.findall(r'(\d+)x(\d+)', display)[-1])
    right, left, y = int(width * .88), int(width * .17), int(height * .60)
    gestures = [(right, left, page) for page in range(1, 6)] + [
        (left, right, 4), (left, right, 3), (right, int(width * .79), 3)]
    for start, end, page in gestures:
        subprocess.run(command + ['shell', 'input', 'swipe', str(start), str(y),
                                  str(end), str(y), '700'], check=True)
        deadline = time.monotonic() + 10
        while True:
            current = status()
            if current['error']:
                raise RuntimeError(current['error'])
            if current['ready'] and current['page_start'] == page:
                break
            if time.monotonic() > deadline:
                raise RuntimeError(f'Expected page {page + 1}, got {current}')
            time.sleep(.1)
    time.sleep(1.1)  # 等待批量 FrameTiming 回调交付，不改变手势结果。
    status(finish='true')
    wait_for('CURL_INPUT_COMPLETE', 40)
    raw = subprocess.check_output(command + ['exec-out', 'run-as', package,
                                           'cat', 'code_cache/fbooks-page-curl-v2/input.json'])
    data = json.loads(raw)
    if data['page_start'] != 3 or data['input']['pointer_moves'] == 0:
        raise RuntimeError('Expected page 4 and nonempty input samples')
    if not all(s['peak_rgba_bytes'] <= s['budget_bytes'] for s in data['memory_samples']):
        raise RuntimeError('Texture budget exceeded')
    destination = Path(args.output)
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'input.json').write_bytes(raw)
    (destination / 'input-final.png').write_bytes(
        subprocess.check_output(command + ['exec-out', 'screencap', '-p']))
    print(json.dumps({'page_start': data['page_start'], 'input': data['input']}))


if __name__ == '__main__':
    main()
