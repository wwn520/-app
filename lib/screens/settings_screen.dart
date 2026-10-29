import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/settings/settings_provider.dart';
import 'package:printer_app/widgets/color_mode_switch.dart';
import 'package:printer_app/widgets/printer_list_tile.dart';
import 'package:printer_app/widgets/quality_selector.dart';

/// 打印设置页：纸张(A4) / 色彩 / 质量 / 份数 / 常用打印机（P1-1）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(SettingsProviders.settings);
    final notifier = ref.read(SettingsProviders.settings.notifier);
    final frequent = ref
        .read(SettingsProviders.service)
        .loadFrequentPrinters();

    return Scaffold(
      appBar: AppBar(title: const Text('打印设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('纸张尺寸', style: TextStyle(fontWeight: FontWeight.w600)),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('A4 (210 × 297 mm)'),
            subtitle: const Text('首版仅支持 A4（P2 扩展 A5/照片纸）'),
            trailing: const Icon(Icons.check, color: Colors.green),
          ),
          const Divider(),
          const Text('色彩模式', style: TextStyle(fontWeight: FontWeight.w600)),
          Center(
            child: ColorModeSwitch(
              value: settings.colorMode,
              onChanged: (m) => notifier.update(settings.copyWith(colorMode: m)),
            ),
          ),
          const Divider(),
          const Text('打印质量', style: TextStyle(fontWeight: FontWeight.w600)),
          Center(
            child: QualitySelector(
              value: settings.quality,
              onChanged: (q) => notifier.update(settings.copyWith(quality: q)),
            ),
          ),
          const Divider(),
          const Text('份数', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                onPressed: settings.copies > 1
                    ? () =>
                        notifier.update(settings.copyWith(copies: settings.copies - 1))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${settings.copies}', style: const TextStyle(fontSize: 18)),
              IconButton(
                onPressed: () =>
                    notifier.update(settings.copyWith(copies: settings.copies + 1)),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const Divider(),
          const Text('常用打印机', style: TextStyle(fontWeight: FontWeight.w600)),
          if (frequent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('暂无记录，去发现页选择打印机会自动记录',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...frequent.map((p) => PrinterListTile(
                  printer: p,
                  selected:
                      ref.watch(FlowProviders.selectedPrinter)?.id == p.id,
                  onTap: () =>
                      ref.read(FlowProviders.selectedPrinter.notifier).state = p,
                )),
        ],
      ),
    );
  }
}
