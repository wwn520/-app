import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';
import 'package:printer_app/models/id_card.dart';
import 'package:printer_app/widgets/source_picker_sheet.dart';

/// 来源选择页：普通照片 / 身份证 两种入口。
class SourceSelectScreen extends ConsumerWidget {
  const SourceSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择打印内容')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ModeCard(
              icon: Icons.photo,
              title: '普通照片打印',
              subtitle: '从相册多选 / 拍照 / 微信分享，单张或拼版打印',
              onTap: () => _pickNormal(context, ref),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              icon: Icons.credit_card,
              title: '身份证打印',
              subtitle: '人像面 + 国徽面，端侧自动裁正拼版（不上传）',
              onTap: () {
                ref.read(FlowProviders.printMode.notifier).state =
                    PrintMode.idCard;
                AppRoutes.go(context, AppRoutes.idCard);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickNormal(BuildContext context, WidgetRef ref) async {
    final source = await SourcePickerSheet.show(context);
    if (source == null) return;
    final images = await ref.read(ServiceProviders.importManager).pickFrom(source);
    if (images.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未选择任何图片')));
      return;
    }
    ref.read(FlowProviders.printMode.notifier).state = PrintMode.normal;
    ref.read(FlowProviders.importedImages.notifier).state = images;
    ref.read(FlowProviders.generatedPdf.notifier).state = null;
    AppRoutes.go(context, AppRoutes.editor);
  }
}

/// 入口卡片。
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.12),
                child: Icon(icon,
                    size: 30, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
