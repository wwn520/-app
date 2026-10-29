import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_app/core/constants.dart';
import 'package:printer_app/ipp_client/ipp_attributes.dart';
import 'package:printer_app/ipp_client/ipp_message.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/models/print_settings.dart';

/// 轻量 IPP 字节解析器（仅用于测试断言，复刻 IppMessage 的字段布局）：
/// 跳过 version(2)+op/status(2)+request-id(4)，逐属性读取
/// value-tag / nameLen / name / valueLen / value。
Map<String, Map<String, Object>> parseIpp(Uint8List bytes) {
  final out = <String, Map<String, Object>>{};
  var offset = 8;
  while (offset < bytes.length) {
    final tag = bytes[offset++];
    if (tag == 0x03) break; // end-of-attributes
    if (tag >= 0x01 && tag <= 0x09) continue; // 分隔标签
    final nameLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final name = String.fromCharCodes(bytes.sublist(offset, offset + nameLen));
    offset += nameLen;
    final valueLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final value = Uint8List.fromList(bytes.sublist(offset, offset + valueLen));
    offset += valueLen;
    out[name] = {'tag': tag, 'value': value};
  }
  return out;
}

Printer _printer() => Printer(
      id: 'epson',
      name: 'EPSON L3250 Series',
      host: '192.168.1.50',
      port: 631,
      ippPath: '/ipp/print',
      status: PrinterStatus.unknown,
      lastSeen: DateTime.now(),
    );

void main() {
  final msg = IppMessage();

  group('IppMessage 报文头', () {
    test('版本 1.1 + Print-Job 操作码 0x0002 + request-id=1', () {
      final groups = IppAttributes.printJob(_printer(), const PrintSettings());
      final bytes = msg.encode(Constants.operationPrintJob, groups, Uint8List(8));
      expect(bytes[0], 0x01);
      expect(bytes[1], 0x01);
      expect(bytes[2], 0x00);
      expect(bytes[3], 0x02);
      expect(bytes[4], 0x00);
      expect(bytes[5], 0x00);
      expect(bytes[6], 0x00);
      expect(bytes[7], 0x01);
    });

    test('Get-Printer-Attributes 操作码 0x000B', () {
      final groups = IppAttributes.getPrinterAttributes(_printer());
      final bytes =
          msg.encode(Constants.operationGetPrinterAttributes, groups);
      expect(bytes[2], 0x00);
      expect(bytes[3], 0x0B);
    });
  });

  group('Print-Job 关键属性字节/标签（RFC 8010）', () {
    test('属性名/值标签/取值正确', () {
      final groups =
          IppAttributes.printJob(_printer(), const PrintSettings());
      final bytes =
          msg.encode(Constants.operationPrintJob, groups, Uint8List(8));
      final attrs = parseIpp(bytes);

      // 操作属性组
      expect(attrs['attributes-charset']!['tag'], 0x47);
      expect(String.fromCharCodes(attrs['attributes-charset']!['value'] as Uint8List),
          'utf-8');
      expect(attrs['attributes-natural-language']!['tag'], 0x48);
      expect(
          String.fromCharCodes(
              attrs['attributes-natural-language']!['value'] as Uint8List),
          'en-us');
      expect(attrs['printer-uri']!['tag'], 0x45);
      expect(attrs['document-format']!['tag'], 0x49);
      expect(String.fromCharCodes(attrs['document-format']!['value'] as Uint8List),
          'application/pdf');

      // 作业属性组
      expect(attrs['print-color-mode']!['tag'], 0x44);
      expect(String.fromCharCodes(attrs['print-color-mode']!['value'] as Uint8List),
          'monochrome');
      expect(attrs['media']!['tag'], 0x44);
      expect(String.fromCharCodes(attrs['media']!['value'] as Uint8List),
          'iso_a4');
      expect(attrs['sides']!['tag'], 0x44);
      expect(String.fromCharCodes(attrs['sides']!['value'] as Uint8List),
          'one-sided');

      // copies 为整数(0x21)，4 字节大端
      expect(attrs['copies']!['tag'], 0x21);
      final c = attrs['copies']!['value'] as Uint8List;
      expect(c.length, 4);
      final copies =
          (c[0] << 24) | (c[1] << 16) | (c[2] << 8) | c[3];
      expect(copies, 1);

      // 名称类属性用 nameWithoutLanguage(0x42)
      expect(attrs['job-name']!['tag'], 0x42);
      expect(attrs['requesting-user-name']!['tag'], 0x42);
    });

    test('彩色模式 → print-color-mode=color', () {
      final groups = IppAttributes.printJob(
          _printer(), const PrintSettings(colorMode: ColorMode.color));
      final bytes =
          msg.encode(Constants.operationPrintJob, groups, Uint8List(8));
      final attrs = parseIpp(bytes);
      expect(String.fromCharCodes(attrs['print-color-mode']!['value'] as Uint8List),
          'color');
    });

    test('多份数 → copies 大端编码正确', () {
      final groups = IppAttributes.printJob(
          _printer(), const PrintSettings(copies: 3));
      final bytes =
          msg.encode(Constants.operationPrintJob, groups, Uint8List(8));
      final attrs = parseIpp(bytes);
      final c = attrs['copies']!['value'] as Uint8List;
      final copies = (c[0] << 24) | (c[1] << 16) | (c[2] << 8) | c[3];
      expect(copies, 3);
    });
  });

  group('IppMessage.decode 响应解析', () {
    test('成功状态码 + job-id 解析', () {
      final b = BytesBuilder();
      b.addByte(0x01);
      b.addByte(0x01); // version 1.1
      b.addByte(0x00);
      b.addByte(0x00); // status successful-ok
      b.addByte(0x00);
      b.addByte(0x00);
      b.addByte(0x00);
      b.addByte(0x01); // request-id
      b.addByte(0x01); // operations-attributes-tag
      b.addByte(0x21); // integer
      final name = utf8.encode('job-id');
      b.addByte((name.length >> 8) & 0xFF);
      b.addByte(name.length & 0xFF);
      b.add(name);
      b.addByte(0x00);
      b.addByte(0x04); // value length 4
      b.addByte(0x00);
      b.addByte(0x00);
      b.addByte(0x00);
      b.addByte(0x07); // job-id = 7
      b.addByte(0x03); // end-of-attributes

      final resp = msg.decode(b.toBytes());
      expect(resp.isSuccessful, isTrue);
      expect(resp.jobId, 7);
    });

    test('非成功状态码 → isSuccessful=false', () {
      final b = BytesBuilder();
      b.addByte(0x01);
      b.addByte(0x01);
      b.addByte(0x04);
      b.addByte(0x0A); // client-error-not-possible
      b.addByte(0x00);
      b.addByte(0x00);
      b.addByte(0x00);
      b.addByte(0x01);
      b.addByte(0x03);
      final resp = msg.decode(b.toBytes());
      expect(resp.isSuccessful, isFalse);
    });
  });
}
