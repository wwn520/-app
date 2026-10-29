import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/app/app.dart';

/// 应用入口。
///
/// 用 [ProviderScope] 包裹，提供 Riverpod 全局 DI 与状态容器。
void main() {
  // 保证 Flutter 绑定初始化（部分平台插件需要）
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}
