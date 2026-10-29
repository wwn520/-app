import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_app/core/constants.dart';

/// URI 与 TXT 记录辅助工具。
///
/// 职责：
/// 1. 由 IP/port/path 构造 IPP 打印机 URI（`ipp://...`）。
/// 2. 由 nsd 的 TXT 记录解析 `rp`（relative path），失败回退默认路径。
/// 3. 把 `ipp://` URI 转成 HTTP 传输端点（`http://...`，IPP 基于 HTTP/1.1）。
class UriHelper {
  /// 构造 IPP 打印机 URI（用于 IPP 报文中的 printer-uri 属性）。
  static Uri buildIppUri(String host, int port, String? path) {
    final p = (path == null || path.isEmpty) ? Constants.ippDefaultPath : path;
    return Uri(scheme: 'ipp', host: host, port: port, path: p);
  }

  /// 把 IPP URI 转为实际 HTTP 传输端点（IPP 报文通过 HTTP POST 发送）。
  static Uri toHttpEndpoint(Uri ippUri) {
    return Uri(
      scheme: 'http',
      host: ippUri.host,
      port: ippUri.port,
      path: ippUri.path,
    );
  }

  /// 从 nsd TXT 记录（Map<key, bytes>）解析 `rp` 字段。
  ///
  /// TXT 记录里 `rp` 表示打印机的相对路径（如 `/ipp/print`）。
  /// 找不到或解析失败时返回 null，由调用方回退默认路径。
  static String? parseTxtRp(Map<String, Uint8List?>? txt) {
    if (txt == null) return null;
    final raw = txt['rp'];
    if (raw == null || raw.isEmpty) return null;
    final s = utf8.decode(raw);
    // 部分固件 rp 可能带前导空格或尾部空字符，做一次清理
    final trimmed = s.trim();
    return trimmed.isEmpty ? null : (trimmed.startsWith('/') ? trimmed : '/$trimmed');
  }

  /// 从 TXT 记录解析设备型号 `ty`（text）。
  static String? parseTxtTy(Map<String, Uint8List?>? txt) {
    if (txt == null) return null;
    final raw = txt['ty'] ?? txt['model'];
    if (raw == null || raw.isEmpty) return null;
    return utf8.decode(raw).trim();
  }

  /// 清理 nsd 服务名（去掉 `.local.` 等后缀，便于展示）。
  static String sanitizeServiceName(String name) {
    return name.replaceAll(RegExp(r'\.local\.?$'), '').trim();
  }
}
