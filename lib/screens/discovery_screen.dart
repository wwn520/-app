import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/widgets/printer_list_tile.dart';

/// 打印机发现页：列出同 WiFi 在线打印机，支持选择 + 手动刷新。
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printersAsync = ref.watch(ServiceProviders.printers);
    final selected = ref.watch(FlowProviders.selectedPrinter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择打印机'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () =>
                ref.read(ServiceProviders.printerDiscovery).refresh(),
          ),
        ],
      ),
      body: printersAsync.when(
        data: (printers) {
          if (printers.isEmpty) {
            return const Center(
              child: Text('未发现打印机\n请确认手机与打印机在同一 WiFi',
                  textAlign: TextAlign.center),
            );
          }
          // 在线优先排序
          final sorted = [...printers]
            ..sort((a, b) => _rank(b.status).compareTo(_rank(a.status)));
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final p = sorted[i];
              return PrinterListTile(
                printer: p,
                selected: selected?.id == p.id,
                onTap: () =>
                    ref.read(FlowProviders.selectedPrinter.notifier).state = p,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('发现出错: $e')),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: selected == null
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('确认选择'),
        ),
      ),
    );
  }

  int _rank(PrinterStatus s) =>
      s == PrinterStatus.online ? 2 : s == PrinterStatus.unknown ? 1 : 0;
}
