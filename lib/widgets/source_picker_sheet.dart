import 'package:flutter/material.dart';

import 'package:printer_app/models/id_card.dart';

/// 底部来源选择面板：相册 / 拍照 / 微信(系统分享)。
///
/// 通过系统分享（receive_sharing_intent）接收微信图片，无需 OpenSDK。
class SourcePickerSheet {
  /// 弹出面板，返回用户选择的来源（取消返回 null）。
  static Future<ImageSource?> show(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('选择图片来源',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('相册'),
              subtitle: const Text('多选照片'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.album),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              subtitle: const Text('调用相机拍摄'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('微信 / 系统分享'),
              subtitle: const Text('从微信「分享到」本应用'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
