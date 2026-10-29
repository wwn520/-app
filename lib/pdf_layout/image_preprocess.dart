import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:printer_app/models/print_settings.dart';

/// 图像预处理：灰度转换、对比度增强（黑白模式双保险 + 身份证清晰度）。
///
/// 依赖 `image` 包（纯 Dart，无原生依赖），用于 PDF 排版前的像素级处理。
class ImagePreprocess {
  /// 按色彩模式预处理：黑白模式转灰度（与 IPP print-color-mode 双重保险）。
  ///
  /// 返回重新编码的 JPEG 字节；解码失败则原样返回。
  static Uint8List applyColorMode(Uint8List bytes, ColorMode mode) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final out =
        mode == ColorMode.grayscale ? _toGrayscale(image) : image;
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  /// 轻度增强对比度（用于身份证边框 / 文字更清晰）。[amount] 默认 1.3。
  static Uint8List enhanceContrast(Uint8List bytes, {double amount = 1.3}) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final out = _adjustContrast(image, amount);
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  /// 灰度化（加权平均 BT.601）。
  static img.Image _toGrayscale(img.Image src) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final l = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b)
            .round()
            .clamp(0, 255);
        out.setPixel(x, y, img.ColorRgb8(l, l, l));
      }
    }
    return out;
  }

  /// 对比度调整：new = (v - 128) * amount + 128。
  static img.Image _adjustContrast(img.Image src, double amount) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final r = _clamp((p.r - 128) * amount + 128);
        final g = _clamp((p.g - 128) * amount + 128);
        final b = _clamp((p.b - 128) * amount + 128);
        out.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }
    return out;
  }

  static int _clamp(double v) => v.round().clamp(0, 255);
}
