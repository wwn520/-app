import 'package:flutter/material.dart';

/// 应用主题（浅色；P2 暗黑模式预留）。
///
/// 设计基调：纯净、无广告位、清晰可读。
class AppTheme {
  /// 主色（沉稳蓝绿，传达「可靠工具」质感）。
  static const Color primary = Color(0xFF1F6F6B);
  static const Color primaryLight = Color(0xFF4FA39C);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF8A8A8E);
  static const Color success = Color(0xFF2E9E5B);
  static const Color danger = Color(0xFFD64545);

  /// 浅色主题数据。
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          background: background,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: surface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: onSurface),
          titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        ),
      );
}
