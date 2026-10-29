import 'package:flutter_test/flutter_test.dart';
import 'package:printer_app/ipp_client/ipp_attributes.dart';

/// IPP 值标签测试：断言各标签等于 RFC 8010 标准值。
/// 这些断言当前会与源码不符（源码误用了旧草案值），预期在工程师修复后通过。
void main() {
  group('IppTags 值标签 = RFC 8010 标准值', () {
    test('整数/布尔/枚举类', () {
      expect(IppTags.integer, 0x21);
      expect(IppTags.boolean, 0x22);
      expect(IppTags.enumTag, 0x23);
    });

    test('分隔标签', () {
      expect(IppTags.operationsAttributesTag, 0x01);
      expect(IppTags.jobAttributesTag, 0x02);
      expect(IppTags.endOfAttributesTag, 0x03);
      expect(IppTags.printerAttributesTag, 0x04);
    });

    test('字符串类（RFC 8010 §3.5.2 Table 6）', () {
      // 以下为 RFC 8010 权威取值；源码当前误用 0x34/0x35/0x36/0x32/0x33（旧草案），
      // 会令真实打印机无法识别属性 → 打印失败。
      expect(IppTags.charset, 0x47,
          reason: 'attributes-charset 必须是 0x47');
      expect(IppTags.naturalLanguage, 0x48,
          reason: 'attributes-natural-language 必须是 0x48');
      expect(IppTags.mimeMediaType, 0x49,
          reason: 'document-format(mimeMediaType) 必须是 0x49');
      expect(IppTags.textWithoutLanguage, 0x41,
          reason: 'textWithoutLanguage 必须是 0x41');
      expect(IppTags.nameWithoutLanguage, 0x42,
          reason: 'nameWithoutLanguage 必须是 0x42');
      expect(IppTags.keyword, 0x44);
      expect(IppTags.uri, 0x45);
    });
  });
}
