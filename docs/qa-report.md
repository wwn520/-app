# QA 测试与独立验证报告

**测试工程师**：严过关（Yan）｜**项目**：无广告打印机 App（Flutter + IPP/AirPrint，目标 EPSON L3250）
**日期**：2026-10-26｜**范围**：T01–T05 全部 Dart 代码（lib/）静态审查 + 单元测试

---

## 0. 环境说明（重要）

本机 **未安装 Flutter / Dart SDK**（`flutter --version` / `dart --version` 均 `command not found`），
因此 **无法在本地执行 `flutter pub get` / `flutter test`**。

- 所有 `test/*.dart` 已按 `flutter_test` 规范写好，断言均针对**正确行为**编写。
- 源码存在若干**编译级缺陷**（见 §2 BUG-E 系列），在修复前整个 `printer_app` 包无法编译，
  故测试在修复前无法运行——这是**预期内的源码阻塞**，非测试问题。
- 本地运行命令见 §6。

---

## 1. 测试清单（共 9 文件 / 约 42 用例）

| 测试文件 | 覆盖模块 | 类型 | 关键断言 |
|---|---|---|---|
| `test/constants_test.dart` | `core/constants.dart` | 纯逻辑 | A4@72dpi=595.28×841.89；`iso_a4`/`monochrome`/`color`/`one-sided`/`application/pdf`；操作码 `0x0002`/`0x000B`；探活 15s/3s |
| `test/app_error_test.dart` | `models/app_error.dart` | 纯逻辑 | 7 个错误码均有非空中文文案；IPP 状态码→错误码映射（busy/ippError/jobRejected/unknown）；`toString` 安全 |
| `test/ipp_attributes_test.dart` | `ipp_client/ipp_attributes.dart` | 字节标签 | `IppTags` 各值标签 = **RFC 8010 标准值**（当前源码不符，会失败→暴露 BUG-IPP） |
| `test/ipp_message_test.dart` | `ipp_client/ipp_message.dart` | 字节结构 | 报文头版本/操作码/request-id；Print-Job 关键属性名+值标签+取值；Get-Printer-Attributes 操作码；decode 成功/失败、job-id 解析 |
| `test/perspective_corrector_test.dart` | `id_card_scan/perspective_corrector.dart` | 纯逻辑 | 恒等四角尺寸一致；单应矩阵方向正确（选区=左上→输出中心红 / 右下→蓝）；退化共点返回原字节；无法解码抛异常 |
| `test/id_card_compositor_test.dart` | `pdf_layout/id_card_compositor.dart` | 纯逻辑 | 上下/左右布局矩形均落在 A4 内不越界；正面(红)/国徽(蓝)位置正确；`flipBack=true` 水平镜像左右亮度互换；无法解码抛异常 |
| `test/printer_liveness_test.dart` | `printer_discovery/printer_liveness.dart` | 状态机 | 探活成功→回调 `online`；失败→`offline`；重复 `scheduleProbe` 取消旧定时器 |
| `test/uri_helper_test.dart` | `utils/uri_helper.dart` | 纯逻辑 | `buildIppUri`/`toHttpEndpoint`；`parseTxtRp`；`sanitizeServiceName` |
| `test/edge_detector_test.dart` | `id_card_scan/edge_detector.dart` | 结构/桩 | 无法解码→`null`；合成图不抛异常且返回合法 Quad；**依赖修复前无法编译** |

---

## 2. 独立代码审查发现（源码 Bug）

> 路由：全部为**源码缺陷** → 已通过 SendMessage 反馈 `software-engineer` 修复。

### 🔴 BUG-IPP（严重，阻断真实打印）—— `lib/ipp_client/ipp_attributes.dart` 第 20–24 行
`IppTags` 字符串类标签取值**误用旧草案值**，与现行 **RFC 8010**（`rfc-editor.org/rfc/rfc8010.html` Table 6）不符：

| 属性 | 当前（错误） | 应为（RFC 8010） |
|---|---|---|
| `charset` | `0x34` | **`0x47`** |
| `naturalLanguage` | `0x35` | **`0x48`** |
| `mimeMediaType` | `0x36` | **`0x49`** |
| `textWithoutLanguage` | `0x32` | **`0x41`** |
| `nameWithoutLanguage` | `0x33` | **`0x42`** |

`integer=0x21`/`boolean=0x22`/`enumTag=0x23`/`keyword=0x44`/`uri=0x45` 正确。
影响：`attributes-charset`、`attributes-natural-language`、`document-format`、
`requesting-user-name`、`job-name` 全部携带错误 value-tag，真实打印机将**拒绝或误解析请求 → 打印失败**。

### 🔴 BUG-DEP（严重，阻断编译）—— `pubspec.yaml` 第 77 行
依赖 `edge_detect: ^1.1.0` **在 pub.dev 不存在**（实测 `pub.dev/packages/edge_detect` → 404）。
正确包名是 **`edge_detection`**。→ `flutter pub get` 直接失败，App 无法构建。

### 🔴 BUG-EDGE-IMPORT（严重，阻断编译）—— `lib/id_card_scan/edge_detector.dart` 第 4 行
`import 'package:edge_detect/edge_detect.dart';` 路径错误，应为
`import 'package:edge_detection/edge_detection.dart';`（随 BUG-DEP 一并修正）。

### 🟠 BUG-EDGE-API（高，阻断编译/功能错误）—— `lib/id_card_scan/edge_detector.dart` 第 60–69 行
`autoCropNative` 调用 `EdgeDetection.detectEdge(sourcePath, savePath: savePath)`。
真实 `edge_detection` 包 `detectEdge` **不接受任何参数**（它启动原生相机/裁剪 UI 并返回裁剪后路径），
无法传入已有图片做"按源图高精度裁边"。该设计假设与真实 API 不符，**无法编译且功能不成立**，需重新设计
（改为无参调用并接受其相机流结果，或换用支持"传入图片裁剪"的方案）。

### 🟠 BUG-EDGE-NORM（高，自动检测产出错误四角）—— `lib/id_card_scan/edge_detector.dart` 第 46–53 行
`detect()` 中四角在 **480 宽 small 图坐标**下计算，但 `_norm(corners[i], src.width, src.height)`
误用**原始图尺寸**做归一化，导致所有四角被压到左上角（归一化值仅为真实值的 ~24%），自动四角检测失效。
应改为 `_norm(corners[i], w, h)`（`w`/`h` 即 small 图宽高，缩放不变性保证归一化正确）。

---

## 3. 次要观察（非阻断，建议优化）

1. **`IppAttributes.printJob`** 把 `document-format` 放进**第二个** `operations-attributes-tag` 组，
   而非与 `attributes-charset` 同组。RFC 允许组重复，但部分严格打印机更期望同组；建议合并。
2. **`ErrorCode.paperEmtpy`** 已定义并有中文文案（覆盖度达标），但**无任何代码路径产出它**
   （未解析 `printer-state-reasons` 的 `media-empty`）。属可达性缺口，不影响 PRD 覆盖度验收。
3. **`IppMessage.decode`** 对截断响应未做长度保护，畸形字节可能抛 `RangeError`；建议加边界校验。
4. **`ServiceProviders.printers`** `StreamProvider` 在 provider 体内调用 `svc.startDiscovery()` 属副作用反模式，
   建议移至 `ref.onDispose` 前的显式启动或 `Provider` 生命周期管理。

---

## 4. 已验证正确（无 Bug）的模块

- **`perspective_corrector.dart`**：单应矩阵 DLT + 高斯-约当消元、双线性采样边界（`sx>=w-1`/`sy>=h-1` 判定正确，
  不会越界）数学正确；通过四色象限测试可验证映射方向无误。
- **`id_card_compositor.dart`**：上下/左右布局矩形坐标精确落于 A4 内（`margin=24`，`cellH/2` 取整后对称），
  镜像 `flipBack` 逻辑正确。
- **`printer_liveness.dart`**：`Timer.periodic(15s)` 探活，`IppClient` 传 3s 超时，超时/异常→`offline`；
  最坏 15s+3s=18s<30s 满足"30s 内转离线"。
- **`app_error.dart` / `constants.dart` / `uri_helper.dart` / `print_settings.dart` / `printer.dart` / `print_job.dart`**：
  枚举、中文文案、IPP 取值、URI 映射全部正确。
- **Riverpod 作用域**：`main.dart` 已用 `ProviderScope` 包裹，无作用域问题（任务预检担忧已排除）。

---

## 5. 需真机 / 集成验证项

- `edge_detect`/`edge_detection` 原生裁剪 UI（BUG-EDGE-API 修复后的真实行为）。
- `nsd` mDNS 发现、`image_picker`、`receive_sharing_intent` 原生插件调用（无纯逻辑可测，仅结构/桩）。
- `IppClient` 真实 HTTP/IPP 提交到 EPSON L3250（含 3s 超时→`networkTimeout` 路径，需真实/超时端点）。
- 端到端：拍摄身份证 → 透视校正 → 拼版 → 生成 A4 PDF → 打印。

---

## 6. 本地运行命令（供工程师/用户）

```bash
# 1) 安装 Flutter SDK 3.16+ 并配置（本机当前缺失）
# 2) 先修复 §2 的 BUG-DEP / BUG-EDGE-IMPORT / BUG-EDGE-API / BUG-IPP / BUG-EDGE-NORM
flutter pub get
flutter analyze
flutter test            # 默认运行 test/ 下全部用例
flutter test test/ipp_message_test.dart   # 单文件
flutter test test/perspective_corrector_test.dart
```

---

## 7. 智能路由判定（Smart Routing）

- **判定：Engineer（软件工程师寇豆码）**
- 理由：发现的 5 处缺陷（BUG-IPP / BUG-DEP / BUG-EDGE-IMPORT / BUG-EDGE-API / BUG-EDGE-NORM）
  全部为**源码实现/依赖/API 误用**问题，测试代码本身正确，无测试侧 Bug 需自修。
- 修复后预期：本套测试应全部通过（IPP 标签类测试将由失败转为通过；透视/拼版/错误码/探活/URI 测试本应直接通过）。
- 因本机无 SDK，未执行真实"第 2 轮回归"——工程师合入修复后，依赖 `flutter test` 即可完成第 2 轮验证。
