import 'package:flutter_test/flutter_test.dart';
import 'package:printer_app/models/app_error.dart';

/// 错误码测试：覆盖全部错误码 + 中文文案 + IPP 状态码映射。
void main() {
  test('全部 7 个错误码都有非空中文友好文案', () {
    for (final code in ErrorCode.values) {
      final e = AppError.fromCode(code);
      expect(e.code, code);
      expect(e.friendlyMessage, isNotEmpty);
    }
  });

  test('paperEmpty 等关键错误码有专用文案（不只是 unknown 兜底）', () {
    expect(AppError.fromCode(ErrorCode.paperEmpty).friendlyMessage,
        contains('纸'));
    expect(AppError.fromCode(ErrorCode.printerOffline).friendlyMessage,
        contains('离线'));
    expect(AppError.fromCode(ErrorCode.networkTimeout).friendlyMessage,
        contains('超时'));
  });

  group('IPP 状态码 → ErrorCode 映射（RFC 2911）', () {
    test('server-error-busy → printerBusy', () {
      expect(AppError.fromIppStatus(0x0507).code, ErrorCode.printerBusy);
    });

    test('服务端类错误 → ippError', () {
      for (final s in [0x0500, 0x0501, 0x0502, 0x0504, 0x0505, 0x0506]) {
        expect(AppError.fromIppStatus(s).code, ErrorCode.ippError,
            reason: 'status 0x${s.toRadixString(16)}');
      }
    });

    test('客户端拒绝类错误 → jobRejected', () {
      for (final s in [0x040A, 0x040B, 0x040E]) {
        expect(AppError.fromIppStatus(s).code, ErrorCode.jobRejected,
            reason: 'status 0x${s.toRadixString(16)}');
      }
    });

    test('任意客户端错误(>=0x0400) 归入 ippError', () {
      expect(AppError.fromIppStatus(0x0401).code, ErrorCode.ippError);
    });

    test('成功码(0x0000) 不被当成错误，归为 unknown', () {
      expect(AppError.fromIppStatus(0x0000).code, ErrorCode.unknown);
    });
  });

  test('toString 不抛异常且包含错误码名', () {
    final s = AppError.fromCode(ErrorCode.printerOffline).toString();
    expect(s, contains('printerOffline'));
  });
}
