import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:printer_app/id_card_scan/corner_editor_controller.dart';

/// 手动四角拖拽覆盖层。
///
/// 在图片之上叠加四个可拖拽手柄，实时更新 [CornerEditorController] 的 [Quad]，
/// 用于身份证自动识别置信度不足时的手动兜底（P1-4）。
///
/// 实现要点：整层用单一 [GestureDetector] 接收拖拽，按指针落下时离哪个手柄最近
/// 决定激活角；手柄本身 [IgnorePointer] 仅作可视反馈，避免手势冲突。
class CornerEditorOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final CornerEditorController controller;

  const CornerEditorOverlay({
    super.key,
    required this.imageBytes,
    required this.controller,
  });

  @override
  State<CornerEditorOverlay> createState() => _CornerEditorOverlayState();
}

class _CornerEditorOverlayState extends State<CornerEditorOverlay> {
  final GlobalKey _key = GlobalKey();
  CornerId? _activeCorner;

  @override
  Widget build(BuildContext context) {
    final decoded = img.decodeImage(widget.imageBytes);
    final aspect = decoded != null ? decoded.width / decoded.height : 1.0;

    return LayoutBuilder(
      key: _key,
      builder: (ctx, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        // contain 后的实际图片显示矩形
        double w;
        double h;
        if (boxW / boxH > aspect) {
          h = boxH;
          w = h * aspect;
        } else {
          w = boxW;
          h = w / aspect;
        }
        final offX = (boxW - w) / 2;
        final offY = (boxH - h) / 2;
        final rect = Rect.fromLTWH(offX, offY, w, h);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (d) => _onPan(d.localPosition, rect),
          onPanUpdate: (d) => _onPan(d.localPosition, rect),
          onPanEnd: (_) => setState(() => _activeCorner = null),
          child: Stack(
            children: [
              Center(
                child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
              ),
              AnimatedBuilder(
                animation: widget.controller,
                builder: (c, _) {
                  final q = widget.controller.quad;
                  final pTL = Offset(
                      rect.left + q.tl.x * rect.width,
                      rect.top + q.tl.y * rect.height);
                  final pTR = Offset(
                      rect.left + q.tr.x * rect.width,
                      rect.top + q.tr.y * rect.height);
                  final pBR = Offset(
                      rect.left + q.br.x * rect.width,
                      rect.top + q.br.y * rect.height);
                  final pBL = Offset(
                      rect.left + q.bl.x * rect.width,
                      rect.top + q.bl.y * rect.height);
                  return Stack(
                    children: [
                      CustomPaint(
                        size: Size(boxW, boxH),
                        painter: _QuadPainter([pTL, pTR, pBR, pBL]),
                      ),
                      _handle(pTL),
                      _handle(pTR),
                      _handle(pBR),
                      _handle(pBL),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onPan(Offset local, Rect rect) {
    if (_activeCorner == null) {
      // 选择最近的角（半径 40 内）
      final q = widget.controller.quad;
      final corners = {
        CornerId.tl: Offset(rect.left + q.tl.x * rect.width,
            rect.top + q.tl.y * rect.height),
        CornerId.tr: Offset(rect.left + q.tr.x * rect.width,
            rect.top + q.tr.y * rect.height),
        CornerId.br: Offset(rect.left + q.br.x * rect.width,
            rect.top + q.br.y * rect.height),
        CornerId.bl: Offset(rect.left + q.bl.x * rect.width,
            rect.top + q.bl.y * rect.height),
      };
      CornerId? nearest;
      double best = 40;
      corners.forEach((id, pos) {
        final d = (pos - local).distance;
        if (d < best) {
          best = d;
          nearest = id;
        }
      });
      _activeCorner = nearest;
    }
    if (_activeCorner == null) return;
    final nx = ((local.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final ny = ((local.dy - rect.top) / rect.height).clamp(0.0, 1.0);
    widget.controller.updateCorner(_activeCorner!, Point(nx, ny));
  }

  /// 纯可视手柄（不参与手势，由父层 GestureDetector 统一处理）。
  Widget _handle(Offset pos) {
    return Positioned(
      left: pos.dx - 15,
      top: pos.dy - 15,
      child: IgnorePointer(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.open_with, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// 绘制四边形选区轮廓。
class _QuadPainter extends CustomPainter {
  final List<Offset> points;

  _QuadPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();
    canvas.drawPath(path, paint);
    // 半透明遮罩（选区外变暗）
    final mask = Paint()..color = Colors.black.withOpacity(0.25);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addPolygon(points, true),
      ),
      mask,
    );
  }

  @override
  bool shouldRepaint(covariant _QuadPainter old) => old.points != points;
}
