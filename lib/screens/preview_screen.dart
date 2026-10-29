import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';
import 'package:printer_app/models/id_card.dart';
import 'package:printer_app/pdf_layout/id_card_compositor.dart';
import 'package:printer_app/pdf_layout/pdf_builder.dart';
import 'package:printer_app/settings/settings_provider.dart';
import 'package:printer_app/widgets/a4_preview_widget.dart';

/// A4 版面预览 + 生成 PDF。
///
/// 普通模式：单图铺满 / 多图 N 合一网格；
/// 身份证模式：正面上 + 国徽面下（与拼版一致）。
/// 「生成并打印」按当前设置生成 A4 PDF 并进入打印状态页。
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(FlowProviders.printMode);
    final images = ref.watch(FlowProviders.importedImages);
    final idCard = ref.watch(FlowProviders.idCardScan);
    final printer = ref.watch(FlowProviders.selectedPrinter);

    // 预览图（布局与 PDF 一致，所见即所得）
    final previewImages = <Uint8List>[];
    CardLayout? layout;
    if (mode == PrintMode.idCard && idCard != null) {
      if (idCard.correctedFront != null) {
        previewImages.add(idCard.correctedFront!);
      }
      if (idCard.correctedBack != null) {
        previewImages.add(idCard.correctedBack!);
      }
      layout = CardLayout.topBottom;
    } else {
      for (final im in images) {
        if (im.bytes != null) previewImages.add(im.bytes!);
      }
    }

    final canPrint = printer != null && previewImages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('A4 预览')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: A4PreviewWidget(
                images: previewImages,
                idCardLayout: layout,
                caption: 'A4 版面预览（与实际打印一致）',
              ),
            ),
          ),
          if (printer == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('未选择打印机，请返回首页选择',
                  style: TextStyle(color: Colors.red)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: canPrint
                  ? () => _generateAndPrint(context, ref, mode, images, idCard)
                  : null,
              child: const Text('生成并打印'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrint(
    BuildContext context,
    WidgetRef ref,
    PrintMode mode,
    List<ImportedImage> images,
    IdCardScan? idCard,
  ) async {
    final settings = ref.read(SettingsProviders.settings);
    final printer = ref.read(FlowProviders.selectedPrinter);
    Uint8List pdf;
    if (mode == PrintMode.idCard && idCard != null) {
      pdf = await PdfBuilder.buildIdCard(
        idCard.correctedFront!,
        idCard.correctedBack!,
        layout: CardLayout.topBottom,
      );
    } else if (images.length == 1) {
      final img = images.first;
      final bytes = img.bytes ?? await File(img.path).readAsBytes();
      pdf = await PdfBuilder.buildSingle(bytes, settings);
    } else {
      final bytesList = await Future.wait(images.map((im) =>
          im.bytes != null
              ? Future<Uint8List>.value(im.bytes!)
              : File(im.path).readAsBytes()));
      pdf = await PdfBuilder.buildGrid(bytesList, bytesList.length, settings);
    }

    ref.read(FlowProviders.generatedPdf.notifier).state = pdf;
    // 记录常用打印机（P1-1）
    if (printer != null) {
      await ref.read(SettingsProviders.service).saveFrequentPrinter(printer);
    }
    if (context.mounted) {
      AppRoutes.go(context, AppRoutes.printStatus);
    }
  }
}
