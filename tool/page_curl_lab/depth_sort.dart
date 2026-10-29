import 'dart:typed_data';

// 深度必须保留 double 的全部精度。按 IEEE-754 的有序字节排序，避免
// 每帧对大量相近深度反复调用对象比较器；相同深度保留输入顺序。
class CurlDepthSorter {
  CurlDepthSorter(int capacity)
    : depths = Float64List(capacity),
      _first = Uint32List(capacity),
      _second = Uint32List(capacity);

  final Float64List depths;
  final Uint32List _first, _second;
  final _counts = Uint32List(256);
  late final _bytes = depths.buffer.asUint8List();

  // 返回复用缓冲区；调用方只读取前 count 项，并在下次调用前消费结果。
  Uint32List sort(int count) {
    RangeError.checkValueInInterval(count, 0, depths.length, 'count');
    final little = Endian.host == Endian.little;
    final signOffset = little ? 7 : 0;
    for (var i = 0; i < count; i++) {
      _first[i] = i;
      if (depths[i].isNaN) {
        // 与 double.compareTo 一致：所有 NaN 相等，并排在正无穷之后。
        ByteData.view(depths.buffer)
            .setUint64(i * 8, 0x7ff8000000000000, Endian.host);
      }
    }
    var input = _first, output = _second;
    for (var digit = 0; digit < 8; digit++) {
      _counts.fillRange(0, 256, 0);
      final offset = little ? digit : 7 - digit;
      for (var i = 0; i < count; i++) {
        final base = input[i] * 8;
        final value = _bytes[base + offset];
        final key = (_bytes[base + signOffset] & 128) != 0
            ? value ^ 255
            : digit == 7
            ? value ^ 128
            : value;
        _counts[key]++;
      }
      var total = 0, occupied = 0;
      for (var key = 0; key < 256; key++) {
        final length = _counts[key];
        _counts[key] = total;
        total += length;
        if (length != 0) occupied++;
      }
      if (occupied < 2) continue;
      for (var i = 0; i < count; i++) {
        final index = input[i], base = index * 8;
        final value = _bytes[base + offset];
        final key = (_bytes[base + signOffset] & 128) != 0
            ? value ^ 255
            : digit == 7
            ? value ^ 128
            : value;
        output[_counts[key]++] = index;
      }
      final swap = input;
      input = output;
      output = swap;
    }
    return input;
  }
}
