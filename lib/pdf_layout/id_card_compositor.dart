import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 身份证拼版布局。
enum CardLayout {
  topBottom, // 正面(上) + 国徽面(下)
  leftRight, // 正面(左) + 国徽面(右)
}

/// 身份证拼版：把「人像面(front)」与「国徽面(back)」拼到一张 A4。
///
/// - [flipBack]：国徽面是否水平镜像（部分证件排版需要）。
/// - [layout]：上下或左右布局。
/// 输出拼版后的 PNG 字节，随后由 [PdfBuilder] 放入 A4 PDF。
class IdCardCompositor {
  /// A4 @72dpi 像素尺寸（pt 与 px@72dpi 等价）。
  static const int a4Width = 595;
  static const int a4Height = 842;

  /// 拼版主入口。
  static Uint8List compose(
    Uint8List frontBytes,
    Uint8List backBytes, {
    bool flipBack = false,
    CardLayout layout = CardLayout.topBottom,
  }) {
    final canvas = img.Image(width: a4Width, height: a4Height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    // 注意：img.decodeImage 对垃圾字节不总是返回 null，可能内部抛 RangeError，
    // 两处 decode 必须各自兜底并统一抛出 Exception（不能漏出 IndexError）。
    final img.Image? front;
    final img.Image? backRaw;
    try {
      front = img.decodeImage(frontBytes);
    } catch (_) {
      throw Exception('无法解码身份证图片，拼版失败');
    }
    try {
      backRaw = img.decodeImage(backBytes);
    } catch (_) {
      throw Exception('无法解码身份证图片，拼版失败');
    }
    if (front == null || backRaw == null) {
      throw Exception('无法解码身份证图片，拼版失败');
    }
    final back = flipBack ? img.flipHorizontal(backRaw) : backRaw;

    final margin = (a4Width * 0.04).round();
    if (layout == CardLayout.topBottom) {
      final cellW = a4Width - margin * 2;
      final cellH = ((a4Height - margin * 3) / 2).round();
      _drawFit(canvas, front, margin, margin, cellW, cellH);
      _drawFit(canvas, back, margin, margin * 2 + cellH, cellW, cellH);
    } else {
      final cellH = a4Height - margin * 2;
      final cellW = ((a4Width - margin * 3) / 2).round();
      _drawFit(canvas, front, margin, margin, cellW, cellH);
      _drawFit(canvas, back, margin * 2 + cellW, margin, cellW, cellH);
    }
    return Uint8List.fromList(img.encodePng(canvas));
  }

  /// 把 [src] 等比缩放居中绘制到 canvas 的 (dx,dy,boxW,boxH) 区域内。
  static void _drawFit(
      img.Image canvas, img.Image src, int dx, int dy, int boxW, int boxH) {
    final scale = math.min(boxW / src.width, boxH / src.height);
    final tw = (src.width * scale).round();
    final th = (src.height * scale).round();
    if (tw <= 0 || th <= 0) return;
    final resized = img.copyResize(src, width: tw, height: th);
    final ox = dx + ((boxW - tw) ~/ 2);
    final oy = dy + ((boxH - th) ~/ 2);
    img.compositeImage(canvas, resized, dstX: ox, dstY: oy);
  }
}
