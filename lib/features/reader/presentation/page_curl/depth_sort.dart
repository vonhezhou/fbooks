import 'dart:typed_data';

// 深度必须保留 double 的全部精度。按 IEEE-754 的有序字节排序，避免
// 每帧对大量相近深度反复调用对象比较器；相同深度保留输入顺序。
class CurlDepthSorter {
  CurlDepthSorter(int capacity)
    : depths = Float64List(capacity),
      _first = Uint32List(capacity),
      _second = Uint32List(capacity),
      _keys = Uint8List(capacity * 8);

  final Float64List depths;
  final Uint32List _first, _second;
  final Uint8List _keys;
  final _counts = Uint32List(8 * 256);
  late final _bytes = depths.buffer.asUint8List();
  late final _data = ByteData.view(depths.buffer);

  // 返回复用缓冲区；调用方只读取前 count 项，并在下次调用前消费结果。
  Uint32List sort(int count) {
    RangeError.checkValueInInterval(count, 0, depths.length, 'count');
    final little = Endian.host == Endian.little;
    final signOffset = little ? 7 : 0;
    _counts.fillRange(0, _counts.length, 0);
    for (var i = 0; i < count; i++) {
      _first[i] = i;
      if (depths[i].isNaN) {
        // 与 double.compareTo 一致：所有 NaN 相等，并排在正无穷之后。
        _data.setUint64(i * 8, 0x7ff8000000000000, Endian.host);
      }
      final base = i * 8;
      final negative = (_bytes[base + signOffset] & 128) != 0;
      // 一次顺序扫描准备所有位的键和直方图，避免每轮经排序索引回读深度及符号。
      for (var digit = 0; digit < 8; digit++) {
        final value = _bytes[base + (little ? digit : 7 - digit)];
        final key = negative
            ? value ^ 255
            : digit == 7
            ? value ^ 128
            : value;
        _keys[base + digit] = key;
        _counts[digit * 256 + key]++;
      }
    }
    var input = _first, output = _second;
    for (var digit = 0; digit < 8; digit++) {
      final histogram = digit * 256;
      var total = 0, occupied = 0;
      for (var key = 0; key < 256; key++) {
        final length = _counts[histogram + key];
        _counts[histogram + key] = total;
        total += length;
        if (length != 0) occupied++;
      }
      if (occupied < 2) continue;
      for (var i = 0; i < count; i++) {
        final index = input[i];
        final key = _keys[index * 8 + digit];
        output[_counts[histogram + key]++] = index;
      }
      final swap = input;
      input = output;
      output = swap;
    }
    return input;
  }
}
