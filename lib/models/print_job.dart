import 'dart:typed_data';

import 'package:printer_app/models/app_error.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/models/print_settings.dart';

/// 打印作业状态。
enum PrintStatus {
  idle, // 空闲
  sending, // 发送中
  success, // 成功
  failed, // 失败
}

/// 一次打印作业。
///
/// 包含目标打印机、打印设置、已生成的 A4 PDF 字节，以及运行期状态与错误。
class PrintJob {
  final String id;
  final Printer printer;
  final PrintSettings settings;
  final Uint8List pdf; // 已生成的 A4 PDF 字节
  PrintStatus status;
  AppError? error;

  PrintJob({
    required this.id,
    required this.printer,
    required this.settings,
    required this.pdf,
    this.status = PrintStatus.idle,
    this.error,
  });

  /// 更新状态（可变，便于在发送流程中就地变更）。
  void update({
    PrintStatus? status,
    AppError? error,
  }) {
    if (status != null) this.status = status;
    if (error != null) this.error = error;
  }
}
