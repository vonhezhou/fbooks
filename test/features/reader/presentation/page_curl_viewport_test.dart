import 'dart:async';
import 'dart:ui' as ui;

import 'package:fbooks/features/reader/presentation/page_curl/page_curl_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ui.Image page(Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(16, 16);
  picture.dispose();
  return image;
}

CurlTurnPages pages() =>
    CurlTurnPages(current: page(Colors.white), target: page(Colors.amber));

void main() {
  testWidgets(
    'reduced motion commits at release without a settling animation',
    (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(onTurn: turns.add, reducedMotion: true));
      final drag = await tester.startGesture(const Offset(360, 300));
      await drag.moveTo(const Offset(90, 310));
      await tester.pump();
      expect(turns, isEmpty);
      await drag.up();
      await tester.pump();
      expect(turns, [1]);
      expect(find.byKey(const Key('reader-page-curl')), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'commits only at release completion and supports backward turns',
    (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(onTurn: turns.add));
      final drag = await tester.startGesture(const Offset(360, 300));
      await drag.moveTo(const Offset(90, 310));
      await tester.pump();
      expect(find.byKey(const Key('reader-page-curl')), findsOneWidget);
      expect(turns, isEmpty);
      await drag.up();
      await tester.pump();
      expect(turns, isEmpty);
      await tester.pumpAndSettle();
      expect(turns, [1]);
      final back = await tester.startGesture(const Offset(30, 300));
      await back.moveTo(const Offset(320, 310));
      await tester.pump();
      expect(turns, [1]);
      await back.up();
      await tester.pumpAndSettle();
      expect(turns, [1, -1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pointer cancellation and short parked drag keep the source page',
    (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(onTurn: turns.add));
      final drag = await tester.startGesture(const Offset(360, 300));
      await drag.moveTo(const Offset(100, 340));
      await tester.pump();
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(turns, isEmpty);
      final short = await tester.startGesture(const Offset(360, 300));
      await short.moveTo(
        const Offset(300, 305),
        timeStamp: const Duration(milliseconds: 30),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await short.up(timeStamp: const Duration(milliseconds: 230));
      await tester.pumpAndSettle();
      expect(turns, isEmpty);
      expect(find.byKey(const Key('reader-page-curl')), findsNothing);
    },
  );

  testWidgets(
    'late loading, failed preparation and retry never commit stale pages',
    (tester) async {
      final turns = <int>[];
      final pending = Completer<CurlTurnPages?>();
      await tester.pumpWidget(
        _app(onTurn: turns.add, prepare: (_) => pending.future),
      );
      await tester.dragFrom(const Offset(360, 300), const Offset(-260, 10));
      pending.complete(pages());
      await tester.pumpAndSettle();
      expect(turns, isEmpty);
      await tester.pumpWidget(
        _app(onTurn: turns.add, prepare: (_) async => throw StateError('load')),
      );
      await tester.dragFrom(const Offset(360, 300), const Offset(-260, 10));
      await tester.pumpAndSettle();
      expect(turns, isEmpty);
      await tester.pumpWidget(_app(onTurn: turns.add));
      await tester.dragFrom(const Offset(360, 300), const Offset(-260, 10));
      await tester.pumpAndSettle();
      expect(turns, [1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('layout revision or unmount invalidates a pending turn', (
    tester,
  ) async {
    final turns = <int>[];
    await tester.pumpWidget(_app(onTurn: turns.add));
    await tester.dragFrom(const Offset(360, 300), const Offset(-260, 10));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(_app(onTurn: turns.add, revision: 1));
    await tester.pumpAndSettle();
    expect(turns, isEmpty);
    final pending = Completer<CurlTurnPages?>();
    await tester.pumpWidget(
      _app(onTurn: turns.add, prepare: (_) => pending.future),
    );
    await tester.dragFrom(const Offset(360, 300), const Offset(-260, 10));
    await tester.pumpWidget(const SizedBox());
    final latePages = pages();
    pending.complete(latePages);
    await tester.pump();
    expect(turns, isEmpty);
    expect(latePages.current.debugDisposed, isTrue);
    expect(latePages.target.debugDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a new drag takes over release and can cancel without double committing',
    (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(onTurn: turns.add));
      final first = await tester.startGesture(const Offset(360, 300));
      await first.moveTo(const Offset(170, 320));
      await tester.pump();
      await first.up();
      await tester.pump(const Duration(milliseconds: 20));
      final second = await tester.startGesture(const Offset(150, 320));
      await second.moveTo(const Offset(380, 320));
      await tester.pump();
      await second.cancel();
      await tester.pumpAndSettle();
      expect(turns, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reserves Android system back edges and keeps interior page drags',
    (tester) async {
      final turns = <int>[];
      await tester.pumpWidget(_app(onTurn: turns.add, reservedEdges: 24));
      await tester.dragFrom(const Offset(389, 300), const Offset(-280, 10));
      await tester.pumpAndSettle();
      expect(turns, isEmpty);
      await tester.dragFrom(const Offset(350, 300), const Offset(-260, 10));
      await tester.pumpAndSettle();
      expect(turns, [1]);
    },
  );
}

Widget _app({
  required ValueChanged<int> onTurn,
  Object revision = 0,
  Future<CurlTurnPages?> Function(int)? prepare,
  double reservedEdges = 0,
  bool reducedMotion = false,
}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 390,
      height: 700,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 700),
          disableAnimations: reducedMotion,
          systemGestureInsets: EdgeInsets.symmetric(horizontal: reservedEdges),
        ),
        child: PageCurlViewport(
          revision: revision,
          paperColor: Colors.white,
          prepareTurn: prepare ?? (_) async => pages(),
          onTurn: onTurn,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    ),
  ),
);
