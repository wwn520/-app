import 'dart:math';
import 'dart:typed_data';

import 'package:edge_detection/edge_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:printer_app/models/id_card.dart';

/// 自动四角检测结果（归一化四角 + 置信度）。
class QuadDetectionResult {
  final Quad quad;
  final double confidence; // 0..1

  const QuadDetectionResult({required this.quad, required this.confidence});
}

/// 身份证边缘检测 / 四角定位。
///
/// 两层设计（确保离线隐私优先 + 编译通过 + 逻辑自洽）：
///
/// 1. **纯 Dart 启发式（`detect`）**：基于 `image` 包的灰度 → Sobel 边缘 →
///    四象限最强角点投票，输出归一化 [Quad] 与置信度；置信度 < 0.85 或失败返回 null，
///    交由 [CornerEditorController] 手动兜底（P1-4）。全程本地、零网络。
///    —— 适用于已通过 image_picker 导入的既有图片。
///
/// 2. **原生交互裁切（`autoCropNative`）**：调用 `edge_detection` 包的原生控件
///    （相机/相册采集 + 交互式边沿裁切）。真实 API 为
///    `EdgeDetection.detectEdge(String imagePath, {bool canUseGallery, ...})`，
///    返回 `Future<bool>`，裁切结果**覆盖写入** [imagePath]；该静态方法**不接受**
///    已有图片作输入，而是「采集 → 裁切」流程，得到更高精度的校正图。
///    —— 适用于在扫描页直接采集并高精度裁切。
class EdgeDetector {
  /// 自动检测证件四角（归一化坐标）。
  ///
  /// 返回 [QuadDetectionResult]；置信度不足或检测失败时返回 null（手动兜底）。
  Future<QuadDetectionResult?> detect(Uint8List imageBytes) async {
    final src = img.decodeImage(imageBytes);
    if (src == null) return null;

    // 缩小以提速
    final small = img.copyResize(src, width: 480);
    final gray = img.grayscale(small);
    final mag = _sobelMagnitude(gray);
    final w = small.width;
    final h = small.height;

    final corners = _voteCorners(mag, w, h);
    final confidence = _confidence(mag, w, h);
    if (confidence < 0.85) return null;

    // 映射回归一化坐标：四角是在缩小图（small）上投票得出的，必须用 small 的尺寸
    // 做归一化（缩放不变性保证正确性）；这里 w/h 即 small 图宽高，不可误用原图 src 的
    // 尺寸，否则四角会被压缩到左上角（原 BUG-EDGE-NORM）。
    return QuadDetectionResult(
      quad: Quad(
        tl: _norm(corners[0], w, h),
        tr: _norm(corners[1], w, h),
        br: _norm(corners[2], w, h),
        bl: _norm(corners[3], w, h),
      ),
      confidence: confidence,
    );
  }

  /// 调用 edge_detection 原生交互裁切控件（相机/相册采集 + 交互式边沿裁切）。
  ///
  /// 真实包 API（edge_detection ^1.1.x）：
  ///   `EdgeDetection.detectEdge(String imagePath, {bool canUseGallery, ...})`
  /// 启动**原生相机/相册采集**并进入裁切 UI，裁切结果**覆盖写入** [imagePath]，
  /// 返回 `Future<bool>`（true=用户完成裁切并保存，false=取消或失败）。
  ///
  /// 注意：该静态方法**不接受已有图片作为输入**，而是「采集 → 裁切」流程，因此适用于
  /// 在扫描页直接采集并高精度裁切。对于已通过 image_picker 导入的既有图片，请使用
  /// 纯 Dart 启发式 [detect]。
  ///
  /// [savePath] 裁切结果写入路径；为空时在本方法内生成到应用私有临时目录。
  /// 返回裁切后图片路径；用户取消、权限不足或异常时返回 null。
  Future<String?> autoCropNative({bool canUseGallery = true, String? savePath}) async {
    try {
      final outPath = savePath ?? await _defaultCropPath();
      final ok = await EdgeDetection.detectEdge(
        outPath,
        canUseGallery: canUseGallery,
        androidScanTitle: '扫描证件',
        androidCropTitle: '裁剪',
        androidCropBlackWhiteTitle: '黑白',
        androidCropReset: '重拍',
      );
      return ok ? outPath : null;
    } catch (_) {
      return null;
    }
  }

  /// 生成应用私有临时目录下的裁切输出路径（不落共享目录，符合隐私红线）。
  static Future<String> _defaultCropPath() async {
    final dir = await getTemporaryDirectory();
    final name = 'id_card_crop_${DateTime.now().microsecondsSinceEpoch}.jpg';
    return '${dir.path}/$name';
  }

  /// 计算归一化坐标（0..1）。
  static Point<double> _norm(Point<double> p, int w, int h) =>
      Point(p.x / w, p.y / h);

  /// 四象限最强角点投票：每个象限选取「边缘强度 × 离中心距离」最大的像素作为角点。
  static List<Point<double>> _voteCorners(
      Float64List mag, int w, int h) {
    final cx = w / 2.0;
    final cy = h / 2.0;
    final best = <Point<double>>[
      Point(0.0, 0.0), // TL
      Point(w.toDouble(), 0.0), // TR
      Point(w.toDouble(), h.toDouble()), // BR
      Point(0.0, h.toDouble()), // BL
    ];
    final bestScore = [0.0, 0.0, 0.0, 0.0];

    const threshold = 40.0; // Sobel 幅值阈值（0..~1020 归一前）
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final e = mag[y * w + x];
        if (e < threshold) continue;
        final dx = x - cx;
        final dy = y - cy;
        final dist = sqrt(dx * dx + dy * dy);
        final score = e * dist;
        int quad;
        if (x < cx && y < cy) {
          quad = 0;
        } else if (x >= cx && y < cy) {
          quad = 1;
        } else if (x >= cx && y >= cy) {
          quad = 2;
        } else {
          quad = 3;
        }
        if (score > bestScore[quad]) {
          bestScore[quad] = score;
          best[quad] = Point(x.toDouble(), y.toDouble());
        }
      }
    }
    return best;
  }

  /// 置信度：外圈 15% 边界带内的强边缘占比，归一化到 0..1。
  static double _confidence(Float64List mag, int w, int h) {
    const band = 0.15;
    final x0 = (w * band).round();
    final x1 = (w * (1 - band)).round();
    final y0 = (h * band).round();
    final y1 = (h * (1 - band)).round();
    int strong = 0;
    int total = 0;
    const threshold = 40.0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final inBand =
            x < x0 || x >= x1 || y < y0 || y >= y1;
        if (!inBand) continue;
        total++;
        if (mag[y * w + x] >= threshold) strong++;
      }
    }
    if (total == 0) return 0;
    final ratio = strong / total;
    return (ratio * 3.0).clamp(0.0, 1.0);
  }

  /// Sobel 边缘幅值。
  static Float64List _sobelMagnitude(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final mag = Float64List(w * h);
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final p = (int a, int b) => gray.getPixel(a, b).r.toDouble();
        final gx = (p(x + 1, y - 1) + 2 * p(x + 1, y) + p(x + 1, y + 1)) -
            (p(x - 1, y - 1) + 2 * p(x - 1, y) + p(x - 1, y + 1));
        final gy = (p(x - 1, y + 1) + 2 * p(x, y + 1) + p(x + 1, y + 1)) -
            (p(x - 1, y - 1) + 2 * p(x, y - 1) + p(x + 1, y - 1));
        mag[y * w + x] = sqrt(gx * gx + gy * gy);
      }
    }
    return mag;
  }
}
