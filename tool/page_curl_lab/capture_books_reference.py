#!/usr/bin/env python3
"""通过本机 Appium/WDA 自动采集 Books 翻页与取消；私有画面只写入仓库外。"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request


class Appium:
    def __init__(self, url):
        self.url = url.rstrip('/')
        self.session = None

    def request(self, method, path, data=None):
        request = urllib.request.Request(
            self.url + path, method=method,
            data=None if data is None else json.dumps(data).encode(),
            headers={'Content-Type': 'application/json'},
        )
        try:
            with urllib.request.urlopen(request, timeout=240) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            result = json.load(error)
        value = result.get('value')
        if isinstance(value, dict) and value.get('error'):
            raise RuntimeError(value.get('message', value['error']))
        return value

    def command(self, method, path, data=None):
        return self.request(method, '/session/' + self.session + path, data)

    def execute(self, name, arguments=None):
        return self.command('POST', '/execute/sync', {
            'script': 'mobile: ' + name, 'args': [arguments or {}],
        })

    def screenshot(self, path):
        data = base64.b64decode(self.command('GET', '/screenshot'), validate=True)
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError('The screenshot response is not a PNG')
        path.write_bytes(data)
        return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--appium-url', default='http://127.0.0.1:4731')
    session = parser.add_mutually_exclusive_group(required=True)
    session.add_argument('--session-id', help='复用现有会话，不在结束时关闭它')
    session.add_argument('--capabilities', type=Path, help='在仓库外保存的 Appium capabilities JSON')
    parser.add_argument('--output', type=Path, required=True, help='仓库外的新目录')
    parser.add_argument('--fps', type=int, default=30, metavar='1..60')
    args = parser.parse_args()
    if not 1 <= args.fps <= 60:
        parser.error('FPS must be between 1 and 60')
    url = urllib.parse.urlparse(args.appium_url)
    if url.scheme not in ('http', 'https') or url.hostname not in ('127.0.0.1', 'localhost', '::1'):
        parser.error('Use a local Appium server; private book images must stay on this Mac')
    repository = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output == repository or repository in output.parents:
        parser.error('Private screenshots, recordings and capabilities must stay outside the repository')
    if args.capabilities:
        capabilities_path = args.capabilities.resolve()
        if capabilities_path == repository or repository in capabilities_path.parents:
            parser.error('Keep device identifiers and signing configuration outside the repository')
        capabilities = json.loads(capabilities_path.read_text())
        # 验证结束后保留 Books，不重置已有书库或测试书的阅读设置。
        capabilities.update({
            'appium:bundleId': 'com.apple.iBooks',
            'appium:noReset': True,
            'appium:shouldTerminateApp': False,
        })
    output.mkdir(parents=True, exist_ok=False)
    client = Appium(args.appium_url)
    report = {'status': 'failed', 'fps_requested': args.fps, 'actions': []}
    recording = False
    owned_session = False
    try:
        if args.session_id:
            client.session = args.session_id
        else:
            result = client.request('POST', '/session', {
                'capabilities': {'alwaysMatch': capabilities},
            })
            client.session = result['sessionId']
            owned_session = True
        client.execute('activateApp', {'bundleId': 'com.apple.iBooks'})
        rect = client.command('GET', '/window/rect')
        width, height = rect['width'], rect['height']
        report['viewport'] = {'width': width, 'height': height}

        def point(x, y):
            return {'x': round(width * x), 'y': round(height * y)}

        def screenshot(name):
            time.sleep(1)
            return client.screenshot(output / (name + '.png'))

        if client.execute('getXCTestScreenRecordingInfo') is not None:
            raise RuntimeError('An existing recording is active; leave it untouched')
        metadata = client.execute('startXCTestScreenRecording', {'fps': args.fps})
        recording = True
        report['fps'] = metadata.get('fps')
        before = screenshot('before-forward')
        start, destination = point(0.956, 0.867), point(0.123, 0.764)
        poses = [
            {
                axis: int(start[axis] + (destination[axis] - start[axis]) * fraction + 0.5)
                for axis in ('x', 'y')
            }
            for fraction in (0.25, 0.5, 0.75, 1.0)
        ]
        actions = [
            {'type': 'pointerMove', 'duration': 0, **start},
            {'type': 'pointerDown', 'button': 0},
        ]
        for pose in poses:
            actions.extend([
                {'type': 'pointerMove', 'duration': 1300, **pose},
                # 中间 pause 会被 XCTest 跨越插值；重复坐标保留停驻关键帧。
                {'type': 'pointerMove', 'duration': 2200, **pose},
            ])
        actions.append({'type': 'pointerUp', 'button': 0})
        watch = time.monotonic()
        client.command('POST', '/actions', {'actions': [{
            'type': 'pointer', 'id': 'finger',
            'parameters': {'pointerType': 'touch'}, 'actions': actions,
        }]})
        report['forward_trace'] = {
            'origin': start, 'poses': poses,
            'move_ms': 1300, 'hold_ms': 2200,
            'hold_method': 'same-coordinate-pointerMove',
        }
        report['actions'].append({'action': 'forward', 'duration_s': time.monotonic() - watch})
        after_forward = screenshot('after-forward')

        # 返回起点再抬手，避免仅用短距离松手被速度阈值判为完成翻页。
        turn = point(0.654, 0.764)
        actions = [
            {'type': 'pointerMove', 'duration': 0, **start},
            {'type': 'pointerDown', 'button': 0},
            {'type': 'pointerMove', 'duration': 100, **start},
            {'type': 'pointerMove', 'duration': 1600, **turn},
            # XCTest 会跨 pause 插值；同坐标关键帧才保留实际停驻。
            {'type': 'pointerMove', 'duration': 700, **turn},
            {'type': 'pointerMove', 'duration': 1600, **start},
            {'type': 'pointerMove', 'duration': 700, **start},
            {'type': 'pointerUp', 'button': 0},
        ]
        watch = time.monotonic()
        client.command('POST', '/actions', {'actions': [{
            'type': 'pointer', 'id': 'finger',
            'parameters': {'pointerType': 'touch'}, 'actions': actions,
        }]})
        report['actions'].append({'action': 'cancel-return', 'duration_s': time.monotonic() - watch})
        after_cancel = screenshot('after-cancel')
        report['forward_frame_changed'] = before != after_forward
        report['cancel_frame_restored'] = after_forward == after_cancel
        # 这只验证画面变化与恢复；页码和中途纸面仍需检查截图/视频，不冒充语义断言。
        if not report['forward_frame_changed'] or not report['cancel_frame_restored']:
            raise RuntimeError('Frame checks failed; inspect the recording and screenshots')
        report['status'] = 'passed'
    except Exception as error:
        report['error'] = str(error)
    finally:
        if recording:
            try:
                movie = client.execute('stopXCTestScreenRecording')
                # 兼容旧版字符串响应，以及新版包含 payload 和元数据的响应。
                payload = movie if isinstance(movie, str) else movie['payload']
                data = base64.b64decode(payload, validate=True)
                if len(data) < 1024 or data[4:8] != b'ftyp':
                    raise ValueError('The recording response is not a usable movie')
                (output / 'forward-cancel.mov').write_bytes(data)
                report['recording_bytes'] = len(data)
            except Exception as error:
                report.update(status='failed', recording_error=str(error))
        if owned_session:
            try:
                client.command('DELETE', '')
            except Exception as error:
                report.update(status='failed', cleanup_error=str(error))
        (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Books reference capture: ' + report['status'])
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
