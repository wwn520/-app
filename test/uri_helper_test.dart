import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_app/utils/uri_helper.dart';

void main() {
  group('UriHelper', () {
    test('buildIppUri 构造 ipp://host:port/path', () {
      final u = UriHelper.buildIppUri('192.168.1.5', 631, '/ipp/print');
      expect(u.scheme, 'ipp');
      expect(u.host, '192.168.1.5');
      expect(u.port, 631);
      expect(u.path, '/ipp/print');
    });

    test('buildIppUri 缺省 path 回退 /ipp/print', () {
      final u = UriHelper.buildIppUri('h', 631, null);
      expect(u.path, '/ipp/print');
    });

    test('toHttpEndpoint 将 ipp 端点转为 http 端点（IPP over HTTP/1.1）', () {
      final u = UriHelper.toHttpEndpoint(
          UriHelper.buildIppUri('192.168.1.5', 631, '/ipp/print'));
      expect(u.scheme, 'http');
      expect(u.host, '192.168.1.5');
      expect(u.path, '/ipp/print');
    });

    test('parseTxtRp 解析 TXT 记录 rp 字段', () {
      final rp = utf8.encode('/ipp/print');
      final txt = <String, Uint8List?>{'rp': Uint8List.fromList(rp)};
      expect(UriHelper.parseTxtRp(txt), '/ipp/print');
    });

    test('parseTxtRp 缺失或空 → null', () {
      expect(UriHelper.parseTxtRp(null), isNull);
      expect(
          UriHelper.parseTxtRp(<String, Uint8List?>{
            'ty': Uint8List.fromList(utf8.encode('x'))
          }),
          isNull);
    });

    test('sanitizeServiceName 去除 .local. 后缀', () {
      expect(UriHelper.sanitizeServiceName('EPSON L3250._local.'), 'EPSON L3250');
    });
  });
}
