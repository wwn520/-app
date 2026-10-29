import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printer_app/id_card_scan/perspective_corrector.dart';
import 'package:printer_app/models/id_card.dart';

/// 生成 2×2 四色象限图（TL红 / TR绿 / BR蓝 / BL黄），用于验证单应矩阵方向。
img.Image _fourQuadrants(int w, int h) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      img.Color c;
      if (x < w / 2 && y < h / 2) {
        c = img.ColorRgb8(220, 20, 20); // TL 红
      } else if (x >= w / 2 && y < h / 2) {
        c = img.ColorRgb8(20, 200, 20); // TR 绿
      } else if (x >= w / 2 && y >= h / 2) {
        c = img.ColorRgb8(20, 20, 220); // BR 蓝
      } else {
        c = img.ColorRgb8(220, 220, 20); // BL 黄
      }
      im.setPixel(x, y, c);
    }
  }
  return im;
}

Uint8List _encode(img.Image im) =>
    Uint8List.fromList(img.encodeJpg(im, quality: 92));

const _identity = Quad(
  tl: Point(0, 0),
  tr: Point(1, 0),
  br: Point(1, 1),
  bl: Point(0, 1),
);

void main() {
  group('PerspectiveCorrector 透视校正', () {
    test('恒等四角 → 输出尺寸与源一致', () async {
      final out = await PerspectiveCorrector.correct(
          _encode(_fourQuadrants(200, 160)), _identity);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 200);
      expect(decoded.height, 160);
    });

    test('单应矩阵方向正确：选区=左上象限 → 输出中心为红', () async {
      final out = await PerspectiveCorrector.correct(
        _encode(_fourQuadrants(200, 200)),
        const Quad(
          tl: Point(0, 0),
          tr: Point(0.5, 0),
          br: Point(0.5, 0.5),
          bl: Point(0, 0.5),
        ),
      );
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 100);
      expect(decoded.height, 100);
      final c = decoded.getPixel(50, 50);
      expect(c.r, greaterThan(120));
      expect(c.g, lessThan(80));
      expect(c.b, lessThan(80));
    });

    test('单应矩阵方向正确：选区=右下象限 → 输出中心为蓝', () async {
      final out = await PerspectiveCorrector.correct(
        _encode(_fourQuadrants(200, 200)),
        const Quad(
          tl: Point(0.5, 0.5),
          tr: Point(1, 0.5),
          br: Point(1, 1),
          bl: Point(0.5, 1),
        ),
      );
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 100);
      expect(decoded.height, 100);
      final c = decoded.getPixel(50, 50);
      expect(c.b, greaterThan(120));
      expect(c.r, lessThan(80));
      expect(c.g, lessThan(80));
    });

    test('退化四角（共点）→ 返回原字节，不抛异常', () async {
      final bytes = _encode(_fourQuadrants(100, 100));
      final out = await PerspectiveCorrector.correct(
        bytes,
        const Quad(
          tl: Point(0.5, 0.5),
          tr: Point(0.5, 0.5),
          br: Point(0.5, 0.5),
          bl: Point(0.5, 0.5),
        ),
      );
      expect(out.length, bytes.length);
    });

    test('无法解码的图片 → 抛异常', () async {
      expect(
        () => PerspectiveCorrector.correct(
          Uint8List.fromList([1, 2, 3, 4]),
          _identity,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
