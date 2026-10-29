import 'package:flutter_test/flutter_test.dart';

import 'package:printer_app/app/app.dart';

/// 应用入口冒烟测试。
///
/// 只验证 MyApp 可实例化（不 pump 完整应用，避免测试环境触发
/// mDNS/shared_preferences 等原生插件导致 MissingPluginException）。
/// 完整模块的行为测试见 test/ 下各单测文件。
void main() {
  test('MyApp 可正常实例化（冒烟）', () {
    const app = MyApp();
    expect(app, isNotNull);
  });
}
