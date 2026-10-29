import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_app/ipp_client/ipp_attributes.dart';

/// IPP 响应解析结果。
class IppResponse {
  /// 状态码（RFC 2911，如 0x0000 successful-ok）。
  final int statusCode;

  /// 作业 ID（Print-Job 成功时返回）。
  final int? jobId;

  /// 属性名 → 值字节。
  final Map<String, Uint8List> attributes;

  const IppResponse({
    required this.statusCode,
    this.jobId,
    required this.attributes,
  });

  /// 是否成功（0x0000 ~ 0x0002 为 successful-* 系列）。
  bool get isSuccessful =>
      statusCode >= 0x0000 && statusCode <= 0x0002;
}

/// IPP 二进制报文编解码（RFC 2910）。
///
/// 报文结构：
///   version(2) | operation-id(2) | request-id(4)
///   [group-tag][attr: tag(1) nameLen(2) name valueLen(2) value]...
///   end-of-attributes(1)
///   [document bytes]   // 仅 Print-Job
class IppMessage {
  /// 编码请求报文。
  ///
  /// [operation] 操作码（Print-Job=0x0002 / Get-Printer-Attributes=0x000B）。
  /// [groups] 属性组（由 [IppAttributes] 构造）。
  /// [document] 可选文档字节（Print-Job 时为 PDF）。
  Uint8List encode(int operation, List<IppAttributeGroup> groups,
      [Uint8List? document]) {
    final out = BytesBuilder();

    // 版本号 1.1
    out.addByte(0x01);
    out.addByte(0x01);

    // 操作码（2 字节大端）
    out.addByte((operation >> 8) & 0xFF);
    out.addByte(operation & 0xFF);

    // 请求 ID（4 字节大端），固定 1（实现可递增）
    out.addByte(0x00);
    out.addByte(0x00);
    out.addByte(0x00);
    out.addByte(0x01);

    // 属性组
    for (final group in groups) {
      out.addByte(group.groupTag);
      for (final entry in group.entries) {
        out.addByte(entry.tag);
        final nameBytes = utf8.encode(entry.name);
        _writeLength(out, nameBytes.length);
        out.add(nameBytes);
        _writeLength(out, entry.value.length);
        out.add(entry.value);
      }
    }

    // 结束标签
    out.addByte(IppTags.endOfAttributesTag);

    // 文档体（Print-Job）
    if (document != null) {
      out.add(document);
    }

    return out.toBytes();
  }

  /// 解码响应报文（粗略解析 status / job-id / 属性）。
  IppResponse decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    int offset = 0;

    // version（2 字节）跳过
    offset += 2;

    // status-code（2 字节）
    final statusCode = data.getUint16(offset);
    offset += 2;

    // request-id（4 字节）跳过
    offset += 4;

    final attributes = <String, Uint8List>{};
    int? jobId;

    while (offset < bytes.length) {
      final tag = bytes[offset++];
      if (tag == IppTags.endOfAttributesTag) break;

      // 分隔标签（0x01~0x09）直接跳过
      if (tag >= 0x01 && tag <= 0x09) continue;

      // 属性条目布局：nameLen(2) name valueLen(2) value
      // 截断防护：剩余字节不足以容纳 length 字段时停止解析，避免 RangeError。
      if (offset + 4 > bytes.length) break;
      final nameLen = data.getUint16(offset);
      offset += 2;
      if (offset + nameLen + 2 > bytes.length) break; // name + valueLen(2)
      final name = String.fromCharCodes(
          bytes.sublist(offset, offset + nameLen));
      offset += nameLen;

      final valueLen = data.getUint16(offset);
      offset += 2;
      if (offset + valueLen > bytes.length) break;
      final value = Uint8List.fromList(
          bytes.sublist(offset, offset + valueLen));
      offset += valueLen;

      attributes[name] = value;

      if (name == 'job-id' && value.length == 4) {
        jobId = ByteData.sublistView(value).getUint32(0);
      }
    }

    return IppResponse(
      statusCode: statusCode,
      jobId: jobId,
      attributes: attributes,
    );
  }

  /// 写 2 字节大端长度。
  void _writeLength(BytesBuilder out, int len) {
    out.addByte((len >> 8) & 0xFF);
    out.addByte(len & 0xFF);
  }
}
