import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printer_app/models/print_settings.dart';
import 'package:printer_app/pdf_layout/id_card_compositor.dart';
import 'package:printer_app/pdf_layout/image_preprocess.dart';

/// PDF 排版：把图片（单图 / 多合一 / 身份证拼版）排版到 A4。
///
/// 文档统一为 application/pdf（A4），黑白模式在嵌入前做灰度转换，
/// 与 IPP print-color-mode 形成双重保险。
class PdfBuilder {
  /// 单张图片排版到 A4（BoxFit.contain，居中留白）。
  static Future<Uint8List> buildSingle(
      Uint8List imageBytes, PrintSettings settings) async {
    final processed =
        ImagePreprocess.applyColorMode(imageBytes, settings.colorMode);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Center(
          child: pw.Image(pw.MemoryImage(processed), fit: pw.BoxFit.contain),
        ),
      ),
    );
    return doc.save();
  }

  /// 多图网格排版到一页 A4（[perPage] 张一页，N 合一）。
  static Future<Uint8List> buildGrid(
      List<Uint8List> images, int perPage, PrintSettings settings) async {
    final processed = images
        .map((b) => ImagePreprocess.applyColorMode(b, settings.colorMode))
        .toList();
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.GridView(
          crossAxisCount: _columns(perPage),
          childAspectRatio: 1.0,
          children: processed
              .map((b) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(pw.MemoryImage(b), fit: pw.BoxFit.contain),
                  ))
              .toList(),
        ),
      ),
    );
    return doc.save();
  }

  /// 身份证两面拼版到 A4。
  static Future<Uint8List> buildIdCard(
    Uint8List frontBytes,
    Uint8List backBytes, {
    bool flipBack = false,
    CardLayout layout = CardLayout.topBottom,
  }) async {
    final composite = IdCardCompositor.compose(
      frontBytes,
      backBytes,
      flipBack: flipBack,
      layout: layout,
    );
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Center(
          child: pw.Image(pw.MemoryImage(composite), fit: pw.BoxFit.contain),
        ),
      ),
    );
    return doc.save();
  }

  /// 根据每页张数推断网格列数。
  static int _columns(int perPage) {
    if (perPage <= 1) return 1;
    if (perPage <= 4) return 2;
    return 3;
  }
}
