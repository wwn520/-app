import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:printer_app/ipp_client/ipp_client.dart';
import 'package:printer_app/image_import/image_picker_source.dart';
import 'package:printer_app/image_import/import_manager.dart';
import 'package:printer_app/image_import/share_receiver.dart';
import 'package:printer_app/models/id_card.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/models/print_job.dart';
import 'package:printer_app/models/print_settings.dart';
import 'package:printer_app/printer_discovery/nsd_wrapper.dart';
import 'package:printer_app/printer_discovery/printer_discovery_service.dart';
import 'package:printer_app/printer_discovery/printer_liveness.dart';

/// 主流程打印模式。
enum PrintMode {
  normal, // 普通图片打印
  idCard, // 身份证拼版打印
}

/// 全局主流程状态（跨页面共享的编排状态）。
///
/// 采用 Riverpod 的 StateProvider 直接持有流程数据，避免繁琐的
/// 路由参数传递；各页面读写这些 provider 即可完成流程串联。
class FlowProviders {
  /// 当前选中的打印机（未选为 null）。
  static final selectedPrinter =
      StateProvider<Printer?>((ref) => null);

  /// 已导入的图片列表（普通模式）。
  static final importedImages =
      StateProvider<List<ImportedImage>>((ref) => const []);

  /// 当前打印模式（普通 / 身份证）。
  static final printMode =
      StateProvider<PrintMode>((ref) => PrintMode.normal);

  /// 身份证扫描会话（身份证模式）。
  static final idCardScan = StateProvider<IdCardScan?>((ref) => null);

  /// 已生成的 A4 PDF 字节（预览 / 打印前）。未生成为 null。
  static final generatedPdf =
      StateProvider<Uint8List?>((ref) => null);

  /// 当前打印作业（含状态与错误）。
  static final printJob = StateProvider<PrintJob?>((ref) => null);
}

/// 服务层 Provider（轻量 DI）。
class ServiceProviders {
  /// mDNS/NSD 平台差异抽象。
  static final nsdWrapper = Provider<NsdWrapper>((ref) => NsdWrapper());

  /// IPP 客户端。
  static final ippClient = Provider<IppClient>((ref) => IppClient());

  /// 在线探活（周期 Get-Printer-Attributes）。
  static final printerLiveness = Provider<PrinterLiveness>(
      (ref) => PrinterLiveness(ref.watch(ippClient)));

  /// 打印机发现服务（合并 nsd + 探活）。
  static final printerDiscovery = Provider<PrinterDiscoveryService>(
    (ref) => PrinterDiscoveryService(
      ref.watch(nsdWrapper),
      ref.watch(printerLiveness),
    ),
  );

  /// 在线打印机列表流（自动启动发现）。
  static final printers = StreamProvider<List<Printer>>((ref) {
    final svc = ref.watch(printerDiscovery);
    svc.startDiscovery();
    ref.onDispose(() => svc.stop());
    return svc.watchPrinterList();
  });

  /// 图片导入管理器（相册 / 拍照 / 分享）。
  static final importManager = Provider<ImportManager>(
    (ref) => ImportManager(
      ImagePickerSource(),
      ShareReceiver(),
    ),
  );
}
