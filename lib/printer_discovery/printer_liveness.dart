import 'dart:async';

import 'package:printer_app/core/constants.dart';
import 'package:printer_app/ipp_client/ipp_client.dart';
import 'package:printer_app/models/printer.dart';

/// 打印机在线/离线探活。
///
/// 设计：发现一台打印机后调用 [scheduleProbe]，每 [livenessIntervalSeconds]
/// 秒发一次 IPP `Get-Printer-Attributes`，超时（[livenessTimeoutSeconds]）即判离线。
/// 通过回调 [onUpdate] 把最新状态回传上层（发现服务更新列表并推给 UI）。
class PrinterLiveness {
  final IppClient _client;
  final Map<String, Timer> _timers = {};

  PrinterLiveness(this._client);

  /// 为某台打印机安排周期探活（并立即探一次）。
  void scheduleProbe(Printer printer, void Function(Printer) onUpdate) {
    _timers[printer.id]?.cancel();
    _probeAndUpdate(printer, onUpdate);
    _timers[printer.id] = Timer.periodic(
      Duration(seconds: Constants.livenessIntervalSeconds),
      (_) => _probeAndUpdate(printer, onUpdate),
    );
  }

  Future<void> _probeAndUpdate(
      Printer printer, void Function(Printer) onUpdate) async {
    final alive = await _client.probeAlive(printer);
    onUpdate(printer.copyWith(
      status: alive ? PrinterStatus.online : PrinterStatus.offline,
      lastSeen: DateTime.now(),
    ));
  }

  /// 取消所有探活定时器（停止发现时调用）。
  Future<void> dispose() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
