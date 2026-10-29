import 'package:flutter/material.dart';

import 'package:printer_app/app/theme.dart';
import 'package:printer_app/models/app_error.dart';
import 'package:printer_app/models/print_job.dart';

/// 打印状态横幅：发送中 / 成功 / 失败（含友好错误 + 重试）。
///
/// 统一展示打印状态反馈（P0-7）。
class StatusBanner extends StatelessWidget {
  final PrintStatus status;
  final AppError? error;
  final VoidCallback? onRetry;

  const StatusBanner({
    super.key,
    required this.status,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case PrintStatus.idle:
        return const SizedBox.shrink();
      case PrintStatus.sending:
        return _build(Colors.blue, Icons.sync, '发送中…', null, false);
      case PrintStatus.success:
        return _build(AppTheme.success, Icons.check_circle, '打印成功', null, false);
      case PrintStatus.failed:
        return _build(
          AppTheme.danger,
          Icons.error_outline,
          error?.friendlyMessage ?? '打印失败，请重试',
          onRetry,
          true,
        );
    }
  }

  Widget _build(Color color, IconData icon, String message, VoidCallback? retry,
      bool showRetry) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
          if (showRetry && retry != null)
            TextButton(
              onPressed: retry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
