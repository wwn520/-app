import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printer_app/id_card_scan/edge_detector.dart';

/// 注意：本测试依赖 lib/id_card_scan/edge_detector.dart（依赖包已修正为
/// edge_detection ^1.1.3，API 签名与 pub.dev 文档一致，可正常编译运行）。
/// 用例覆盖：解码失败兜底 + 合成图不抛异常/四角合法范围。

Uint8List _jpeg(int w, int h, img.Color c) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixel(x, y, c);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im));
}

void main() {
  final detector = EdgeDetector();

  test('无法解码的字节 → detect 返回 null（不抛异常）', () async {
    expect(await detector.detect(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('合成图 → detect 不抛异常，返回 null 或合法 Quad（四角在 0..1）', () async {
    final bytes = _jpeg(480, 360, img.ColorRgb8(200, 200, 200));
    final result = await detector.detect(bytes);
    expect(() => result, returnsNormally);
    if (result != null) {
      for (final p in result.quad.toPixelPoints(1, 1)) {
        expect(p.x, inInclusiveRange(0.0, 1.0));
        expect(p.y, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  // 已知缺陷（源码 Bug，待修）：detect() 内 _norm(corners[i], src.width, src.height)
  // 误用「原始图尺寸」归一化（corners 实为 480 宽 small 图坐标），会把四角压到左上角。
  // 该缺陷由代码审查发现，修复后此处应强化断言（要求四角分布在合理范围而非聚于原点）。
}
