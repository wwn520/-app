import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/theme.dart';
import 'package:printer_app/models/app_error.dart';
import 'package:printer_app/models/print_job.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/settings/settings_provider.dart';
import 'package:printer_app/widgets/status_banner.dart';

/// 打印状态页：发送中 / 成功 / 失败 + 重试（P0-7）。
///
/// Material 3 视觉：中央大图标状态区带 AnimatedSwitcher 动画反馈。
class PrintStatusScreen extends ConsumerStatefulWidget {
  const PrintStatusScreen({super.key});

  @override
  ConsumerState<PrintStatusScreen> createState() => _PrintStatusScreenState();
}

class _PrintStatusScreenState extends ConsumerState<PrintStatusScreen> {
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    // 进入即尝试打印（也可由底部按钮重新触发）
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _submitPrint());
  }

  Future<void> _submitPrint() async {
    final printer = ref.read(FlowProviders.selectedPrinter);
    final pdf = ref.read(FlowProviders.generatedPdf);
    final settings = ref.read(SettingsProviders.settings);

    if (printer == null || pdf == null) {
      ref.read(FlowProviders.printJob.notifier).state = PrintJob(
        id: 'job_${DateTime.now().millisecondsSinceEpoch}',
        printer: printer ??
            Printer(
              id: 'none',
              name: '未选择打印机',
              host: '',
              port: 631,
              lastSeen: DateTime.now(),
            ),
        settings: settings,
        pdf: pdf ?? Uint8List(0),
        status: PrintStatus.failed,
        error: AppError.fromCode(ErrorCode.unknown,
            technical: '缺少打印机或 PDF'),
      );
      return;
    }

    setState(() => _printing = true);
    final job = PrintJob(
      id: 'job_${DateTime.now().millisecondsSinceEpoch}',
      printer: printer,
      settings: settings,
      pdf: pdf,
      status: PrintStatus.sending,
    );
    ref.read(FlowProviders.printJob.notifier).state = job;

    try {
      final resp = await ref
          .read(ServiceProviders.ippClient)
          .sendPrintJob(printer, pdf, settings);
      if (resp.isSuccessful) {
        job.update(status: PrintStatus.success);
      } else {
        job.update(
          status: PrintStatus.failed,
          error: AppError.fromIppStatus(resp.statusCode,
              technical: 'status=${resp.statusCode}'),
        );
      }
    } on AppError catch (e) {
      job.update(status: PrintStatus.failed, error: e);
    } catch (e) {
      job.update(
        status: PrintStatus.failed,
        error: AppError.fromCode(ErrorCode.unknown, technical: e.toString()),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(FlowProviders.printJob);
    return Scaffold(
      appBar: AppBar(title: const Text('打印状态')),
      body: Column(
        children: [
          // 状态横幅（状态切换时淡入淡出）。
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: job == null
                ? const SizedBox.shrink(key: ValueKey('banner-empty'))
                : StatusBanner(
                    key: ValueKey('banner-${job.status.name}'),
                    status: job.status,
                    error: job.error,
                    onRetry:
                        job.status == PrintStatus.failed ? _submitPrint : null,
                  ),
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _bigStatus(context, job),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: _printing ? null : _submitPrint,
          child: _printing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('重新打印'),
        ),
      ),
    );
  }

  /// 中央大图标状态区（带动画切换）。
  Widget _bigStatus(BuildContext context, PrintJob? job) {
    if (job == null || job.status == PrintStatus.idle) {
      return const Column(
        key: ValueKey('idle'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.print_outlined, size: 72, color: AppTheme.muted),
          SizedBox(height: 12),
          Text('准备发送…', style: TextStyle(color: AppTheme.muted)),
        ],
      );
    }
    switch (job.status) {
      case PrintStatus.sending:
        return Column(
          key: const ValueKey('sending'),
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 16),
            Text('正在发送到打印机…',
                style: TextStyle(color: AppTheme.muted, fontSize: 15)),
          ],
        );
      case PrintStatus.success:
        return Column(
          key: const ValueKey('success'),
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, size: 72, color: AppTheme.success),
            SizedBox(height: 12),
            Text('打印任务已提交',
                style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        );
      case PrintStatus.failed:
        return Column(
          key: const ValueKey('failed'),
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, size: 72, color: AppTheme.danger),
            SizedBox(height: 12),
            Text('打印失败，可点击重试',
                style: TextStyle(
                    color: AppTheme.danger,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        );
      case PrintStatus.idle:
        return const SizedBox.shrink(key: ValueKey('idle2'));
    }
  }
}
