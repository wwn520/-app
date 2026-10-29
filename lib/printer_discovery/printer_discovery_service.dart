import 'dart:async';

import 'package:nsd/nsd.dart';

import 'package:printer_app/core/constants.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/printer_discovery/nsd_wrapper.dart';
import 'package:printer_app/printer_discovery/printer_liveness.dart';
import 'package:printer_app/utils/uri_helper.dart';

/// 打印机发现服务。
///
/// 职责：
/// 1. 通过 [NsdWrapper] 浏览 `_ipp._tcp` / `_printer._tcp`；
/// 2. 把 [Service] 转换为 [Printer]（含 TXT `rp` 路径解析）；
/// 3. 对每台打印机安排 [PrinterLiveness] 周期探活；
/// 4. 维护去重列表，向外暴露 [watchPrinters]（单台）与 [watchPrinterList]（列表）。
class PrinterDiscoveryService {
  final NsdWrapper _nsd;
  final PrinterLiveness _liveness;

  final Map<String, Printer> _map = {};
  final StreamController<Printer> _printerCtrl =
      StreamController<Printer>.broadcast();
  final StreamController<List<Printer>> _listCtrl =
      StreamController<List<Printer>>.broadcast();

  StreamSubscription<Service>? _subscription;
  bool _started = false;

  PrinterDiscoveryService(this._nsd, this._liveness);

  /// 单台打印机变更流（发现 / 探活更新）。
  Stream<Printer> watchPrinters() => _printerCtrl.stream;

  /// 打印机列表流（UI 订阅它渲染列表）。
  Stream<List<Printer>> watchPrinterList() => _listCtrl.stream;

  /// 启动发现（幂等）。
  Future<void> startDiscovery() async {
    if (_started) return;
    _started = true;
    _subscription = _nsd
        .browse([
          Constants.serviceTypeIpp,
          Constants.serviceTypePrinter,
          Constants.serviceTypeEpson,
        ])
        .listen(_onServiceFound, onError: (_) {/* 忽略浏览错误 */});
  }

  /// 手动刷新：重启浏览，强制重新发现。
  Future<void> refresh() async {
    await stop();
    _started = false;
    _map.clear();
    _emitList();
    await startDiscovery();
  }

  /// 停止发现与探活。
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _nsd.stopAll();
    await _liveness.dispose();
    _started = false;
  }

  void _onServiceFound(Service service) {
    final printer = _toPrinter(service);
    _map[printer.id] = printer;
    _printerCtrl.add(printer);
    _emitList();
    // 安排周期探活，状态变化经回调回到这里
    _liveness.scheduleProbe(printer, _onLivenessUpdate);
  }

  void _onLivenessUpdate(Printer updated) {
    _map[updated.id] = updated;
    _printerCtrl.add(updated);
    _emitList();
  }

  void _emitList() {
    _listCtrl.add(_map.values.toList());
  }

  /// 把 nsd 的 [Service] 转换为 [Printer]。
  Printer _toPrinter(Service service) {
    final rawName = service.name ?? service.host ?? 'unknown';
    final id = '${UriHelper.sanitizeServiceName(rawName)}@${service.host}';
    final rp = UriHelper.parseTxtRp(service.txt);
    final model = UriHelper.parseTxtTy(service.txt);
    final host = service.host ?? '';
    final port = service.port ?? Constants.ippPort;
    return Printer(
      id: id,
      name: service.name ?? host,
      host: host,
      port: port,
      ippPath: rp,
      model: model,
      status: PrinterStatus.unknown,
      lastSeen: DateTime.now(),
    );
  }
}
