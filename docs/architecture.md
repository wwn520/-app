# 无广告打印机 App — 系统架构设计 + 任务分解

> 文档状态：架构 v1.0 ｜ 角色：架构师 高见远（Gao） ｜ 日期：2026-10-26
> 上游：PRD v0.1（产品经理 许清楚） ｜ 平台：Flutter 3.x 原生（Android + iOS 一套代码）

---

## 1. 实现方案 + 框架选型

### 1.1 技术难点分析

| 难点 | 说明 | 解决思路 |
|---|---|---|
| 局域网零配置发现 | 不同平台 mDNS/Bonjour 实现差异（iOS Bonjour / Android NSD），需解析 TXT 记录拿 IPP path | 用 `nsd` 统一封装，跨平台扫 `_ipp._tcp` / `_printer._tcp` |
| 在线/离线状态 | mDNS 只告知「存在」，断电后需主动探活 | 周期性 IPP `Get-Printer-Attributes` 探活（超时判离线） |
| IPP 协议直连 | 需自组二进制 IPP 报文 + HTTP/1.1 `application/ipp` 传输 + PDF 文档体 | 自实现轻量 `IppClient`（Dart），文档统一转 PDF |
| 黑白/彩色 + A4 版面可控 | 依赖打印机能力，直接发图不可控 | 本地用 `pdf` 包排版到 A4；色彩走 IPP `print-color-mode` 属性 |
| 身份证端侧识别拼版 | 需边缘检测 + 透视校正 + 拼版，且全程本地、断网可用 | `edge_detect`（OpenCV）取四角 + 纯 Dart 透视校正 + `pdf` 拼版 |
| 隐私/无广告 | 敏感图绝不联网、App 无广告位 | 身份证处理模块零网络调用；代码层无广告 SDK 依赖 |
| 多来源导入 | 相册多选、拍照、微信分享 | `image_picker` + `receive_sharing_intent`（系统分享） |

### 1.2 框架/库选型（确认 + 调整）

**确认 Flutter 3.x + Dart**（PRD 指定）。以下逐项确认/优化：

1. **状态管理：选 Riverpod（flutter_riverpod + riverpod_annotation 代码生成）**
   - 理由：
     - 多个独立数据流（mDNS 发现流、IPP 探活、导入、扫描状态、打印状态）天然适合 `StreamProvider` / `AsyncNotifier`；
     - 不依赖 `BuildContext` 取值，数据层（发现/打印）与 UI 彻底解耦；
     - 编译期安全 + Provider 可覆盖，**测试性最佳**（工程师可 mock `IppClient`/`PrinterDiscoveryService`）；
     - 自带轻量 DI，替代手动 Service Locator。
   - 不选 Provider：依赖 Context、跨子树共享与测试注入偏弱。

2. **打印机发现：`nsd` ✅（沿用推荐）**
   - 跨平台 NSD/Bonjour 封装，扫 `_ipp._tcp.local` 与 `_printer._tcp.local`，回调 `ServiceFound` 带 IP/port/TXT。
   - 备选 `multicast_dns`（Flutter 官方 mDNS，直接 Bonjour）：若 `nsd` 在 iOS 上回调不稳定可切换，接口可经 `nsd_wrapper.dart` 抽象隔离。

3. **打印协议：自实现轻量 IPP 客户端 ✅（沿用推荐）**
   - 基于 `http`（HTTP/1.1 POST，`Content-Type: application/ipp`），请求体 = 二进制 IPP 报文 + PDF 文档字节。
   - 提交 `Print-Job`；文档格式统一 `application/pdf`（由 `pdf` 包生成），使黑白/彩色、A4 版面完全可控、兼容性好。
   - 探活用 `Get-Printer-Attributes`。

4. **PDF 排版：`pdf` ✅**
   - 把图片（单图 / N 合一 / 身份证拼版）排版到 A4（`PdfPageFormat.a4`，595.28×841.89 pt@72dpi）。
   - 黑白模式：在嵌入前用 `image` 包做灰度转换 + 设 IPP `print-color-mode=monochrome`，双重保险。

5. **图片导入：`image_picker` + `receive_sharing_intent` ✅（沿用推荐）**
   - `image_picker`：相册多选 + 相机拍照；`receive_sharing_intent`：接收系统分享（微信「分享」→ 本 App，无需 OpenSDK）。

6. **身份证识别：调整 —— `edge_detect`（自动四角）+ 纯 Dart 透视校正（不引入全量 opencv）**
   - 自动：用 `edge_detect`（封装 OpenCV Canny + 轮廓近似）输出四角 `Quad`；
   - 校正：用 `image` 包做灰度/对比度增强，透视校正采用**自写 homography + `image` 像素采样**（纯 Dart，无重型原生构建），兼顾质量与离线/隐私；
   - 手动兜底：自定义四角拖拽 widget（`corner_editor_overlay.dart`），复用同一校正函数；
   - 预留升级位：若中端机校正质量不足，后续可换 `opencv` `warpPerspective`（已在共享知识标注）。

### 1.3 架构模式

- **分层 + MVVM（Riverpod 驱动的 VM）**：`models`（纯数据）→ `core/services`（发现/IPP/PDF/扫描，无 UI 依赖）→ `providers`（Riverpod 把 service 暴露给 UI）→ `screens/widgets`（UI）。
- UI 通过 Provider 订阅状态，业务动作派发给 service；**身份证处理链路完全不触碰任何网络 service**。

---

## 2. 文件清单（lib/ 下按模块组织）

```
lib/
├── main.dart                         # 入口：ProviderScope + runApp
├── app/
│   ├── app.dart                      # MyApp：主题 + 路由装配
│   ├── router.dart                   # 路由表（home/discovery/...）
│   └── theme.dart                    # 浅色主题（P2 暗黑预留）
├── core/
│   ├── constants.dart                # 纸张尺寸、IPP 默认、超时、服务类型、探活间隔
│   └── result.dart                   # Result<E> 成功/失败包装（可选）
├── models/
│   ├── printer.dart                  # Printer + PrinterStatus
│   ├── print_job.dart                # PrintJob + PrintStatus
│   ├── print_settings.dart           # PrintSettings + ColorMode/PaperSize/PrintQuality/PrintSides
│   ├── id_card.dart                  # IdCardScan + Quad + ImageSource
│   └── app_error.dart                # AppError + ErrorCode
├── printer_discovery/
│   ├── printer_discovery_service.dart  # 封装 nsd，暴露 Stream<Printer>
│   ├── printer_liveness.dart           # 周期 Get-Printer-Attributes 探活
│   └── nsd_wrapper.dart                # 平台差异抽象
├── ipp_client/
│   ├── ipp_client.dart               # IppClient：sendPrintJob / getPrinterAttributes / probeAlive
│   ├── ipp_message.dart              # 二进制 IPP 报文编解码
│   └── ipp_attributes.dart           # 操作/作业属性组构造（print-color-mode, media, sides...）
├── pdf_layout/
│   ├── pdf_builder.dart              # 单图 / 多合一 / 身份证拼版 → A4 PDF
│   ├── id_card_compositor.dart       # 两面拼一页 A4（正上/徽下 + 镜像切换）
│   └── image_preprocess.dart         # 灰度/对比度/适配 A4
├── image_import/
│   ├── image_picker_source.dart      # 相册多选 + 拍照
│   ├── share_receiver.dart           # receive_sharing_intent 接入
│   └── import_manager.dart           # 统一多来源 → List<ImportedImage>
├── id_card_scan/
│   ├── edge_detector.dart            # 封装 edge_detect → Quad
│   ├── perspective_corrector.dart    # Dart homography 校正（自动+手动）
│   └── corner_editor_controller.dart # 手动四角状态
├── settings/
│   ├── settings_service.dart         # shared_preferences 持久化（设置 + 常用打印机）
│   └── settings_provider.dart        # Riverpod providers
├── screens/
│   ├── home_screen.dart              # 流程编排（发现→导入→设置→预览→打印）
│   ├── discovery_screen.dart         # 打印机列表 + 在线状态 + 刷新
│   ├── source_select_screen.dart     # 选相册/拍照/分享
│   ├── editor_screen.dart            # 单图编辑/预览
│   ├── id_card_scan_screen.dart      # 上传正反面 → 扫描 → 手动兜底
│   ├── settings_screen.dart          # 纸张/色彩/质量/（P2 双面）
│   ├── preview_screen.dart           # A4 版面预览
│   └── print_status_screen.dart      # 发送中/成功/失败 + 重试
├── widgets/
│   ├── printer_list_tile.dart        # 设备行（名/IP/状态点）
│   ├── color_mode_switch.dart        # 黑白/彩色切换
│   ├── quality_selector.dart         # 草稿/标准/高质量
│   ├── a4_preview_widget.dart        # A4 比例预览
│   ├── corner_editor_overlay.dart    # 手动四角拖拽
│   ├── status_banner.dart            # 打印状态横幅
│   └── source_picker_sheet.dart      # 底部来源选择
└── utils/
    ├── uri_helper.dart               # ippUri 构造 / TXT 解析 rp
    └── image_utils.dart             # 字节/路径互转、缩放
```

---

## 3. 数据结构与接口（关键签名）

> 用 Mermaid 类图见 `class-diagram.mermaid`；下表为接口契约摘要。

### 3.1 模型（models/）

```dart
enum PrinterStatus { online, offline, unknown }

class Printer {
  final String id;        // nsd service name（去重主键）
  final String name;      // 展示名（ty / 设备名）
  final String host;      // IP
  final int port;         // 631
  final String? ippPath;  // 如 /ipp/print，解析 TXT.rp 失败回退
  final String? model;    // TXT.ty
  final PrinterStatus status;
  final DateTime lastSeen;
  Uri get ippUri => Uri(scheme:'ipp', host:host, port:port, path: ippPath ?? '/ipp/print');
}

enum ColorMode { grayscale, color }       // → IPP print-color-mode: monochrome / color
enum PaperSize { a4 }                     // P2 加 a5 / photo
enum PrintQuality { draft, normal, high } // → IPP 分辨率/质量档
enum PrintSides { oneSided }              // P2 加 twoSidedLongEdge

class PrintSettings {
  final PaperSize paper;      // 默认 a4
  final ColorMode colorMode;  // 默认 grayscale
  final PrintQuality quality; // 默认 normal
  final PrintSides sides;     // 默认 oneSided
  final int copies;           // 默认 1
}

enum PrintStatus { idle, sending, success, failed }

class PrintJob {
  final String id;
  final Printer printer;
  final PrintSettings settings;
  final Uint8List pdf;   // 已生成的 A4 PDF 字节
  PrintStatus status;
  AppError? error;
}

enum ImageSource { album, camera, share }

class ImportedImage {
  final String path;        // 本地文件路径
  final ImageSource source;
  final Uint8List? bytes;
}

class Quad {                // 归一化 0..1 四角
  final Point tl, tr, br, bl;
}

class IdCardScan {
  final ImportedImage front;  // 人像面
  final ImportedImage back;   // 国徽面
  Quad? frontCorners;
  Quad? backCorners;
  Uint8List? correctedFront;
  Uint8List? correctedBack;
  bool manualMode = false;
}

enum ErrorCode { printerOffline, printerBusy, jobRejected, paperEmpty, networkTimeout, ippError, unknown }

class AppError {
  final ErrorCode code;
  final String friendlyMessage;   // 中文可读文案
  final String? technical;        // 原始技术信息（仅日志）
}
```

### 3.2 服务（core/services）

```dart
// 发现
class PrinterDiscoveryService {
  Stream<Printer> watchPrinters();   // 合并 nsd 结果 + 探活状态
  Future<void> startDiscovery();
  Future<void> refresh();
  Future<void> stop();
}
class PrinterLiveness {
  void scheduleProbe(Printer p);          // 每 15s 探活
  Future<bool> probeAlive(Printer p);     // IppClient.getPrinterAttributes + 超时
}

// IPP
class IppClient {
  Future<IppResponse> sendPrintJob(Printer p, Uint8List pdf, PrintSettings s);
  Future<IppResponse> getPrinterAttributes(Printer p);
  Future<bool> probeAlive(Printer p);
  Future<IppResponse> _send(Printer p, IppRequest req);
}
class IppMessage {
  Uint8List encode(int operation, Map<String,Object> attrs);
  IppResponse decode(Uint8List bytes);
}

// PDF
class PdfBuilder {
  Future<Uint8List> buildSingle(Uint8List img, PrintSettings s);
  Future<Uint8List> buildGrid(List<Uint8List> imgs, int perPage, PrintSettings s);
  Future<Uint8List> buildIdCard(Uint8List front, Uint8List back, {bool flipBack = false});
}

// 导入
class ImportManager {
  Future<List<ImportedImage>> pickFrom(ImageSource s);
}

// 身份证扫描
class EdgeDetector {
  Future<Quad?> detect(Uint8List img);   // 自动四角，失败返回 null
}
class PerspectiveCorrector {
  Future<Uint8List> correct(Uint8List img, Quad q);  // 自动/手动通用
}

// 设置
class SettingsService {
  PrintSettings loadSettings();
  Future<void> saveSettings(PrintSettings s);
  Future<void> saveFrequentPrinter(Printer p);
  List<Printer> loadFrequentPrinters();
}
```

---

## 4. 程序调用流程（Mermaid 时序图）

> 完整图见 `sequence-diagram.mermaid`。

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Home as HomeScreen
    participant Disc as PrinterDiscoveryService
    participant NS as nsd
    participant IPP as IppClient
    participant Import as ImportManager
    participant Scan as IdCardScanFlow
    participant PDF as PdfBuilder
    participant Status as PrintStatusScreen

    User->>Home: 启动 App
    Home->>Disc: startDiscovery()
    Disc->>NS: browse(_ipp._tcp, _printer._tcp)
    NS-->>Disc: ServiceFound(Printer)
    Disc-->>Home: Stream<Printer> 列表(在线)
    Home->>User: 展示在线打印机

    User->>Home: 选图片来源(相册/拍照/微信)
    Home->>Import: pickFrom(source)
    Import-->>Home: List<ImportedImage>

    opt 身份证模式
        User->>Scan: 上传人像面 + 国徽面
        Scan->>Scan: EdgeDetector.detect → Quad?
        alt 自动达标
            Scan->>Scan: PerspectiveCorrector.correct()
        else 不达标/手动
            User->>Scan: 拖拽四角(corner_editor_overlay)
            Scan->>Scan: correct(manualQuad)
        end
        Scan->>PDF: buildIdCard(front, back)
    else 普通模式
        User->>PDF: buildSingle / buildGrid
    end

    User->>Home: 设置(纸张A4/色彩/质量)
    Home->>PDF: 生成 A4 PDF (Uint8List)
    PDF-->>Home: pdfBytes

    User->>Status: 点「打印」
    Status->>IPP: sendPrintJob(printer, pdf, settings)
    IPP->>IPP: 组装 Print-Job(print-color-mode, media=A4, sides)
    IPP->>Printer: HTTP POST application/ipp + PDF
    alt 成功
        Printer-->>IPP: job-id, successful-ok
        IPP-->>Status: PrintStatus.success
        Status-->>User: 打印成功
    else 失败/超时
        Printer-->>IPP: error / 无响应
        IPP-->>Status: PrintStatus.failed + AppError
        Status-->>User: 友好错误 + 重试
        User->>Status: 重试 → sendPrintJob
    end
```

**探活旁路（离线更新）**：`PrinterLiveness.scheduleProbe` 每 15s 调 `IppClient.getPrinterAttributes`，超时(3s) 即把该 `Printer.status` 置 `offline` 并经 `watchPrinters()` 推给 UI（满足 P0-1「30s 内转离线」）。

---

## 5. 任务列表（有序、含依赖、≤5 个任务）

> 规则遵守：首任务为基础设施；每任务 ≥3 文件；T02–T04 仅依赖 T01（可并行），T05 依赖 T02/T03/T04。覆盖 P0 全量 + P1 关键项；P2 不在首轮。

| Task | 标题 | 依赖 | 优先级 | 源文件（≥3） |
|---|---|---|---|---|
| **T01** | 项目基础设施与骨架 | — | P0 | `pubspec.yaml`, `lib/main.dart`, `lib/app/{app,router,theme}.dart`, `lib/core/constants.dart`, `lib/models/*`, `lib/utils/*` |
| **T02** | 打印机发现 + 在线探活 + IPP 客户端 + 打印状态 UI | T01 | P0 | `lib/printer_discovery/*`, `lib/ipp_client/*`, `lib/screens/discovery_screen.dart`, `lib/screens/print_status_screen.dart`, `lib/widgets/printer_list_tile.dart`, `lib/widgets/status_banner.dart` |
| **T03** | 图片导入 + 打印设置 | T01 | P0 | `lib/image_import/*`, `lib/settings/*`, `lib/screens/source_select_screen.dart`, `lib/screens/settings_screen.dart`, `lib/widgets/source_picker_sheet.dart`, `lib/widgets/color_mode_switch.dart`, `lib/widgets/quality_selector.dart` |
| **T04** | 身份证端侧识别拼版 + PDF 排版 + A4 预览 | T01 | P0 | `lib/id_card_scan/*`, `lib/pdf_layout/*`, `lib/screens/id_card_scan_screen.dart`, `lib/screens/editor_screen.dart`, `lib/screens/preview_screen.dart`, `lib/widgets/a4_preview_widget.dart`, `lib/widgets/corner_editor_overlay.dart` |
| **T05** | 主流程串联 + 集成联调 | T02,T03,T04 | P0 | `lib/screens/home_screen.dart`, `lib/app/router.dart`(装配), `lib/settings/settings_provider.dart`(接线), 联调与 P0 验收 |

**依赖关系图**：`T01 → T02/T03/T04 → T05`。

> 说明：P1-1（常用打印机持久化）、P1-2（A4 预览）、P1-3（多合一）、P1-4（手动兜底）、P1-5（质量档）、P1-6（重试文案）均已分别落在 T02/T03/T04/T05 中；P2 全部后置。

---

## 6. 依赖包列表（pubspec.yaml 关键 dependencies）

```yaml
dependencies:
  flutter: sdk
  flutter_riverpod: ^2.4.0        # 状态管理 + 轻量 DI（选 Riverpod，见 §1.2）
  riverpod_annotation: ^2.3.0     # 代码生成
  nsd: ^0.6.0                     # 跨平台 mDNS/NSD 发现 (_ipp._tcp / _printer._tcp)
  http: ^1.2.0                    # IPP 客户端 HTTP/1.1 传输（application/ipp）
  pdf: ^3.10.0                    # 图片排版到 A4 PDF（单图/多合一/身份证拼版）
  image_picker: ^1.0.0            # 相册多选 + 拍照
  receive_sharing_intent: ^1.8.0  # 微信/系统分享接入（无需 OpenSDK）
  edge_detect: ^1.1.0             # 端侧 OpenCV 文档边缘检测 → 四角
  image: ^4.1.0                   # 灰度/对比度增强、图像预处理、透视采样
  shared_preferences: ^2.2.0      # 打印设置 + 常用打印机持久化
  path_provider: ^2.1.0           # 本地图片缓存路径
dev_dependencies:
  build_runner, riverpod_generator, flutter_lints, freezed(可选)
```

> 透视校正默认走纯 Dart（`image` + 自写 homography），不引入全量 `opencv`；若质量不足再升级 `opencv` `warpPerspective`（已预留接口位）。

---

## 7. 共享知识（跨文件约定）

- **ColorMode 映射**：`grayscale → print-color-mode=monochrome`；`color → print-color-mode=color`。嵌入 PDF 前对灰度模式做灰度转换（双重保险）。
- **PaperSize 常量**：A4 = 210×297mm = `595.28×841.89 pt`@72dpi，存于 `core/constants.dart`（`PdfPageFormat.a4`）。
- **Printer 字段契约**：`id=nsd服务名`、`host=IP`、`port=631`、`ippPath` 优先取 TXT `rp`，失败回退 `/ipp/print`；`status` 由发现+探活共同决定。
- **ErrorCode → 友好文案**（中文，非技术码）：
  - `printerOffline` →「打印机已离线，请检查电源/同 WiFi 后重试」
  - `printerBusy` →「打印机正忙，请稍后再试」
  - `jobRejected` →「打印作业被拒绝，可能是纸张尺寸不支持」
  - `paperEmpty` →「打印机缺纸，请加纸后重试」
  - `networkTimeout` →「网络超时，请确认手机与打印机在同一 WiFi」
  - `ippError` →「打印机返回异常，可重试或换设备」
  - `unknown` →「打印失败，请重试」
- **IPP 默认**：scheme `ipp://`、port `631`、operation `Print-Job`、document-format `application/pdf`；属性组含 `print-color-mode` / `media`(iso-a4) / `copies` / `sides`(one-sided)。`print-color-mode` 兼容读取 `ColorModel` 固件差异。
- **探活**：`Get-Printer-Attributes` 每 15s，超时 3s → 离线（满足 P0-1 30s 内转离线）。
- **隐私红线**：身份证处理链路（EdgeDetector / PerspectiveCorrector / PdfBuilder.buildIdCard）**零网络调用**；不缓存身份证原图到共享目录；断网可完成。
- **无广告底线**：依赖清单不含任何广告 SDK；UI 无广告位。
- **统一响应**：业务层返回用 `Result<E>`/`AppError`，UI 统一经 `status_banner` 展示。

---

## 8. 待明确事项 —— 架构侧拍板建议（请主理人/用户最终确认）

| # | 原问题 | 架构侧建议 | 理由 |
|---|---|---|---|
| 1 | 首版是否双面 | **不做双面，仅单面**；`PrintSides` 枚举 + IPP `sides` 属性位已预留，P2 接入零成本 | P0 硬门槛未含双面；先保单面稳定 |
| 2 | 是否打印历史 | **首版不做历史**（P2-1）；仅 `shared_preferences` 持久化「常用打印机」(P1-1) 与用户设置；默认不缓存身份证图 | 历史涉及存储权限 + 隐私，延后；常用设备足够 P1 |
| 3 | 微信导入方式 | **系统分享**（`receive_sharing_intent`），不接 OpenSDK | 无需企业资质/审核、最稳、符合隐私；微信「分享到」本 App 即可 |
| 4 | 端侧识别引擎 | **`edge_detect` 自动四角 + 纯 Dart 透视校正**；手动兜底用自定义四角拖拽；准确率目标 ≥85% 自动达标（中端机），<85% 转手动；性能 <1.5s/面 | 隐私优先、零重型原生构建；预留 `opencv` 升级位 |
| 5 | IPP 认证/白名单 | **首版匿名通用 IPP，不维护机型白名单**；失败给友好文案；认证/白名单留 P1/P2 | 主流家用机（爱普生/惠普/佳能）多匿名 IPP；首版广兼容 |
| 6 | 纸张范围 | **首版严格只做 A4**；`PaperSize` 枚举 + 常量驱动 UI/PDF，P2-3 扩展 A5/照片纸零改动 | 控制预览与参数复杂度，聚焦 P0 |

---

## 9. 仍不清楚 / 假设项（UNCLEAR）

- `edge_detect` 实际返回形态（四角点 vs 边图）需工程师按包 API 适配 `EdgeDetector` 包装契约；若包仅出边图无四角，则需加轮廓拟合步骤。
- 微信/系统分享：iOS 需配 `CFBundleDocumentTypes`/`UTImportedTypeDeclarations`，Android 需 `intent-filter`（`receive_sharing_intent` 文档为准）。
- 部分打印机用 `ipps://`(HTTPS/631)；首版仅 `ipp://`，`ipps` 留 P1。
- 部分打印机 IPP path 非 `/ipp/print`（如 `/printer`、`/ipp/port1`）：发现时解析 TXT `rp`/`adminurl`，失败回退默认。
- `print-color-mode` 在部分固件为 `ColorModel`：客户端做兼容读取。
- 原生构建：`edge_detect` 含 OpenCV 原生依赖，需确保 Android NDK / iOS pod 正常；若接入 `opencv` 升级位需额外原生配置。
