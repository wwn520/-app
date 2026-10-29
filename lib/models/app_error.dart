/// 应用统一错误模型与错误码定义。
///
/// 所有业务层失败均收敛为 [AppError]，UI 通过 [status_banner] 展示
/// [friendlyMessage]（中文可读文案，非技术码）。[technical] 仅用于日志。
enum ErrorCode {
  printerOffline, // 打印机离线
  printerBusy, // 打印机忙
  jobRejected, // 作业被拒绝
  paperEmpty, // 缺纸
  networkTimeout, // 网络超时
  ippError, // IPP 协议/服务端异常
  unknown, // 未知
}

/// 应用层错误。包含错误码、中文友好文案、可选技术信息。
class AppError {
  final ErrorCode code;
  final String friendlyMessage;
  final String? technical;

  const AppError({
    required this.code,
    required this.friendlyMessage,
    this.technical,
  });

  /// 按错误码生成预置的中文友好文案。
  factory AppError.fromCode(ErrorCode code, {String? technical}) {
    return AppError(
      code: code,
      friendlyMessage: _messages[code] ?? _messages[ErrorCode.unknown]!,
      technical: technical,
    );
  }

  /// 把 IPP 状态码映射为 ErrorCode（未知码归为 ippError）。
  factory AppError.fromIppStatus(int statusCode, {String? technical}) {
    final code = _ippStatusToCode(statusCode);
    return AppError.fromCode(code, technical: technical);
  }

  @override
  String toString() =>
      'AppError(${code.name}, friendly=$friendlyMessage, technical=$technical)';

  /// 错误码 → 中文友好文案映射（共享知识 §7）。
  static const Map<ErrorCode, String> _messages = {
    ErrorCode.printerOffline: '打印机已离线，请检查电源/同 WiFi 后重试',
    ErrorCode.printerBusy: '打印机正忙，请稍后再试',
    ErrorCode.jobRejected: '打印作业被拒绝，可能是纸张尺寸不支持',
    ErrorCode.paperEmpty: '打印机缺纸，请加纸后重试',
    ErrorCode.networkTimeout: '网络超时，请确认手机与打印机在同一 WiFi',
    ErrorCode.ippError: '打印机返回异常，可重试或换设备',
    ErrorCode.unknown: '打印失败，请重试',
  };

  /// IPP 状态码 → ErrorCode（RFC 2911 常见码）。
  static ErrorCode _ippStatusToCode(int status) {
    switch (status) {
      case 0x0507: // server-error-busy
        return ErrorCode.printerBusy;
      case 0x0500: // server-error-internal-error
      case 0x0501: // server-error-operation-not-supported
      case 0x0502: // server-error-service-unavailable
      case 0x0504: // server-error-device-error
      case 0x0505: // server-error-temporary-error
      case 0x0506: // server-error-not-accepting-jobs
        return ErrorCode.ippError;
      case 0x040A: // client-error-document-format-not-supported
      case 0x040B: // client-error-attributes-or-values-not-supported
      case 0x040E: // client-error-conflicting-attributes
        return ErrorCode.jobRejected;
      default:
        // 0x0000 系列为成功，不应映射到错误；其余归为 ippError
        return status >= 0x0400 ? ErrorCode.ippError : ErrorCode.unknown;
    }
  }
}
