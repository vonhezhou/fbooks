import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:fbooks/features/reader/presentation/comic_curl_pages.dart';
import 'package:fbooks/features/reader/presentation/page_curl/curl_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const colors = [
  Colors.black,
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.amber,
  Colors.purple,
];
ui.Image solid(Color color, [int width = 20, int height = 30]) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> decode(
  Uint8List bytes, {
  required int maxWidth,
  required int maxHeight,
}) async => solid(colors[bytes[0]]);
Future<Uint8List> read(int index) async => Uint8List.fromList([index]);
Future<List<int>> pixel(
  WidgetTester tester,
  ui.Image image,
  int x,
  int y,
) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return data!.buffer.asUint8List().sublist(
    (y * image.width + x) * 4,
    (y * image.width + x) * 4 + 4,
  );
}

List<int> rgba(Color color) => [
  color.toARGB32() >> 16 & 255,
  color.toARGB32() >> 8 & 255,
  color.toARGB32() & 255,
  255,
];

void main() {
  for (final doublePage in [false, true]) {
    testWidgets(
      'cancel disposes prepared landing image doublePage=$doublePage',
      (tester) async {
        var commits = 0;
        final pages = await prepareComicCurlPages(
          currentPage: 1,
          targetPage: doublePage ? 3 : 2,
          pageCount: 6,
          size: const Size(120, 160),
          pixelRatio: 1,
          preferences: ComicReadingPreferences(doublePage: doublePage),
          readPage: read,
          decode: decode,
          onCommitImage: (image) {
            commits++;
            image.dispose();
          },
        );
        final landing = pages.landingImage!;
        expect((landing.width, landing.height), (120, 160));
        pages.dispose();
        expect(landing.debugDisposed, isTrue);
        expect(pages.images.every((image) => image.debugDisposed), isTrue);
        expect(commits, 0);
      },
    );
  }

  testWidgets('fractional viewport and DPR keep every snapshot pixel opaque', (
    tester,
  ) async {
    final pages = await prepareComicCurlPages(
      currentPage: 1,
      targetPage: 2,
      pageCount: 4,
      size: const Size(120.3, 160.8),
      pixelRatio: 1.25,
      preferences: ComicReadingPreferences.defaults,
      readPage: read,
      decode: decode,
    );
    for (final image in pages.images) {
      final data = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final bytes = data!.buffer.asUint8List();
      expect(
        [for (var i = 3; i < bytes.length; i += 4) bytes[i]]
            .every((a) => a == 255),
        isTrue,
      );
    }
    pages.dispose();
  });

  testWidgets(
    'real codec decodes only needed pixels and preserves aspect ratio',
    (tester) async {
      final original = solid(Colors.red, 160, 400);
      final png = await tester.runAsync(
        () => original.toByteData(format: ui.ImageByteFormat.png),
      );
      original.dispose();
      final image = await tester.runAsync(
        () => decodeComicCurlImage(
          png!.buffer.asUint8List(),
          maxWidth: 40,
          maxHeight: 60,
        ),
      );
      expect((image!.width, image.height), (24, 60));
      image.dispose();
      await tester.runAsync(
        () => expectLater(
          decodeComicCurlImage(
            Uint8List.fromList([0, 1]),
            maxWidth: 40,
            maxHeight: 60,
          ),
          throwsException,
        ),
      );
    },
  );

  for (final rtl in [false, true]) {
    for (final backwards in [false, true]) {
      testWidgets('spread endpoint page order rtl=$rtl backwards=$backwards', (
        tester,
      ) async {
        ui.Image? landed;
        final pages = await prepareComicCurlPages(
          currentPage: backwards ? 3 : 1,
          targetPage: backwards ? 1 : 3,
          pageCount: 6,
          size: const Size(120, 160),
          pixelRatio: 1,
          preferences: ComicReadingPreferences(
            doublePage: true,
            mode: rtl
                ? ComicReadingMode.rightToLeft
                : ComicReadingMode.leftToRight,
          ),
          readPage: read,
          decode: decode,
          onCommitImage: (image) => landed = image,
        );
        expect(pages.spread, isTrue);
        expect(pages.images, hasLength(4));
        expect(pages.paperBounds!.height, lessThan(160));
        for (final progress in [0.0, 1.0]) {
          final recorder = ui.PictureRecorder();
          CurlPainter(
            images: pages.images,
            progress: progress,
            spread: true,
            rtl: rtl,
            opaquePages: true,
          ).paint(Canvas(recorder), const Size(120, 160));
          final picture = recorder.endRecording();
          final image = picture.toImageSync(120, 160);
          picture.dispose();
          final first = progress == 0 ? 1 : 3;
          expect(
            await pixel(tester, image, 30, 80),
            rgba(colors[rtl ? first + 1 : first]),
          );
          expect(
            await pixel(tester, image, 90, 80),
            rgba(colors[rtl ? first : first + 1]),
          );
          image.dispose();
        }
        pages.onCommit!();
        expect(landed!.isCloneOf(pages.landingImage!), isTrue);
        pages.dispose();
        expect(pages.landingImage!.debugDisposed, isTrue);
        expect(landed!.debugDisposed, isFalse);
        expect(pages.images.every((i) => i.debugDisposed), isTrue);
        expect((landed!.width, landed!.height), (120, 160));
        final target = backwards ? 1 : 3;
        expect(
          await pixel(tester, landed!, 30, 80),
          rgba(colors[rtl ? target + 1 : target]),
        );
        expect(await pixel(tester, landed!, 0, 0), [17, 17, 17, 255]);
        landed!.dispose();
      });
    }
  }

  testWidgets(
    'cover and trailing single page keep whole-page fitting and landing ownership',
    (tester) async {
      ui.Image? landing;
      final pages = await prepareComicCurlPages(
        currentPage: 0,
        targetPage: 1,
        pageCount: 4,
        size: const Size(120, 160),
        pixelRatio: 1,
        preferences: const ComicReadingPreferences(doublePage: true),
        readPage: read,
        decode: decode,
        onCommitImage: (image) => landing = image,
      );
      expect(pages.spread, isFalse);
      expect(landing, isNull);
      pages.onCommit!();
      expect(landing!.isCloneOf(pages.landingImage!), isTrue);
      pages.dispose();
      expect(landing!.debugDisposed, isFalse);
      expect(await pixel(tester, landing!, 30, 80), rgba(Colors.red));
      expect(await pixel(tester, landing!, 90, 80), rgba(Colors.green));
      landing!.dispose();
      final trailing = await prepareComicCurlPages(
        currentPage: 1,
        targetPage: 3,
        pageCount: 4,
        size: const Size(120, 160),
        pixelRatio: 1,
        preferences: const ComicReadingPreferences(doublePage: true),
        readPage: read,
        decode: decode,
      );
      expect(trailing.spread, isFalse);
      trailing.dispose();
    },
  );

  testWidgets(
    'failed target decoding releases decoded images and never commits',
    (tester) async {
      final owned = <ui.Image>[];
      var commits = 0;
      await expectLater(
        prepareComicCurlPages(
          currentPage: 0,
          targetPage: 1,
          pageCount: 3,
          size: const Size(120, 160),
          pixelRatio: 1,
          preferences: ComicReadingPreferences.defaults,
          readPage: read,
          decode: (bytes, {required maxWidth, required maxHeight}) async {
            if (bytes[0] == 1) throw StateError('Decode unavailable');
            final image = solid(Colors.red);
            owned.add(image);
            return image;
          },
          onCommitImage: (_) => commits++,
        ),
        throwsStateError,
      );
      expect(owned, isNotEmpty);
      expect(owned.every((i) => i.debugDisposed), isTrue);
      expect(commits, 0);
    },
  );
}
