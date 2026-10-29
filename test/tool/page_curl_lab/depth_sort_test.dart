import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/page_curl_lab/depth_sort.dart';

void main() {
  test('精确保留深度顺序，覆盖相邻浮点、负值、正负零、无穷和 NaN', () {
    final values = [
      double.nan,
      double.infinity,
      1.0,
      1.0000000000000002,
      -0.0,
      0.0,
      -1.0,
      double.negativeInfinity,
      -1.0000000000000002,
      double.nan,
      1e-300,
      -1e-300,
    ];
    final sorter = CurlDepthSorter(values.length)..depths.setAll(0, values);
    final expected = List.generate(values.length, (i) => i)
      ..sort((a, b) {
        final c = values[a].compareTo(values[b]);
        return c == 0 ? a.compareTo(b) : c;
      });
    expect(
      sorter.sort(values.length).take(values.length),
      orderedEquals(expected),
    );
  });
  test('相近及重复深度稳定排序，缓冲区可在空、小、大前缀间复用', () {
    final random = math.Random(73), sorter = CurlDepthSorter(9216);
    for (final count in [9216, 0, 3, 9216, 17, 1, 4096]) {
      final values = [
        for (var i = 0; i < count; i++)
          i % 4 == 0
              ? 0.0
              : (i % 4 == 1
                    ? random.nextInt(8).toDouble()
                    : random.nextDouble() * 1e-10),
      ];
      sorter.depths.setAll(0, values);
      final expected = List.generate(count, (i) => i)
        ..sort((a, b) {
          final c = values[a].compareTo(values[b]);
          return c == 0 ? a.compareTo(b) : c;
        });
      expect(sorter.sort(count).take(count), orderedEquals(expected));
    }
  });
  test('排序拒绝超过容量的前缀', () {
    final sorter = CurlDepthSorter(3);
    expect(() => sorter.sort(-1), throwsRangeError);
    expect(() => sorter.sort(4), throwsRangeError);
  });
  test('随机浮点位型与 compareTo 的完整顺序一致', () {
    final random = math.Random(91), bytes = ByteData(8), values = <double>[];
    for (var i = 0; i < 4096; i++) {
      bytes.setUint32(0, random.nextInt(0x100000000));
      bytes.setUint32(4, random.nextInt(0x100000000));
      values.add(bytes.getFloat64(0));
    }
    final sorter = CurlDepthSorter(values.length)..depths.setAll(0, values);
    final expected = List.generate(values.length, (i) => i)
      ..sort((a, b) {
        final c = values[a].compareTo(values[b]);
        return c == 0 ? a.compareTo(b) : c;
      });
    expect(
      sorter.sort(values.length).take(values.length),
      orderedEquals(expected),
    );
  });
}
