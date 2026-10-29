import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/models/print_settings.dart';
import 'package:printer_app/settings/settings_service.dart';

/// 设置相关 Provider（Riverpod 接线）。
class SettingsProviders {
  /// 设置持久化服务。
  static final service = Provider<SettingsService>((ref) => SettingsService());

  /// 打印设置状态（自动从持久化加载，变更时写回）。
  static final settings =
      StateNotifierProvider<SettingsNotifier, PrintSettings>(
    (ref) => SettingsNotifier(ref.watch(service)),
  );
}

/// 打印设置状态管理器：初始为默认值，构造时异步加载持久化设置。
class SettingsNotifier extends StateNotifier<PrintSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(const PrintSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.loadSettings();
  }

  /// 更新设置并持久化。
  Future<void> update(PrintSettings settings) async {
    state = settings;
    await _service.saveSettings(settings);
  }
}
