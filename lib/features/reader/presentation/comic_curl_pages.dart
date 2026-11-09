import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fbooks/domain/reading/comic_reading_preferences.dart';
import 'package:fbooks/features/reader/presentation/page_curl/page_curl_viewport.dart';
import 'package:flutter/painting.dart';

typedef ComicCurlDecoder = Future<ui.Image> Function(
  Uint8List bytes, {
  required int maxWidth,
  required int maxHeight,
});

Future<ui.Image> decodeComicCurlImage(
  Uint8List bytes, {
  required int maxWidth,
  required int maxHeight,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = math.min(
      1.0,
      math.min(maxWidth / descriptor.width, maxHeight / descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

bool comicHasSpread(
  int firstPage,
  int count,
  ComicReadingPreferences preferences,
) => preferences.usesDoublePage && firstPage > 0 && firstPage + 1 < count;

List<int> comicVisiblePages(
  int firstPage,
  int count,
  ComicReadingPreferences preferences,
) => [
  firstPage,
  if (comicHasSpread(firstPage, count, preferences)) firstPage + 1,
];

// 动画仅解码视口所需像素；静止页仍由原 Image/InteractiveViewer 保留完整缩放能力。
double comicCurlPixelRatio(Size size, double pixelRatio) => math.min(
  pixelRatio,
  math.min(
    4096 / math.max(size.width, size.height),
    math.sqrt(4 * 1024 * 1024 / (size.width * size.height)),
  ),
);

Future<CurlTurnPages> prepareComicCurlPages({
  required int currentPage,
  required int targetPage,
  required int pageCount,
  required Size size,
  required double pixelRatio,
  required ComicReadingPreferences preferences,
  required Future<Uint8List> Function(int page) readPage,
  ComicCurlDecoder decode = decodeComicCurlImage,
  void Function(ui.Image image)? onCommitImage,
}) async {
  final ratio = comicCurlPixelRatio(size, pixelRatio);
  final rightToLeft = preferences.mode == ComicReadingMode.rightToLeft;
  Future<({ui.Image image, Rect bounds})> compose(int firstPage) async {
    final pages = comicVisiblePages(firstPage, pageCount, preferences);
    final order = rightToLeft ? pages.reversed.toList() : pages;
    final cellWidth = (size.width - (order.length == 2 ? 4 : 0)) / order.length;
    final decoded = <ui.Image>[];
    Rect? paper;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        (size.width * ratio).ceil() / ratio,
        (size.height * ratio).ceil() / ratio,
      ),
      Paint()
        ..color = const Color(0xff111111)
        ..isAntiAlias = false,
    );
    try {
      for (var i = 0; i < order.length; i++) {
        final image = await decode(
          await readPage(order[i]),
          maxWidth: math.max(1, (cellWidth * ratio).ceil()),
          maxHeight: math.max(1, (size.height * ratio).ceil()),
        );
        decoded.add(image);
        final source = Size(image.width.toDouble(), image.height.toDouble());
        final fitted = applyBoxFit(
          BoxFit.contain,
          source,
          Size(cellWidth, size.height),
        );
        final destination = Alignment.center.inscribe(
          fitted.destination,
          Rect.fromLTWH(i * (cellWidth + 4), 0, cellWidth, size.height),
        );
        paper = paper?.expandToInclude(destination) ?? destination;
        canvas.drawImageRect(
          image,
          Offset.zero & source,
          destination,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final picture = recorder.endRecording();
      try {
        return (
          image: picture.toImageSync(
            (size.width * ratio).ceil(),
            (size.height * ratio).ceil(),
          ),
          bounds: paper!,
        );
      } finally {
        picture.dispose();
      }
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      for (final image in decoded) {
        image.dispose();
      }
    }
  }

  List<ui.Image> split(ui.Image image) {
    final halves = <ui.Image>[];
    try {
      final leftWidth = image.width ~/ 2;
      for (final rect in [
        Rect.fromLTWH(0, 0, leftWidth.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          leftWidth.toDouble(),
          0,
          (image.width - leftWidth).toDouble(),
          image.height.toDouble(),
        ),
      ]) {
        final recorder = ui.PictureRecorder();
        Canvas(recorder)
            .drawImageRect(image, rect, Offset.zero & rect.size, Paint());
        final picture = recorder.endRecording();
        try {
          halves.add(
            picture.toImageSync(rect.width.toInt(), rect.height.toInt()),
          );
        } finally {
          picture.dispose();
        }
      }
      return rightToLeft ? halves.reversed.toList() : halves;
    } catch (_) {
      for (final half in halves) {
        half.dispose();
      }
      rethrow;
    }
  }

  ui.Image crop(ui.Image image, Rect pixels) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
        .drawImageRect(image, pixels, Offset.zero & pixels.size, Paint());
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(pixels.width.toInt(), pixels.height.toInt());
    } finally {
      picture.dispose();
    }
  }

  Rect? paperBounds;
  ui.Image? current, target, landingImage;
  final halves = <ui.Image>[];
  try {
    final source = await compose(currentPage);
    current = source.image;
    final next = await compose(targetPage);
    target = next.image;
    // 保留已经合成的完整目标页，释放落页只交接句柄，避免末帧重新栅格化。
    landingImage = onCommitImage == null ? null : target.clone();
    final commitImage = landingImage;
    void commit() => onCommitImage!(commitImage!.clone());
    final a = source.bounds, b = next.bounds;
    // 相同纸面范围只卷曲实际图像；黑色 contain 留白不成为纸张的一部分。
    // 封面／跨幅等不兼容尺寸保留完整快照，保证两端原有适配策略不变。
    if ((a.topLeft - b.topLeft).distance * ratio < .5 &&
        (a.bottomRight - b.bottomRight).distance * ratio < .5) {
      final bounds = a.expandToInclude(b);
      final pixels =
          Rect.fromLTRB(
            (bounds.left * ratio).floorToDouble(),
            (bounds.top * ratio).floorToDouble(),
            (bounds.right * ratio).ceilToDouble(),
            (bounds.bottom * ratio).ceilToDouble(),
          ).intersect(
            Rect.fromLTWH(
              0,
              0,
              current.width.toDouble(),
              current.height.toDouble(),
            ),
          );
      final croppedCurrent = crop(current, pixels);
      ui.Image? croppedTarget;
      try {
        croppedTarget = crop(target, pixels);
      } catch (_) {
        croppedCurrent.dispose();
        rethrow;
      }
      current.dispose();
      target.dispose();
      current = croppedCurrent;
      target = croppedTarget;
      paperBounds = Rect.fromLTWH(
        pixels.left / ratio,
        pixels.top / ratio,
        pixels.width / ratio,
        pixels.height / ratio,
      );
    }
    if (comicHasSpread(currentPage, pageCount, preferences) &&
        comicHasSpread(targetPage, pageCount, preferences)) {
      final currentFaces = split(current);
      halves.addAll(currentFaces);
      final targetFaces = split(target);
      halves.addAll(targetFaces);
      final ordered = targetPage > currentPage
          ? [...currentFaces, ...targetFaces]
          : [...targetFaces, ...currentFaces];
      final pages = CurlTurnPages.spread(
        ordered,
        paperBounds: paperBounds,
        landingImage: commitImage,
        onCommit: commitImage == null ? null : commit,
      );
      halves.clear();
      landingImage = null;
      return pages;
    }
    // 封面与末尾孤页维持现有整页布局，不把它们移入半页改变静止适配规则。
    final result = CurlTurnPages(
      current: current,
      target: target,
      paperBounds: paperBounds,
      landingImage: commitImage,
      onCommit: commitImage == null ? null : commit,
    );
    current = target = landingImage = null;
    return result;
  } finally {
    current?.dispose();
    target?.dispose();
    landingImage?.dispose();
    for (final half in halves) {
      half.dispose();
    }
  }
}
