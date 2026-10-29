import 'package:flutter/material.dart';

import 'package:printer_app/pdf_layout/id_card_compositor.dart';

/// A4 比例版面预览。
///
/// 在 A4 比例（1:√2）的白底卡片内展示待打印内容：
/// - 普通单图：居中 contain；
/// - 多图：2 列网格（与 PDF N 合一对齐）；
/// - 身份证：[idCardLayout] 决定上下 / 左右摆放（与拼版一致，所见即所得）。
class A4PreviewWidget extends StatelessWidget {
  final List<Uint8List> images;
  final CardLayout? idCardLayout;
  final String? caption;

  const A4PreviewWidget({
    super.key,
    required this.images,
    this.idCardLayout,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1 / 1.414, // A4
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildContent(),
            ),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(caption!, style: const TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (images.isEmpty) {
      return const Center(child: Text('暂无预览', style: TextStyle(color: Colors.grey)));
    }
    if (idCardLayout != null && images.length >= 2) {
      if (idCardLayout == CardLayout.topBottom) {
        return Column(
          children: [
            Expanded(child: Image.memory(images[0], fit: BoxFit.contain)),
            const SizedBox(height: 4),
            Expanded(child: Image.memory(images[1], fit: BoxFit.contain)),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: Image.memory(images[0], fit: BoxFit.contain)),
          const SizedBox(width: 4),
          Expanded(child: Image.memory(images[1], fit: BoxFit.contain)),
        ],
      );
    }
    if (images.length == 1) {
      return Image.memory(images[0], fit: BoxFit.contain);
    }
    return GridView.count(
      crossAxisCount: 2,
      children: images
          .map((b) => Image.memory(b, fit: BoxFit.contain))
          .toList(),
    );
  }
}
