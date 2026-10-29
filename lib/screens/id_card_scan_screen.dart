import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';
import 'package:printer_app/app/theme.dart';
import 'package:printer_app/id_card_scan/corner_editor_controller.dart';
import 'package:printer_app/id_card_scan/edge_detector.dart';
import 'package:printer_app/id_card_scan/perspective_corrector.dart';
import 'package:printer_app/models/id_card.dart';
import 'package:printer_app/widgets/corner_editor_overlay.dart';
import 'package:printer_app/widgets/source_picker_sheet.dart';

/// 身份证扫描页：按导入顺序自动认定正反面 → 默认原图直出 → 拼版。
///
/// 全程本地处理，零网络调用（隐私红线）。
/// 流程以「少操作、不裁坏」为原则：
/// - **自动认定**：第 1 张 = 正面（人像面），第 2 张 = 国徽面；
///   点缩略图可对调作为兜底，无需手动指定正反面。
/// - **默认原图**：导入即视为校正完成（拼版时等比 contain 缩放、白底居中，
///   绝不裁掉内容）。
/// - **智能裁边（可选增强）**：置信度达标才应用透视校正，任一面置信度不足
///   自动回退该面原图。
/// - **手动四角**：保留为二级入口。
class IdCardScanScreen extends ConsumerStatefulWidget {
  const IdCardScanScreen({super.key});

  @override
  ConsumerState<IdCardScanScreen> createState() => _IdCardScanScreenState();
}

class _IdCardScanScreenState extends ConsumerState<IdCardScanScreen> {
  ImportedImage? _front;
  ImportedImage? _back;
  Uint8List? _frontSrc; // 原图字节（用于显示与校正）
  Uint8List? _backSrc;

  Quad? _frontQuad;
  Quad? _backQuad;
  Uint8List? _frontCorrected; // 默认 = 原图
  Uint8List? _backCorrected;

  bool _manualMode = false;
  bool _editingFront = true; // 手动模式下当前编辑哪一面
  bool _busy = false;

  final CornerEditorController _frontCtrl = CornerEditorController();
  final CornerEditorController _backCtrl = CornerEditorController();

  bool get _ready => _frontCorrected != null && _backCorrected != null;

  Future<Uint8List> _bytes(ImportedImage im) async =>
      im.bytes ?? await File(im.path).readAsBytes();

  /// 导入图片（相册 / 拍照 / 分享），按导入顺序自动认定正反面。
  Future<void> _import() async {
    final source = await SourcePickerSheet.show(context);
    if (source == null) return;
    final list =
        await ref.read(ServiceProviders.importManager).pickFrom(source);
    if (list.isEmpty) return;

    // 顺序填入空槽；两槽都已满时，用新导入的前两张整体替换。
    ImportedImage? front = _front;
    ImportedImage? back = _back;
    final queue = list.toList();
    if (front == null && queue.isNotEmpty) front = queue.removeAt(0);
    if (back == null && queue.isNotEmpty) back = queue.removeAt(0);
    if (queue.isNotEmpty) {
      front = list[0];
      back = list.length > 1 ? list[1] : null;
    }

    setState(() => _busy = true);
    try {
      final frontBytes = front != null ? await _bytes(front) : null;
      final backBytes = back != null ? await _bytes(back) : null;
      if (!mounted) return;
      setState(() {
        _front = front;
        _back = back;
        _frontSrc = frontBytes;
        _backSrc = backBytes;
        // 默认直接使用原图（不裁剪，杜绝「裁坏」）。
        _frontCorrected = frontBytes;
        _backCorrected = backBytes;
        _frontQuad = null;
        _backQuad = null;
        _manualMode = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 点缩略图/对调按钮交换正反面（兜底，无需手动指定）。
  void _swap() {
    if (_front == null || _back == null) return;
    setState(() {
      final f = _front;
      _front = _back;
      _back = f;
      final fs = _frontSrc;
      _frontSrc = _backSrc;
      _backSrc = fs;
      final fc = _frontCorrected;
      _frontCorrected = _backCorrected;
      _backCorrected = fc;
      final fq = _frontQuad;
      _frontQuad = _backQuad;
      _backQuad = fq;
    });
    // 手动模式下同步交换编辑起点。
    if (_manualMode) {
      _frontCtrl.setQuad(_frontQuad ?? _defaultQuad());
      _backCtrl.setQuad(_backQuad ?? _defaultQuad());
    }
  }

  /// 智能裁边（可选增强）：置信度达标才应用，否则自动回退原图。
  Future<void> _autoEnhance() async {
    if (_frontSrc == null || _backSrc == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final detector = EdgeDetector();
      final fr = await detector.detect(_frontSrc!);
      final br = await detector.detect(_backSrc!);
      Uint8List? frontEnhanced;
      Uint8List? backEnhanced;
      if (fr != null) {
        frontEnhanced =
            await PerspectiveCorrector.correct(_frontSrc!, fr.quad);
      }
      if (br != null) {
        backEnhanced =
            await PerspectiveCorrector.correct(_backSrc!, br.quad);
      }
      if (!mounted) return;
      setState(() {
        if (frontEnhanced != null) {
          _frontCorrected = frontEnhanced;
          _frontQuad = fr!.quad;
          _frontCtrl.setQuad(fr.quad);
        }
        if (backEnhanced != null) {
          _backCorrected = backEnhanced;
          _backQuad = br!.quad;
          _backCtrl.setQuad(br.quad);
        }
        _manualMode = false;
      });
      if (frontEnhanced == null || backEnhanced == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('部分识别置信度不足，已保留原图，可尝试手动调整四角')));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('自动识别失败，已保留原图')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 手动模式：应用当前四角校正（二级入口）。
  Future<void> _applyManual() async {
    if (_frontSrc == null || _backSrc == null) return;
    setState(() => _busy = true);
    try {
      _frontCorrected =
          await PerspectiveCorrector.correct(_frontSrc!, _frontCtrl.quad);
      _backCorrected =
          await PerspectiveCorrector.correct(_backSrc!, _backCtrl.quad);
      _frontQuad = _frontCtrl.quad;
      _backQuad = _backCtrl.quad;
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _proceed() {
    if (!_ready || _front == null || _back == null) return;
    final scan = IdCardScan(front: _front!, back: _back!);
    scan.frontCorners = _frontQuad;
    scan.backCorners = _backQuad;
    scan.correctedFront = _frontCorrected;
    scan.correctedBack = _backCorrected;
    scan.manualMode = _manualMode;
    ref.read(FlowProviders.idCardScan.notifier).state = scan;
    AppRoutes.go(context, AppRoutes.preview);
  }

  /// 控制器默认四角（与 CornerEditorController 初始值一致）。
  static Quad _defaultQuad() => Quad(
        tl: const math.Point(0.12, 0.12),
        tr: const math.Point(0.88, 0.12),
        br: const math.Point(0.88, 0.88),
        bl: const math.Point(0.12, 0.88),
      );

  @override
  Widget build(BuildContext context) {
    final canSwap = _front != null && _back != null;
    final canOverlay = _manualMode &&
        ((_editingFront && _frontSrc != null) ||
            (!_editingFront && _backSrc != null));
    return Scaffold(
      appBar: AppBar(title: const Text('身份证打印')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('按导入顺序自动认定：第 1 张 = 正面（人像面），第 2 张 = 国徽面',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.muted)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _FaceSlot(
                    label: '正面（人像面）',
                    image: _front,
                    onTap: canSwap ? _swap : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    onPressed: canSwap ? _swap : null,
                    tooltip: '对调正反面',
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ),
                Expanded(
                  child: _FaceSlot(
                    label: '背面（国徽面）',
                    image: _back,
                    onTap: canSwap ? _swap : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _import,
              child: Text(_front == null
                  ? '导入图片（第 1 张）'
                  : (_back == null ? '继续导入（第 2 张）' : '重新导入')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: (_busy || !canSwap) ? null : _autoEnhance,
              child: const Text('智能裁边（可选增强，失败自动保留原图）'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: (_busy || !canSwap)
                  ? null
                  : () => setState(() => _manualMode = !_manualMode),
              child: Text(_manualMode ? '收起手动四角调整' : '手动调整四角'),
            ),
            if (_manualMode) ...[
              const SizedBox(height: 4),
              ToggleButtons(
                isSelected: [_editingFront, !_editingFront],
                onPressed: (i) => setState(() => _editingFront = i == 0),
                children: const [
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('人像面')),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('国徽面')),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: canOverlay
                    ? CornerEditorOverlay(
                        imageBytes:
                            _editingFront ? _frontSrc! : _backSrc!,
                        controller:
                            _editingFront ? _frontCtrl : _backCtrl,
                      )
                    : const Center(child: Text('请先导入图片')),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _busy ? null : _applyManual,
                child: const Text('应用手动校正'),
              ),
            ],
            const SizedBox(height: 16),
            if (_ready)
              _CorrectedPreview(
                  front: _frontCorrected!, back: _backCorrected!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_ready && !_busy) ? _proceed : null,
              child: const Text('下一步：A4 预览'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 正/反面预览槽：点缩略图对调正反面。
class _FaceSlot extends StatelessWidget {
  final String label;
  final ImportedImage? image;
  final VoidCallback? onTap;

  const _FaceSlot({
    required this.label,
    required this.image,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = image?.bytes != null
        ? Image.memory(image!.bytes!, fit: BoxFit.cover)
        : (image != null
            ? Image.file(File(image!.path), fit: BoxFit.cover)
            : const Icon(Icons.add_a_photo, size: 36, color: Colors.grey));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 85.6 / 54.0, // 身份证标准比例
          child: GestureDetector(
            onTap: onTap, // 点缩略图对调正反面（兜底）
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumbnail,
            ),
          ),
        ),
      ],
    );
  }
}

/// 拼版结果预览（上下布局，与默认拼版一致）。
class _CorrectedPreview extends StatelessWidget {
  final Uint8List front;
  final Uint8List back;
  const _CorrectedPreview({required this.front, required this.back});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('拼版预览（正面上 / 国徽面下）'),
        const SizedBox(height: 6),
        Image.memory(front, height: 110, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Image.memory(back, height: 110, fit: BoxFit.contain),
      ],
    );
  }
}
