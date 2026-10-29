import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

enum PageKind { text, comic, pdf }

class PageTextures {
  PageTextures(this.images, this.prepareMs);
  final List<ui.Image> images;
  final double prepareMs;
  int get rgbaBytes =>
      images.fold(0, (n, image) => n + image.width * image.height * 4);
  void dispose() {
    for (final image in images) {
      image.dispose();
    }
  }
}

Future<PageTextures> preparePages(
  PageKind kind,
  Size size,
  double dpr, {
  List<int> pageNumbers = const [0, 1, 2, 3],
}) async {
  final watch = Stopwatch()..start();
  final width = (size.width * dpr).ceil();
  final height = (size.height * dpr).ceil();
  final images = <ui.Image>[];
  PdfDocument? document;
  try {
    if (kind == PageKind.pdf) {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openData(pdfFixture());
    }
    for (final page in pageNumbers) {
      if (document != null) {
        final rendered = await document.pages[page % document.pages.length]
            .render(fullWidth: width.toDouble(), fullHeight: height.toDouble());
        if (rendered == null) throw StateError('PDF render returned no pixels');
        try {
          images.add(await rendered.createImage());
        } finally {
          rendered.dispose();
        }
        continue;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr);
      final rect = Offset.zero & size;
      canvas.drawRect(rect, Paint()..color = const Color(0xfffaf6ec));
      if (kind == PageKind.text) {
        _text(
          canvas,
          'THE PAPER LAB  /  ${page + 1}',
          const Offset(25, 24),
          12,
          size.width - 50,
        );
        var y = 65.0;
        _text(canvas, 'A page in motion', Offset(25, y), 26, size.width - 50);
        y += 55;
        while (y < size.height - 50) {
          final paragraph = TextPainter(
            text: const TextSpan(
              text:
                  'Paper bends into light. The words follow its surface, while a soft shadow reveals the page beneath. '
                  'This texture is a controlled typography fixture for measuring a reusable curl renderer.',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 16,
                height: 1.5,
                color: Color(0xff302c27),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: size.width - 50);
          if (y + paragraph.height > size.height - 35) {
            paragraph.dispose();
            break;
          }
          paragraph.paint(canvas, Offset(25, y));
          y += paragraph.height + 18;
          paragraph.dispose();
        }
      } else {
        final random = math.Random(page);
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 2; col++) {
            final panel = Rect.fromLTWH(
              12 + col * (size.width - 24) / 2,
              12 + row * (size.height - 24) / 3,
              (size.width - 24) / 2 - 6,
              (size.height - 24) / 3 - 6,
            );
            canvas.drawRect(
              panel,
              Paint()
                ..shader = ui.Gradient.linear(
                  panel.topLeft,
                  panel.bottomRight,
                  [
                    Colors.primaries[(page * 3 + row + col) %
                        Colors.primaries.length],
                    const Color(0xff182333),
                  ],
                ),
            );
            canvas.save();
            canvas.clipRect(panel);
            for (var i = 0; i < 35; i++) {
              canvas.drawLine(
                Offset(
                  panel.left + random.nextDouble() * panel.width,
                  panel.top,
                ),
                Offset(
                  panel.left + random.nextDouble() * panel.width,
                  panel.bottom,
                ),
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.18)
                  ..strokeWidth = 2,
              );
            }
            canvas.drawCircle(
              panel.center,
              panel.width * 0.24,
              Paint()..color = const Color(0xfff6ca9b),
            );
            canvas.restore();
            _text(
              canvas,
              'FRAME ${page * 6 + row * 2 + col + 1}',
              panel.topLeft + const Offset(8, 8),
              12,
              panel.width - 16,
            );
          }
        }
      }
      _text(
        canvas,
        '${page + 1}',
        Offset(size.width / 2 - 5, size.height - 27),
        12,
        35,
      );
      final picture = recorder.endRecording();
      ui.Image image;
      try {
        image = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
      if (kind == PageKind.comic) {
        // 图片场景包含真实 PNG 编解码，但不包含 CBZ 解压和文件 I/O。
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final codec = await ui.instantiateImageCodec(
            png!.buffer.asUint8List(),
          );
          try {
            images.add((await codec.getNextFrame()).image);
          } finally {
            codec.dispose();
          }
        } finally {
          image.dispose();
        }
      } else {
        images.add(image);
      }
    }
    return PageTextures(images, watch.elapsedMicroseconds / 1000);
  } catch (_) {
    for (final image in images) {
      image.dispose();
    }
    rethrow;
  } finally {
    await document?.dispose();
  }
}

void _text(
  Canvas canvas,
  String value,
  Offset offset,
  double fontSize,
  double width,
) {
  final text = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'serif',
        fontSize: fontSize,
        color: const Color(0xff302c27),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  text.paint(canvas, offset);
  text.dispose();
}

/// 自包含的四页有效 PDF：真实走 PDFium，不读取用户书库。
Uint8List pdfFixture() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R 9 0 R] /Count 4 >>',
  ];
  for (var i = 0; i < 4; i++) {
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Resources << /Font << /F1 11 0 R >> >> /Contents ${4 + i * 2} 0 R >>',
    );
    final commands = StringBuffer(
      '0.98 0.96 0.92 rg 0 0 600 800 re f\n0.12 0.14 0.18 rg\nBT /F1 28 Tf 45 735 Td (PDF PAPER LAB - PAGE ${i + 1}) Tj ET\n',
    );
    for (var j = 0; j < 24; j++) {
      commands.writeln(
        'BT /F1 14 Tf 45 ${680 - j * 23} Td (Vector text and rules rendered by PDFium. Sample line ${j + 1}.) Tj ET',
      );
    }
    commands.writeln('0.25 0.4 0.6 RG 2 w 45 65 510 80 re S');
    final stream = commands.toString();
    objects.add(
      '<< /Length ${ascii.encode(stream).length} >>\nstream\n${stream}endstream',
    );
  }
  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>');
  final output = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(output.length);
    output.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = output.length;
  output.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    output.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  output.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(output.toString()));
}
