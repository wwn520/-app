import 'dart:async';

import 'package:nsd/nsd.dart';

/// nsd 平台差异抽象封装。
///
/// 统一跨平台（Android NSD / iOS Bonjour）的浏览接口，
/// 对外暴露一个简单的 [Service] 流，屏蔽 Discovery 的监听/停止细节，
/// 便于后续在 iOS 不稳定时切换到 multicast_dns（接口不变）。
///
/// nsd 5.x 真实 API：顶层函数 `startDiscovery` / `stopDiscovery`；
/// [Discovery] 通过 `addServiceListener` 接收 found/lost 事件。
class NsdWrapper {
  final List<Discovery> _active = [];

  /// 浏览多个服务类型，返回合并后的 [Service] 流。
  ///
  /// [types] 通常为 `[_ipp._tcp, _printer._tcp]`。
  Stream<Service> browse(List<String> types) {
    final controller = StreamController<Service>.broadcast();
    for (final type in types) {
      startDiscovery(type).then((discovery) {
        _active.add(discovery);
        discovery.addServiceListener((service, status) {
          if (status == ServiceStatus.found) {
            controller.add(service);
          }
        });
      }).catchError((_) {
        // 某些平台/类型不被支持，忽略
      });
    }
    return controller.stream;
  }

  /// 停止所有进行中的浏览。
  Future<void> stopAll() async {
    for (final discovery in _active) {
      try {
        await stopDiscovery(discovery);
      } catch (_) {
        // 已停止则忽略
      }
    }
    _active.clear();
  }
}
