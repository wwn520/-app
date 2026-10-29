import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';
import 'package:printer_app/app/theme.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/settings/settings_provider.dart';

/// 首页：主流程编排入口。
///
/// 串联：发现打印机 → 选图/身份证 → 设置 → 预览 → 打印。
/// - 启动时恢复「最后使用的打印机」并自动占位选中（离线态展示）；
/// - 发现服务探活确认其在线（host+port+name 匹配）后自动切换为在线实例；
/// - 进入即自动启动 mDNS 发现（StreamProvider）。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreLastPrinter());
  }

  /// 启动恢复「最后使用的打印机」：无选中时以离线态占位，等待发现确认。
  Future<void> _restoreLastPrinter() async {
    final last = await ref.read(SettingsProviders.service).loadLastPrinter();
    // await 之后必须守卫 mounted：页面若已卸载，访问 ref 会抛 StateError。
    if (!mounted || last == null) return;
    ref.read(FlowProviders.lastPrinter.notifier).state = last;
    final current = ref.read(FlowProviders.selectedPrinter);
    if (current == null) {
      ref.read(FlowProviders.selectedPrinter.notifier).state =
          last.copyWith(status: PrinterStatus.offline);
    }
  }

  /// 发现列表更新时：若「最后使用的打印机」已被探活确认在线，则自动选中。
  void _autoSelectOnline(List<Printer> printers) {
    final last = ref.read(FlowProviders.lastPrinter);
    if (last == null) return;
    Printer? found;
    for (final p in printers) {
      if (p.host == last.host &&
          p.port == last.port &&
          p.name == last.name &&
          p.status == PrinterStatus.online) {
        found = p;
        break;
      }
    }
    if (found == null) return;
    final current = ref.read(FlowProviders.selectedPrinter);
    if (current == null ||
        current.id != found.id ||
        current.status != PrinterStatus.online) {
      ref.read(FlowProviders.selectedPrinter.notifier).state = found;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 订阅发现流：列表变化时尝试自动选中上次使用的在线打印机。
    ref.listen(ServiceProviders.printers, (_, next) {
      next.whenData(_autoSelectOnline);
    });

    final selected = ref.watch(FlowProviders.selectedPrinter);
    final last = ref.watch(FlowProviders.lastPrinter);
    final mode = ref.watch(FlowProviders.printMode);
    final images = ref.watch(FlowProviders.importedImages);
    final idCard = ref.watch(FlowProviders.idCardScan);
    final printersAsync = ref.watch(ServiceProviders.printers);

    // 当前选中是否为「恢复出的上次打印机」（尚未被发现确认为在线实例）。
    final isRestoredLast = selected != null &&
        last != null &&
        selected.host == last.host &&
        selected.port == last.port &&
        selected.name == last.name;

    final hasContent =
        mode == PrintMode.idCard ? idCard != null : images.isNotEmpty;
    final canPrint = selected != null && hasContent;

    String title;
    String subtitle;
    if (selected == null) {
      title = '未选择打印机';
      subtitle = '点击发现并选择局域网打印机';
    } else if (selected.status == PrinterStatus.online) {
      title = selected.name;
      subtitle =
          '${selected.host}:${selected.port}${selected.ippPath ?? ''} · 在线';
    } else if (isRestoredLast) {
      title = selected.name;
      subtitle =
          '上次使用的打印机（离线）· ${selected.host}:${selected.port}';
    } else {
      title = selected.name;
      subtitle =
          '${selected.host}:${selected.port}${selected.ippPath ?? ''} · 检测中';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('王婉宁打印')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            icon: Icons.print,
            title: title,
            subtitle: subtitle,
            badge: _StatusBadge(status: selected?.status),
            onTap: () => AppRoutes.go(context, AppRoutes.discovery),
          ),
          _Card(
            icon: Icons.credit_card,
            title: '选择内容',
            subtitle: mode == PrintMode.idCard
                ? (idCard != null ? '身份证模式（正反面已就绪）' : '身份证模式（待导入正反面）')
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
              final online = printers
                  .where((p) => p.status == PrinterStatus.online)
                  .length;
              return Text('局域网在线打印机：$online 台',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 13));
            },
            loading: () => const Text('正在发现打印机…',
                style: TextStyle(color: AppTheme.muted, fontSize: 13)),
            error: (e, _) => Text('发现出错：$e',
                style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// 在线状态徽标（绿=在线 / 灰=检测中 / 红=离线）。
class _StatusBadge extends StatelessWidget {
  final PrinterStatus? status;

  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      PrinterStatus.online => (AppTheme.success, '在线'),
      PrinterStatus.offline => (AppTheme.danger, '离线'),
      PrinterStatus.unknown => (AppTheme.muted, '检测中'),
      null => (AppTheme.muted, '未选择'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 首页状态卡（Material 3：图标底色 + 柔和阴影 + 状态徽标）。
class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? badge;
  final VoidCallback onTap;

  const _Card({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (badge != null) badge! else const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
