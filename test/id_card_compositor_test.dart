import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:printer_app/pdf_layout/id_card_compositor.dart';

Uint8List _solid(int w, int h, img.Color c) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixel(x, y, c);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

/// 左右明暗不对称图：左半暗、右半亮，用于验证 flipBack 镜像。
Uint8List _asymmetric(int w, int h) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixel(
          x, y, x < w / 2 ? img.ColorRgb8(10, 10, 10) : img.ColorRgb8(240, 240, 240));
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  group('IdCardCompositor 身份证拼版', () {
    test('上下布局：正面(上,红) + 国徽(下,蓝) 均落在 A4 内且不越界', () {
      final bytes = IdCardCompositor.compose(
        _solid(300, 200, img.ColorRgb8(220, 20, 20)),
        _solid(300, 200, img.ColorRgb8(20, 20, 220)),
      );
      final canvas = img.decodeImage(bytes)!;
      expect(canvas.width, IdCardCompositor.a4Width);
      expect(canvas.height, IdCardCompositor.a4Height);

      final top = canvas.getPixel(270, 216); // 上格中心
      expect(top.r, greaterThan(120));
      expect(top.b, lessThan(80));

      final bottom = canvas.getPixel(270, 625); // 下格中心
      expect(bottom.b, greaterThan(120));
      expect(bottom.r, lessThan(80));
    });

    test('左右布局：正面(左,红) + 国徽(右,蓝)', () {
      final bytes = IdCardCompositor.compose(
        _solid(300, 200, img.ColorRgb8(220, 20, 20)),
        _solid(300, 200, img.ColorRgb8(20, 20, 220)),
        layout: CardLayout.leftRight,
      );
      final canvas = img.decodeImage(bytes)!;
      expect(canvas.width, IdCardCompositor.a4Width);
      expect(canvas.height, IdCardCompositor.a4Height);

      final left = canvas.getPixel(150, 420);
      expect(left.r, greaterThan(120));
      final right = canvas.getPixel(440, 420);
      expect(right.b, greaterThan(120));
    });

    test('flipBack=true 水平镜像国徽面（左右亮度互换）', () {
      final back = _asymmetric(300, 200); // 左暗右亮
      final bytes = IdCardCompositor.compose(
        _solid(300, 200, img.ColorRgb8(220, 20, 20)),
        back,
        flipBack: true,
      );
      final canvas = img.decodeImage(bytes)!;
      // 下格起始 x=309，取 cell 内 60px 与 201px 两点
      final leftOfBack = canvas.getPixel(309 + 60, 420);
      final rightOfBack = canvas.getPixel(309 + 261 - 60, 420);
      // 镜像后：cell 左侧应显示原图右侧(亮)，右侧显示原图左侧(暗)
      expect(leftOfBack.r, greaterThan(rightOfBack.r));
    });

    test('无法解码图片 → 抛异常', () {
      expect(
        () => IdCardCompositor.compose(
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5, 6]),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
