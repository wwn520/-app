import 'dart:convert';

/// 打印机在线状态。
enum PrinterStatus {
  online, // 在线
  offline, // 离线
  unknown, // 未知（刚发现尚未探活）
}

/// 局域网发现的网络打印机。
///
/// 字段契约（共享知识 §7）：
/// - [id] = nsd 服务名（去重主键）
/// - [host] = IP
/// - [port] = 631
/// - [ippPath] 优先取 TXT `rp`，失败回退 `/ipp/print`
/// - [status] 由发现 + 探活共同决定
class Printer {
  final String id; // nsd 服务名（去重主键）
  final String name; // 展示名（ty / 设备名）
  final String host; // IP
  final int port; // 631
  final String? ippPath; // 如 /ipp/print
  final String? model; // TXT.ty
  final PrinterStatus status;
  final DateTime lastSeen;

  const Printer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.ippPath,
    this.model,
    this.status = PrinterStatus.unknown,
    required this.lastSeen,
  });

  /// IPP 打印机 URI（scheme=ipp, host, port, path）。
  Uri get ippUri => Uri(
        scheme: 'ipp',
        host: host,
        port: port,
        path: ippPath ?? '/ipp/print',
      );

  /// 不可变拷贝（更新状态/路径时）。
  Printer copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? ippPath,
    String? model,
    PrinterStatus? status,
    DateTime? lastSeen,
  }) {
    return Printer(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      ippPath: ippPath ?? this.ippPath,
      model: model ?? this.model,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// 序列化（用于 shared_preferences 持久化常用打印机）。
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'ippPath': ippPath,
        'model': model,
        'status': status.name,
        'lastSeen': lastSeen.toIso8601String(),
      };

  /// 反序列化。
  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      ippPath: json['ippPath'] as String?,
      model: json['model'] as String?,
      status: PrinterStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => PrinterStatus.unknown,
      ),
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'Printer($name @ $host:$port${ippPath ?? ''} -> ${status.name})';
}
