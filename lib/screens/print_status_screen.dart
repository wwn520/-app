import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/models/app_error.dart';
import 'package:printer_app/models/print_job.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/settings/settings_provider.dart';
import 'package:printer_app/widgets/status_banner.dart';

/// 打印状态页：发送中 / 成功 / 失败 + 重试（P0-7）。
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
      setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(FlowProviders.printJob);
    return Scaffold(
      appBar: AppBar(title: const Text('打印状态')),
      body: Column(
        children: [
          if (job != null)
            StatusBanner(
              status: job.status,
              error: job.error,
              onRetry:
                  job.status == PrintStatus.failed ? _submitPrint : null,
            ),
          const Expanded(
            child: Center(
              child: Text('将文件通过 IPP 发送到所选打印机',
                  style: TextStyle(color: Colors.grey)),
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
}
