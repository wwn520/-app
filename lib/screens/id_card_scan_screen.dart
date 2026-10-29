import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';
import 'package:printer_app/id_card_scan/corner_editor_controller.dart';
import 'package:printer_app/id_card_scan/edge_detector.dart';
import 'package:printer_app/id_card_scan/perspective_corrector.dart';
import 'package:printer_app/models/id_card.dart';
import 'package:printer_app/widgets/corner_editor_overlay.dart';

/// 身份证扫描页：上传正反面 → 端侧校正 → 拼版。
///
/// 全程本地处理，零网络调用（隐私红线）。
/// - 自动：EdgeDetector 纯 Dart 四角检测 + PerspectiveCorrector 校正；
///   置信度不足或失败时回退手动四角拖拽（P1-4）。
/// - 高清：edge_detection 原生相机/相册采集 + 交互裁切（更高精度自动裁边）。
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
  Uint8List? _frontCorrected;
  Uint8List? _backCorrected;

  bool _manualMode = false;
  bool _editingFront = true; // 手动模式下当前编辑哪一面
  bool _busy = false;

  final CornerEditorController _frontCtrl = CornerEditorController();
  final CornerEditorController _backCtrl = CornerEditorController();

  bool get _ready => _frontCorrected != null && _backCorrected != null;

  Future<Uint8List> _bytes(ImportedImage im) async =>
      im.bytes ?? await File(im.path).readAsBytes();

  Future<void> _pick(ImageSource source, bool isFront) async {
    final list =
        await ref.read(ServiceProviders.importManager).pickFrom(source);
    if (list.isEmpty) return;
    final im = list.first;
    final src = await _bytes(im);
    setState(() {
      if (isFront) {
        _front = im;
        _frontSrc = src;
      } else {
        _back = im;
        _backSrc = src;
      }
      _resetCorrection();
    });
  }

  void _resetCorrection() {
    _frontCorrected = null;
    _backCorrected = null;
    _frontQuad = null;
    _backQuad = null;
    _manualMode = false;
  }

  /// 自动识别并校正（纯 Dart 四角检测）。
  Future<void> _autoDetect() async {
    if (_front == null || _back == null) return;
    setState(() => _busy = true);
    try {
      final detector = EdgeDetector();
      final fb = _frontSrc!;
      final bb = _backSrc!;
      final fr = await detector.detect(fb);
      final br = await detector.detect(bb);
      _frontQuad = fr?.quad;
      _backQuad = br?.quad;
      if (fr != null && br != null) {
        // 双达标：直接自动校正
        _frontCorrected = await PerspectiveCorrector.correct(fb, fr.quad);
        _backCorrected = await PerspectiveCorrector.correct(bb, br.quad);
        _manualMode = false;
      } else {
        // 任一侧不达标：进入手动兜底（已自动校正的可直接采用，并作为手动编辑起点）
        _manualMode = true;
        if (fr != null) {
          _frontCorrected =
              await PerspectiveCorrector.correct(fb, fr.quad);
          _frontCtrl.setQuad(fr.quad);
        }
        if (br != null) {
          _backCorrected = await PerspectiveCorrector.correct(bb, br.quad);
          _backCtrl.setQuad(br.quad);
        }
      }
      setState(() {});
    } catch (_) {
      _manualMode = true;
      setState(() {});
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 高清裁边（edge_detection 原生相机/相册采集 + 交互裁切），绕过四角直接得到校正图。
  ///
  /// 注意：真实 edge_detection 的静态方法为「采集 → 裁切」流程（不接受已有图片），
  /// 因此此方法会启动原生采集+裁切，并将结果写入应用临时目录，不直接复用已导入原图。
  Future<void> _nativeCrop(ImportedImage im, bool isFront) async {
    setState(() => _busy = true);
    try {
      final detector = EdgeDetector();
      final cropped = await detector.autoCropNative();
      if (cropped != null) {
        final bytes = await File(cropped).readAsBytes();
        setState(() {
          if (isFront) {
            _frontCorrected = bytes;
          } else {
            _backCorrected = bytes;
          }
        });
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 手动模式：应用当前四角校正。
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
      setState(() {});
    } finally {
      setState(() => _busy = false);
    }
  }

  void _proceed() {
    if (!_ready) return;
    final scan = IdCardScan(front: _front!, back: _back!);
    scan.frontCorners = _frontQuad;
    scan.backCorners = _backQuad;
    scan.correctedFront = _frontCorrected;
    scan.correctedBack = _backCorrected;
    scan.manualMode = _manualMode;
    ref.read(FlowProviders.idCardScan.notifier).state = scan;
    AppRoutes.go(context, AppRoutes.preview);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _front != null && _back != null;
    final canOverlay = _manualMode &&
        ((_editingFront && _frontSrc != null) ||
            (!_editingFront && _backSrc != null));
    return Scaffold(
      appBar: AppBar(title: const Text('身份证打印')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _PickSlot(
              label: '人像面',
              image: _front,
              onPick: () => _pick(ImageSource.album, true),
              onCrop: _front == null
                  ? null
                  : () => _nativeCrop(_front!, true),
            ),
            const SizedBox(height: 12),
            _PickSlot(
              label: '国徽面',
              image: _back,
              onPick: () => _pick(ImageSource.album, false),
              onCrop: _back == null
                  ? null
                  : () => _nativeCrop(_back!, false),
            ),
            const SizedBox(height: 16),
            if (canEdit) ...[
              ElevatedButton(
                onPressed: _busy ? null : _autoDetect,
                child: const Text('自动识别并校正'),
              ),
              const SizedBox(height: 8),
              if (_manualMode) ...[
                const Text('自动置信度不足，请拖拽四角手动校正',
                    style: TextStyle(color: Colors.orange)),
                const SizedBox(height: 8),
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
                      : const Center(child: Text('请先选择图片')),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _applyManual,
                  child: const Text('应用手动校正'),
                ),
              ],
            ],
            const SizedBox(height: 12),
            if (_frontCorrected != null && _backCorrected != null)
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

/// 单面选择槽。
class _PickSlot extends StatelessWidget {
  final String label;
  final ImportedImage? image;
  final VoidCallback onPick;
  final VoidCallback? onCrop;

  const _PickSlot({
    required this.label,
    required this.image,
    required this.onPick,
    this.onCrop,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = image?.bytes != null
        ? Image.memory(image!.bytes!, fit: BoxFit.cover)
        : (image != null
            ? Image.file(File(image!.path), fit: BoxFit.cover)
            : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey));
    return Row(
      children: [
        Container(
          width: 72,
          height: 96,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: thumbnail,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  TextButton(onPressed: onPick, child: const Text('选择')),
                  if (onCrop != null)
                    TextButton(onPressed: onCrop, child: const Text('高清裁边')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 校正结果预览（上下布局，与默认拼版一致）。
class _CorrectedPreview extends StatelessWidget {
  final Uint8List front;
  final Uint8List back;
  const _CorrectedPreview({required this.front, required this.back});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('校正预览（正面上 / 国徽面下）'),
        const SizedBox(height: 6),
        Image.memory(front, height: 110, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Image.memory(back, height: 110, fit: BoxFit.contain),
      ],
    );
  }
}
