import 'package:flutter/material.dart';

import 'package:printer_app/app/router.dart';
import 'package:printer_app/app/theme.dart';

/// 根组件：主题 + 路由装配。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrinterApp 无广告打印',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
