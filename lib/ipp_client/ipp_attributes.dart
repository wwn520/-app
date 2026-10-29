import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_app/core/constants.dart';
import 'package:printer_app/models/print_settings.dart';
import 'package:printer_app/models/printer.dart';

/// IPP 属性标签常量（RFC 8010 §3.5.2 Table 6 / Table 4）。
///
/// 这些字节值必须与现行 RFC 8010 一致，否则真实打印机将拒绝或误解析请求。
class IppTags {
  // 分隔标签
  static const int operationsAttributesTag = 0x01;
  static const int jobAttributesTag = 0x02;
  static const int endOfAttributesTag = 0x03;
  static const int printerAttributesTag = 0x04;

  // 值标签（RFC 8010 标准值）
  static const int integer = 0x21; // 4 字节有符号整数
  static const int boolean = 0x22; // 1 字节布尔
  static const int enumTag = 0x23; // 4 字节枚举
  static const int octetString = 0x30; // 八位字节串
  static const int textWithoutLanguage = 0x41; // 无语言文本
  static const int nameWithoutLanguage = 0x42; // 无语言名称
  static const int keyword = 0x44; // 关键字
  static const int uri = 0x45; // URI
  static const int charset = 0x47; // 字符集
  static const int naturalLanguage = 0x48; // 自然语言
  static const int mimeMediaType = 0x49; // MIME 类型
}

/// 单个 IPP 属性条目：标签 + 名称 + 值字节。
class IppAttributeEntry {
  final int tag;
  final String name;
  final Uint8List value;

  const IppAttributeEntry(this.tag, this.name, this.value);
}

/// 属性组：分隔标签 + 一组属性条目。
class IppAttributeGroup {
  final int groupTag;
  final List<IppAttributeEntry> entries;

  const IppAttributeGroup(this.groupTag, this.entries);
}

/// IPP 属性构造工具：把业务参数翻译为二进制属性组。
///
/// 这些组会被 [IppMessage.encode] 序列化为二进制 IPP 报文。
class IppAttributes {
  /// 通用操作属性组（operations-attributes-tag），所有操作都需要。
  static List<IppAttributeGroup> _commonOperations(Printer printer) => [
        IppAttributeGroup(IppTags.operationsAttributesTag, [
          IppAttributeEntry(
              IppTags.charset, 'attributes-charset', _utf8(Constants.charset)),
          IppAttributeEntry(IppTags.naturalLanguage,
              'attributes-natural-language', _utf8(Constants.naturalLanguage)),
          IppAttributeEntry(
              IppTags.uri, 'printer-uri', _utf8(printer.ippUri.toString())),
          IppAttributeEntry(IppTags.nameWithoutLanguage, 'requesting-user-name',
              _utf8(Constants.requestingUserName)),
        ]),
      ];

  /// Print-Job 属性组（含 document-format / print-color-mode / media / copies / sides / print-quality）。
  static List<IppAttributeGroup> printJob(Printer printer, PrintSettings s) {
    final groups = _commonOperations(printer);
    // 将 document-format 并入首个操作属性组（与 charset / natural-language 同组），
    // 以兼容对属性分组较严格的打印机（RFC 2911 允许重复组，但部分实现更期望同组）。
    groups.first.entries.add(IppAttributeEntry(IppTags.mimeMediaType,
        'document-format', _utf8(Constants.documentFormat)));
    groups.add(IppAttributeGroup(IppTags.jobAttributesTag, [
      IppAttributeEntry(
          IppTags.nameWithoutLanguage,
          'job-name',
          _utf8(
              '${Constants.jobName}_${DateTime.now().millisecondsSinceEpoch}')),
      IppAttributeEntry(IppTags.integer, 'copies', _int4(s.copies)),
      IppAttributeEntry(
          IppTags.keyword,
          'print-color-mode',
          _utf8(s.colorMode == ColorMode.grayscale
              ? Constants.printColorModeMono
              : Constants.printColorModeColor)),
      IppAttributeEntry(
          IppTags.keyword, 'media', _utf8(Constants.mediaA4)),
      IppAttributeEntry(
          IppTags.keyword, 'sides', _utf8(Constants.sidesOneSided)),
      // print-quality（RFC 8011 §5.2.13）：enum 编码，draft=3 / normal=4 / high=5
      IppAttributeEntry(
          IppTags.enumTag, 'print-quality', _int4(_qualityValue(s.quality))),
    ]));
    return groups;
  }

  /// Get-Printer-Attributes 属性组（探活）。
  ///
  /// 注意：所有操作属性必须在**同一个** operations-attributes-tag 组内；
  /// `requested-attributes` 为 1setOf keyword，这里合并为**单个** keyword 条目、
  /// 值用逗号分隔（重复写同名完整条目违反 RFC 8010，会被真实打印机拒收）。
  static List<IppAttributeGroup> getPrinterAttributes(Printer printer) {
    final groups = _commonOperations(printer);
    groups.first.entries.add(IppAttributeEntry(
        IppTags.keyword,
        'requested-attributes',
        _utf8('printer-state,printer-is-accepting-jobs')));
    return groups;
  }

  /// PrintSettings.quality → IPP print-quality 枚举值。
  static int _qualityValue(PrintQuality quality) {
    switch (quality) {
      case PrintQuality.draft:
        return Constants.printQualityDraft;
      case PrintQuality.normal:
        return Constants.printQualityNormal;
      case PrintQuality.high:
        return Constants.printQualityHigh;
    }
  }

  // ── 值编码辅助 ──
  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  /// 4 字节大端有符号整数。
  static Uint8List _int4(int v) => Uint8List(4)
    ..[0] = (v >> 24) & 0xFF
    ..[1] = (v >> 16) & 0xFF
    ..[2] = (v >> 8) & 0xFF
    ..[3] = v & 0xFF;
}
