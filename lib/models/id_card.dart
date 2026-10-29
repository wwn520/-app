import 'dart:math';
import 'dart:typed_data';

/// 图片来源。
enum ImageSource {
  album, // 相册
  camera, // 拍照
  share, // 系统/微信分享
}

/// 已导入的一张图片。
class ImportedImage {
  final String path; // 本地文件路径
  final ImageSource source;
  final Uint8List? bytes; // 可选内存字节（相册/拍照直接持有；分享可能仅 path）

  const ImportedImage({
    required this.path,
    required this.source,
    this.bytes,
  });
}

/// 归一化四角（坐标范围 0..1，相对于原图宽高）。
///
/// 顺序固定：左上 / 右上 / 右下 / 左下。
class Quad {
  final Point<double> tl;
  final Point<double> tr;
  final Point<double> br;
  final Point<double> bl;

  const Quad({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
  });

  /// 以像素坐标形式返回四角（按同样顺序）。
  List<Point<double>> toPixelPoints(double width, double height) => [
        Point(tl.x * width, tl.y * height),
        Point(tr.x * width, tr.y * height),
        Point(br.x * width, br.y * height),
        Point(bl.x * width, bl.y * height),
      ];

  /// 不可变拷贝。
  Quad copyWith({
    Point<double>? tl,
    Point<double>? tr,
    Point<double>? br,
    Point<double>? bl,
  }) =>
      Quad(
        tl: tl ?? this.tl,
        tr: tr ?? this.tr,
        br: br ?? this.br,
        bl: bl ?? this.bl,
      );
}

/// 身份证扫描会话状态。
///
/// 持有「人像面(front)」与「国徽面(back)」两张导入图，
/// 自动/手动校正得到的四角 [frontCorners]/[backCorners]，
/// 以及校正后字节 [correctedFront]/[correctedBack]。
/// [manualMode] 标记是否走手动四角拖拽兜底。
class IdCardScan {
  final ImportedImage front; // 人像面
  final ImportedImage back; // 国徽面
  Quad? frontCorners;
  Quad? backCorners;
  Uint8List? correctedFront;
  Uint8List? correctedBack;
  bool manualMode = false;

  IdCardScan({
    required this.front,
    required this.back,
  });
}
