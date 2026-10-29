import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/providers.dart';
import 'package:printer_app/app/router.dart';

/// 单图/多图编辑预览页（普通模式）。
///
/// 展示已导入图片缩略图，提供「下一步：打印设置」与「重新选择」。
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(FlowProviders.importedImages);
    return Scaffold(
      appBar: AppBar(title: const Text('编辑预览')),
      body: Column(
        children: [
          Expanded(
            child: images.isEmpty
                ? const Center(child: Text('未选择图片'))
                : GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(8),
                    children: images
                        .map(
                          (im) => Card(
                            clipBehavior: Clip.antiAlias,
                            child: im.bytes != null
                                ? Image.memory(im.bytes!, fit: BoxFit.cover)
                                : Image.file(File(im.path), fit: BoxFit.cover),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: images.isEmpty
                      ? null
                      : () => AppRoutes.go(context, AppRoutes.settings),
                  child: const Text('下一步：打印设置'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('重新选择'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
