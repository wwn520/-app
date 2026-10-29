import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:printer_app/models/printer.dart';
import 'package:printer_app/models/print_settings.dart';

/// 设置持久化服务（shared_preferences）。
///
/// 持久化两类数据（P1-1 / 用户设置）：
/// 1. 打印设置（纸张/色彩/质量/份数）；
/// 2. 常用打印机列表（最多保留 5 台）。
///
/// 注意：不缓存身份证原图（隐私红线），仅缓存设置与设备信息。
class SettingsService {
  static SharedPreferences? _prefs;

  static const String _settingsKey = 'print_settings';
  static const String _frequentKey = 'frequent_printers';
  static const String _lastPrinterKey = 'last_printer';
  static const int _maxFrequent = 5;

  /// 懒加载并缓存 SharedPreferences 实例。
  static Future<SharedPreferences> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// 读取打印设置（无则返回默认）。
  Future<PrintSettings> loadSettings() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const PrintSettings();
    try {
      return PrintSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PrintSettings();
    }
  }

  /// 保存打印设置。
  Future<void> saveSettings(PrintSettings settings) async {
    final prefs = await _ensure();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// 记录一台常用打印机（去重置顶，最多 5 台）。
  Future<void> saveFrequentPrinter(Printer printer) async {
    final prefs = await _ensure();
    final list = loadFrequentPrintersSync();
    list.removeWhere((e) => e.id == printer.id);
    list.insert(0, printer);
    final trimmed = list.take(_maxFrequent).toList();
    await prefs.setString(
      _frequentKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  /// 保存「最后使用的打印机」完整信息（id/name/host/port/ippPath/model）。
  Future<void> saveLastPrinter(Printer printer) async {
    final prefs = await _ensure();
    await prefs.setString(_lastPrinterKey, jsonEncode(printer.toJson()));
  }

  /// 读取「最后使用的打印机」（无记录或数据损坏时返回 null）。
  Future<Printer?> loadLastPrinter() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_lastPrinterKey);
    if (raw == null) return null;
    try {
      return Printer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 读取常用打印机列表。
  List<Printer> loadFrequentPrinters() {
    return loadFrequentPrintersSync();
  }

  /// 同步读取（已确保 prefs 初始化后使用，否则返回空）。
  List<Printer> loadFrequentPrintersSync() {
    final prefs = _prefs;
    if (prefs == null) return [];
    final raw = prefs.getString(_frequentKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Printer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
