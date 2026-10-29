import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';
import 'package:printer_app/models/id_card.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/settings/settings_provider.dart';

/// 首页：主流程编排入口。
///
/// 串联：发现打印机 → 选图/身份证 → 设置 → 预览 → 打印。
/// 顶部状态卡汇总当前选择，进入即自动启动 mDNS 发现（StreamProvider）。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(FlowProviders.selectedPrinter);
    final mode = ref.watch(FlowProviders.printMode);
    final images = ref.watch(FlowProviders.importedImages);
    final idCard = ref.watch(FlowProviders.idCardScan);
    final printersAsync = ref.watch(ServiceProviders.printers);

    final hasContent = mode == PrintMode.idCard
        ? idCard != null
        : images.isNotEmpty;
    final canPrint = selected != null && hasContent;

    return Scaffold(
      appBar: AppBar(title: const Text('无广告打印')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            icon: Icons.print,
            title: selected?.name ?? '未选择打印机',
            subtitle: selected != null
                ? '${selected.host}:${selected.port}${selected.ippPath ?? ''} · ${_status(selected.status)}'
                : '点击发现并选择局域网打印机',
            onTap: () => AppRoutes.go(context, AppRoutes.discovery),
          ),
          _Card(
            icon: Icons.credit_card,
            title: '选择内容',
            subtitle: mode == PrintMode.idCard
                ? '身份证模式'
                : '普通照片（已选 ${images.length} 张）',
            onTap: () => AppRoutes.go(context, AppRoutes.sourceSelect),
          ),
          _Card(
            icon: Icons.tune,
            title: '打印设置',
            subtitle: 'A4 · 色彩 · 质量 · 份数',
            onTap: () => AppRoutes.go(context, AppRoutes.settings),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: canPrint
                ? () => AppRoutes.go(context, AppRoutes.preview)
                : null,
            child: const Text('去预览 / 打印'),
          ),
          const SizedBox(height: 16),
          printersAsync.when(
            data: (printers) {
              final online =
                  printers.where((p) => p.status == PrinterStatus.online).length;
              return Text('局域网在线打印机：$online 台',
                  style: const TextStyle(color: Colors.grey));
            },
            loading: () => const Text('正在发现打印机…',
                style: TextStyle(color: Colors.grey)),
            error: (e, _) => Text('发现出错：$e',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _status(PrinterStatus s) {
    switch (s) {
      case PrinterStatus.online:
        return '在线';
      case PrinterStatus.offline:
        return '离线';
      case PrinterStatus.unknown:
        return '检测中';
    }
  }
}

/// 首页状态卡。
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Card({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
