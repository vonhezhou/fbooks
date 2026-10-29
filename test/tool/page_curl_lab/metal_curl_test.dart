import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/metal_curl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/metal-curl');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late ui.Image image;
  setUp(() async {
    final r = ui.PictureRecorder();
    ui.Canvas(r).drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    final p = r.endRecording();
    image = await p.toImage(8, 8);
    p.dispose();
  });
  tearDown(() {
    image.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  Future<void> prepare(MetalCurlController c) => c.prepare(
    [image, image],
    size: const ui.Size(96, 128),
    pixelRatio: 2,
    spread: false,
    rtl: false,
    progress: 0,
  );
  test('预热帧不发布；单个在途更新只合并中间状态，保留最终进度', () async {
    final progress = <double>[];
    final warmPublication = <bool>[];
    final blocked = Completer<Map<String, Object>>();
    final submitted = Completer<void>();
    var hold = false;
    var disposed = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      switch (call.method) {
        case 'create':
          return {'id': 7};
        case 'render':
          if (!hold) {
            warmPublication.add(args['publish'] as bool);
            return {'accepted': true};
          }
          progress.add((args['shape'] as List)[2] as double);
          if (progress.length == 1) {
            submitted.complete();
            return blocked.future;
          }
          return {'accepted': true};
        case 'dispose':
          disposed++;
          return null;
        default:
          return null;
      }
    });
    final c = MetalCurlController(
      channel: channel,
      loadShader: () async => 'source',
    );
    await prepare(c);
    expect(warmPublication, [false, false, true]);
    hold = true;
    c.enqueue(progress: .1, grabY: .8, spread: false, rtl: false);
    await submitted.future;
    c.enqueue(progress: .2, grabY: .8, spread: false, rtl: false);
    c.enqueue(progress: .3, grabY: .8, spread: false, rtl: false);
    blocked.complete({'accepted': true});
    await c.settled;
    expect(progress, [.1, .3]);
    expect(c.coalesced, 1);
    await c.dispose();
    expect(disposed, 1);
  });
  test('创建期间关闭时释放迟到的原生纹理，不继续上传页面', () async {
    final creating = Completer<void>(),
        created = Completer<Map<String, Object>>();
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'create') {
        creating.complete();
        return created.future;
      }
      return null;
    });
    final c = MetalCurlController(
      channel: channel,
      loadShader: () async => 'source',
    );
    final pending = prepare(c);
    await creating.future;
    await c.dispose();
    created.complete({'id': 9});
    await pending;
    expect(methods, ['create', 'dispose']);
    expect(c.textureId, isNull);
  });
  test('渲染失败可见且关闭仍释放原生资源', () async {
    var failing = false;
    var disposed = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') return {'id': 7};
      if (call.method == 'render') {
        if (failing) throw PlatformException(code: 'gpu');
        return {'accepted': true};
      }
      if (call.method == 'dispose') disposed++;
      return null;
    });
    final c = MetalCurlController(
      channel: channel,
      loadShader: () async => 'source',
    );
    await prepare(c);
    failing = true;
    c.enqueue(progress: .4, grabY: .8, spread: false, rtl: false);
    await expectLater(c.settled, throwsStateError);
    await c.dispose();
    expect(disposed, 1);
  });
}
