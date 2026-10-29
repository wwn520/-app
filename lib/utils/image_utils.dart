import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';

/// 图像字节 / 文件路径互转、尺寸读取等工具。
///
/// 注意：身份证处理的中间产物只写入**应用私有临时目录**
/// （[getTemporaryDirectory]），不落共享相册/目录，符合隐私红线。
class ImageUtils {
  /// 读取本地文件为字节。
  static Future<Uint8List> fileToBytes(String path) {
    return File(path).readAsBytes();
  }

  /// 把字节写入应用私有临时目录，返回路径。
  ///
  /// [fileName] 建议带扩展名（如 .jpg / .png）。
  static Future<String> bytesToFile(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 图像尺寸（像素）。解码失败返回 null。
  static ImageDimension? imageSize(Uint8List bytes) {
    final img = decodeImage(bytes);
    if (img == null) return null;
    return ImageDimension(width: img.width, height: img.height);
  }

  /// 把字节解码为 [Image]（失败返回 null）。
  static Image? decode(Uint8List bytes) => decodeImage(bytes);

  /// 编码为 JPEG（默认质量 90）。
  static Uint8List encodeJpg(Image image, {int quality = 90}) {
    return encodeJpg(image, quality: quality);
  }

  /// 编码为 PNG。
  static Uint8List encodePng(Image image) => encodePng(image);
}

/// 简单图像尺寸封装（避免依赖 dart:ui 的 Size）。
class ImageDimension {
  final int width;
  final int height;

  const ImageDimension({required this.width, required this.height});

  @override
  String toString() => 'ImageDimension($width x $height)';
}
