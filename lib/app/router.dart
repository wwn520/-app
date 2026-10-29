import 'package:flutter/material.dart';

import 'package:printer_app/screens/discovery_screen.dart';
import 'package:printer_app/screens/editor_screen.dart';
import 'package:printer_app/screens/home_screen.dart';
import 'package:printer_app/screens/id_card_scan_screen.dart';
import 'package:printer_app/screens/preview_screen.dart';
import 'package:printer_app/screens/print_status_screen.dart';
import 'package:printer_app/screens/settings_screen.dart';
import 'package:printer_app/screens/source_select_screen.dart';

/// 路由名常量与路由表装配。
///
/// 主流程：Home → Discovery / SourceSelect → Editor / IdCardScan
///        → Settings → Preview → PrintStatus
class AppRoutes {
  static const String home = '/';
  static const String discovery = '/discovery';
  static const String sourceSelect = '/source';
  static const String editor = '/editor';
  static const String idCard = '/idcard';
  static const String settings = '/settings';
  static const String preview = '/preview';
  static const String printStatus = '/status';

  /// 路由表（WidgetBuilder 形式，流程状态走 FlowProviders，无需参数）。
  static Map<String, WidgetBuilder> get routes => {
        home: (ctx) => const HomeScreen(),
        discovery: (ctx) => const DiscoveryScreen(),
        sourceSelect: (ctx) => const SourceSelectScreen(),
        editor: (ctx) => const EditorScreen(),
        idCard: (ctx) => const IdCardScanScreen(),
        settings: (ctx) => const SettingsScreen(),
        preview: (ctx) => const PreviewScreen(),
        printStatus: (ctx) => const PrintStatusScreen(),
      };

  /// 便捷跳转。
  static void go(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  /// 便捷跳转并替换当前页。
  static void goReplacement(BuildContext context, String routeName) {
    Navigator.of(context).pushReplacementNamed(routeName);
  }
}
