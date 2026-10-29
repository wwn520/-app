import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:printer_app/core/constants.dart';
import 'package:printer_app/ipp_client/ipp_attributes.dart';
import 'package:printer_app/ipp_client/ipp_message.dart';
import 'package:printer_app/models/app_error.dart';
import 'package:printer_app/models/printer.dart';
import 'package:printer_app/models/print_settings.dart';
import 'package:printer_app/utils/uri_helper.dart';

/// 轻量 IPP 客户端（Dart 自实现，不依赖原生库）。
///
/// 传输：HTTP/1.1 POST，`Content-Type: application/ipp`，
/// 请求体 = 二进制 IPP 报文 + PDF 文档字节。
/// 操作：Print-Job / Get-Printer-Attributes（探活）。
class IppClient {
  final http.Client _http = http.Client();
  final IppMessage _message = IppMessage();

  /// 提交打印作业（Print-Job）。[pdf] 为已生成的 A4 PDF 字节。
  Future<IppResponse> sendPrintJob(
      Printer printer, Uint8List pdf, PrintSettings settings) async {
    final groups = IppAttributes.printJob(printer, settings);
    final ippBytes = _message.encode(
        Constants.operationPrintJob, groups, pdf);
    return _send(printer, ippBytes,
        timeoutSeconds: Constants.printJobTimeoutSeconds);
  }

  /// 获取打印机属性（探活用）。
  Future<IppResponse> getPrinterAttributes(Printer printer) async {
    final groups = IppAttributes.getPrinterAttributes(printer);
    final ippBytes =
        _message.encode(Constants.operationGetPrinterAttributes, groups);
    return _send(printer, ippBytes,
        timeoutSeconds: Constants.livenessTimeoutSeconds);
  }

  /// 探活：成功返回 true，超时/异常返回 false。
  Future<bool> probeAlive(Printer printer) async {
    try {
      final resp = await getPrinterAttributes(printer);
      return resp.isSuccessful;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 底层发送：HTTP POST application/ipp。
  Future<IppResponse> _send(Printer printer, Uint8List ippBytes,
      {int timeoutSeconds = Constants.requestTimeoutSeconds}) async {
    final endpoint = UriHelper.toHttpEndpoint(printer.ippUri);
    try {
      final resp = await _http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/ipp',
              'Accept': 'application/ipp',
            },
            body: ippBytes,
          )
          .timeout(Duration(seconds: timeoutSeconds));
      return _message.decode(resp.bodyBytes);
    } on TimeoutException {
      throw AppError.fromCode(ErrorCode.networkTimeout,
          technical: 'IPP 请求超时: $endpoint');
    } catch (e) {
      throw AppError.fromCode(ErrorCode.ippError, technical: e.toString());
    }
  }

  /// 释放底层 HTTP 客户端。
  void dispose() => _http.close();
}
