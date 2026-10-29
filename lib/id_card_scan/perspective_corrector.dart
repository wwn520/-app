import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:printer_app/models/id_card.dart';

/// 纯 Dart 透视校正（不引入全量 opencv）。
///
/// 原理：
/// 1. 由四角（归一化）换算为源图像素四角；
/// 2. 估计输出矩形尺寸（四边长度均值）；
/// 3. 用 4 点 DLT 求单应矩阵 H（dst 矩形 → src 四边形）；
/// 4. 对目标每个像素逆映射回源坐标，双线性采样得到校正图。
///
/// 自动检测（EdgeDetector）与手动拖拽（CornerEditorController）共用本校正，
/// 满足「端侧、离线、隐私优先」约束。
class PerspectiveCorrector {
  /// 对图片按给定四角（归一化）做透视校正，输出校正后 JPEG 字节。
  ///
  /// [quad] 四角顺序：tl, tr, br, bl。
  static Future<Uint8List> correct(Uint8List imageBytes, Quad quad) async {
    final src = img.decodeImage(imageBytes);
    if (src == null) {
      throw Exception('无法解码图片，透视校正失败');
    }
    final w = src.width;
    final h = src.height;

    // 归一化四角 -> 源图像素坐标
    final pts = [
      Point(quad.tl.x * w, quad.tl.y * h),
      Point(quad.tr.x * w, quad.tr.y * h),
      Point(quad.br.x * w, quad.br.y * h),
      Point(quad.bl.x * w, quad.bl.y * h),
    ];

    // 目标矩形尺寸：四边长度均值，保持证件比例
    final topW = _dist(pts[0], pts[1]);
    final bottomW = _dist(pts[3], pts[2]);
    final leftH = _dist(pts[0], pts[3]);
    final rightH = _dist(pts[1], pts[2]);
    final outW = max(topW, bottomW).round();
    final outH = max(leftH, rightH).round();
    if (outW <= 1 || outH <= 1) return imageBytes;

    // 目标矩形四角（tl, tr, br, bl）
    final dst = [
      Point(0.0, 0.0),
      Point(outW.toDouble(), 0.0),
      Point(outW.toDouble(), outH.toDouble()),
      Point(0.0, outH.toDouble()),
    ];

    // 单应矩阵映射：矩形(dst) -> 原始四边形(pts)
    final H = _computeHomography(dst, pts);

    final out = img.Image(width: outW, height: outH);
    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        final denom = H[6] * x + H[7] * y + H[8];
        if (denom.abs() < 1e-9) {
          out.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          continue;
        }
        final sx = (H[0] * x + H[1] * y + H[2]) / denom;
        final sy = (H[3] * x + H[4] * y + H[5]) / denom;
        if (sx < 0 || sy < 0 || sx >= w - 1 || sy >= h - 1) {
          out.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        } else {
          out.setPixel(x, y, _sampleBilinear(src, sx, sy));
        }
      }
    }
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  /// 双线性采样：在 (x,y) 处对源图插值。
  static img.Color _sampleBilinear(img.Image src, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final fx = x - x0;
    final fy = y - y0;

    final c00 = src.getPixel(x0, y0);
    final c10 = src.getPixel(x1, y0);
    final c01 = src.getPixel(x0, y1);
    final c11 = src.getPixel(x1, y1);

    final r = _lerp(c00.r, c10.r, c01.r, c11.r, fx, fy);
    final g = _lerp(c00.g, c10.g, c01.g, c11.g, fx, fy);
    final b = _lerp(c00.b, c10.b, c01.b, c11.b, fx, fy);
    return img.ColorRgb8(r, g, b);
  }

  /// 四角双线性插值。
  static int _lerp(num a, num b, num c, num d, double fx, double fy) {
    final top = a + (b - a) * fx;
    final bottom = c + (d - c) * fx;
    return (top + (bottom - top) * fy).round().clamp(0, 255);
  }

  static double _dist(Point<double> a, Point<double> b) =>
      sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

  /// 由 4 对点（src → dst）求 3x3 单应矩阵（DLT，固定 h8=1）。
  ///
  /// 返回长度 9 的列表 [h0..h8]，满足：
  ///   u = (h0*x + h1*y + h2) / (h6*x + h7*y + h8)
  ///   v = (h3*x + h4*y + h5) / (h6*x + h7*y + h8)
  static List<double> _computeHomography(
      List<Point<double>> src, List<Point<double>> dst) {
    final A = List.generate(8, (_) => List<double>.filled(8, 0));
    final b = List<double>.filled(8, 0);
    for (int i = 0; i < 4; i++) {
      final x = src[i].x;
      final y = src[i].y;
      final u = dst[i].x;
      final v = dst[i].y;
      // 行 2i：u 方程
      A[2 * i][0] = x;
      A[2 * i][1] = y;
      A[2 * i][2] = 1;
      A[2 * i][6] = -u * x;
      A[2 * i][7] = -u * y;
      b[2 * i] = u;
      // 行 2i+1：v 方程
      A[2 * i + 1][3] = x;
      A[2 * i + 1][4] = y;
      A[2 * i + 1][5] = 1;
      A[2 * i + 1][6] = -v * x;
      A[2 * i + 1][7] = -v * y;
      b[2 * i + 1] = v;
    }
    final h = _solveLinear(A, b);
    return [...h, 1.0];
  }

  /// 高斯-约当消元解线性方程组（n×n）。
  static List<double> _solveLinear(
      List<List<double>> A, List<double> b) {
    final n = b.length;
    final M = List.generate(n, (i) => [...A[i], b[i]]);
    for (int col = 0; col < n; col++) {
      int pivot = col;
      for (int r = col + 1; r < n; r++) {
        if (M[r][col].abs() > M[pivot][col].abs()) pivot = r;
      }
      final tmp = M[col];
      M[col] = M[pivot];
      M[pivot] = tmp;
      final pivVal = M[col][col];
      if (pivVal.abs() < 1e-12) continue; // 近奇异，近似跳过该行
      for (int r = 0; r < n; r++) {
        if (r == col) continue;
        final factor = M[r][col] / pivVal;
        if (factor == 0) continue;
        for (int c = col; c <= n; c++) {
          M[r][c] -= factor * M[col][c];
        }
      }
    }
    final x = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      x[i] = M[i][i].abs() < 1e-12 ? 0 : M[i][n] / M[i][i];
    }
    return x;
  }
}
