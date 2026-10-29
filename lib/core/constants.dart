/// 全局常量定义。
///
/// 集中存放纸张尺寸、IPP 协议默认值、超时、服务类型、探活间隔等，
/// 供发现 / IPP / PDF / 设置等模块统一引用，避免魔法数字。
class Constants {
  // ───────── IPP 协议默认 ─────────
  /// 默认 IPP 端口
  static const int ippPort = 631;

  /// 默认 IPP 打印路径（解析 TXT `rp` 失败时的回退值）
  static const String ippDefaultPath = '/ipp/print';

  /// 统一文档格式（由 pdf 包生成）
  static const String documentFormat = 'application/pdf';

  /// IPP 操作码：Print-Job
  static const int operationPrintJob = 0x0002;

  /// IPP 操作码：Get-Printer-Attributes
  static const int operationGetPrinterAttributes = 0x000B;

  /// 单次 IPP 请求超时（秒）
  static const int requestTimeoutSeconds = 3;

  /// 打印发送总超时（秒）—— 略大于单次请求超时
  static const int printJobTimeoutSeconds = 10;

  // ───────── mDNS/NSD 服务类型 ─────────
  static const String serviceTypeIpp = '_ipp._tcp';
  static const String serviceTypePrinter = '_printer._tcp';
  // 爱普生等厂商会额外广播 _epson._tcp，纳入监听以兼容更多机型
  static const String serviceTypeEpson = '_epson._tcp';

  // ───────── 探活（在线/离线） ─────────
  /// 探活周期（秒）：每 15s 发 Get-Printer-Attributes
  static const int livenessIntervalSeconds = 15;

  /// 探活超时（秒）：超时即判离线（满足 P0-1「30s 内转离线」）
  static const int livenessTimeoutSeconds = 3;

  // ───────── 纸张尺寸（A4 @ 72dpi） ─────────
  /// A4 宽度（pt）= 210mm @72dpi = 595.28
  static const double a4WidthPt = 595.28;

  /// A4 高度（pt）= 297mm @72dpi = 841.89
  static const double a4HeightPt = 841.89;

  // ───────── IPP 属性取值 ─────────
  /// 黑白（灰度）模式对应 IPP print-color-mode
  static const String printColorModeMono = 'monochrome';

  /// 彩色模式对应 IPP print-color-mode
  static const String printColorModeColor = 'color';

  /// 介质尺寸 A4（ISO A4）
  static const String mediaA4 = 'iso_a4';

  /// 单面打印
  static const String sidesOneSided = 'one-sided';

  /// 字符集与语言
  static const String charset = 'utf-8';
  static const String naturalLanguage = 'en-us';

  /// 用于探测/提交时的请求用户名
  static const String requestingUserName = 'printer_app';

  /// 作业名前缀
  static const String jobName = 'printer_app_job';
}
