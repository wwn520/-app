import 'package:flutter_test/flutter_test.dart';
import 'package:printer_app/core/constants.dart';

/// 常量层测试：A4 尺寸、IPP 操作码、探活参数、纸张/色彩取值。
void main() {
  group('Constants 全局常量', () {
    test('A4 @72dpi 尺寸与物理 210mm×297mm 一致', () {
      // 210mm / 25.4 * 72 = 595.28；297mm / 25.4 * 72 = 841.89
      expect(Constants.a4WidthPt, closeTo(595.28, 0.01));
      expect(Constants.a4HeightPt, closeTo(841.89, 0.01));
    });

    test('纸张/色彩/介质取值符合 IPP 规范', () {
      // media 必须为 PWG 5101.1 self-describing 关键字（iso_a4 非法会被拒收）
      expect(Constants.mediaA4, 'iso_a4_210x297mm');
      expect(Constants.printColorModeMono, 'monochrome');
      expect(Constants.printColorModeColor, 'color');
      expect(Constants.sidesOneSided, 'one-sided');
      expect(Constants.documentFormat, 'application/pdf');
    });

    test('IPP 操作码正确（Print-Job=0x0002 / Get-Printer-Attributes=0x000B）', () {
      expect(Constants.operationPrintJob, 0x0002);
      expect(Constants.operationGetPrinterAttributes, 0x000B);
    });

    test('探活参数：15s 周期 / 3s 超时（满足 30s 内转离线）', () {
      expect(Constants.livenessIntervalSeconds, 15);
      expect(Constants.livenessTimeoutSeconds, 3);
    });

    test('字符集/语言/请求用户名', () {
      expect(Constants.charset, 'utf-8');
      expect(Constants.naturalLanguage, 'en'); // RFC 4646 主标签
      expect(Constants.requestingUserName, 'printer_app');
      expect(Constants.ippDefaultPath, '/ipp/print');
    });

    test('print-quality 枚举值符合 RFC 8011（draft=3/normal=4/high=5）', () {
      expect(Constants.printQualityDraft, 3);
      expect(Constants.printQualityNormal, 4);
      expect(Constants.printQualityHigh, 5);
    });
  });
}
