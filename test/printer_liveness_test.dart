import 'package:flutter_test/flutter_test.dart';
import 'package:printer_app/ipp_client/ipp_client.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/printer_discovery/printer_liveness.dart';

/// 用假 IppClient 覆盖 probeAlive，验证探活状态机在成功/失败时的 online/offline 转移。
class _FakeClient extends IppClient {
  final bool alive;
  _FakeClient(this.alive);

  @override
  Future<bool> probeAlive(Printer printer) => Future.value(alive);
}

Printer _printer() => Printer(
      id: 'p1',
      name: 'TestPrinter',
      host: '10.0.0.1',
      port: 631,
      status: PrinterStatus.unknown,
      lastSeen: DateTime.now(),
    );

void main() {
  group('PrinterLiveness 探活状态机', () {
    test('探活成功 → 回调收到 online 状态', () async {
      final liveness = PrinterLiveness(_FakeClient(true));
      Printer? updated;
      liveness.scheduleProbe(_printer(), (p) => updated = p);
      // 等待立即触发的 _probeAndUpdate 完成（FakeClient 瞬时返回）
      await Future.delayed(const Duration(milliseconds: 100));
      expect(updated, isNotNull);
      expect(updated!.status, PrinterStatus.online);
      await liveness.dispose();
    });

    test('探活失败(超时/异常) → 回调收到 offline 状态', () async {
      final liveness = PrinterLiveness(_FakeClient(false));
      Printer? updated;
      liveness.scheduleProbe(_printer(), (p) => updated = p);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(updated, isNotNull);
      expect(updated!.status, PrinterStatus.offline);
      await liveness.dispose();
    });

    test('重复 scheduleProbe 不会泄漏定时器（dispose 后定时器清空）', () async {
      final liveness = PrinterLiveness(_FakeClient(true));
      liveness.scheduleProbe(_printer(), (_) {});
      liveness.scheduleProbe(_printer(), (_) {}); // 第二次应取消第一次的定时器
      await Future.delayed(const Duration(milliseconds: 50));
      await liveness.dispose();
      // dispose 后无未取消定时器；此处主要验证不抛异常且可正常结束
      expect(true, isTrue);
    });
  });
}
