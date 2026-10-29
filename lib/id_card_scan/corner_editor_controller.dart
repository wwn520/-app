import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:printer_app/models/id_card.dart';

/// 四角标识。
enum CornerId { tl, tr, br, bl }

/// 手动四角拖拽状态管理（ChangeNotifier）。
///
/// 持有当前 [Quad]（归一化 0..1），供 [CornerEditorOverlay] 拖拽更新，
/// 与 [PerspectiveCorrector] 共用，实现手动兜底（P1-4）。
class CornerEditorController extends ChangeNotifier {
  Quad _quad;

  CornerEditorController({Quad? initial})
      : _quad = initial ??
            Quad(
              tl: const Point(0.12, 0.12),
              tr: const Point(0.88, 0.12),
              br: const Point(0.88, 0.88),
              bl: const Point(0.12, 0.88),
            );

  /// 当前四角。
  Quad get quad => _quad;

  /// 整体替换四角（用于自动检测完成后初始化手动编辑起点）。
  void setQuad(Quad q) {
    _quad = q;
    notifyListeners();
  }

  /// 更新某个角的归一化坐标（自动夹取到 0..1）。
  void updateCorner(CornerId id, Point<double> normalized) {
    final x = normalized.x.clamp(0.0, 1.0);
    final y = normalized.y.clamp(0.0, 1.0);
    switch (id) {
      case CornerId.tl:
        _quad = _quad.copyWith(tl: Point(x, y));
        break;
      case CornerId.tr:
        _quad = _quad.copyWith(tr: Point(x, y));
        break;
      case CornerId.br:
        _quad = _quad.copyWith(br: Point(x, y));
        break;
      case CornerId.bl:
        _quad = _quad.copyWith(bl: Point(x, y));
        break;
    }
    notifyListeners();
  }
}
