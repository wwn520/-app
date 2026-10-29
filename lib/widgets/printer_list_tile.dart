import 'package:flutter/material.dart';

import 'package:printer_app/app/theme.dart';
import 'package:printer_app/models/printer.dart';

/// 打印机列表行：设备名 / IP:port / 在线状态点。
class PrinterListTile extends StatelessWidget {
  final Printer printer;
  final bool selected;
  final VoidCallback? onTap;

  const PrinterListTile({
    super.key,
    required this.printer,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(printer.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(Icons.print, color: statusColor),
        ),
        title: Text(printer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${printer.host}:${printer.port}${printer.ippPath ?? ''}'),
            if (printer.model != null && printer.model!.isNotEmpty)
              Text(printer.model!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _statusText(printer.status),
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ],
        ),
        selected: selected,
        selectedTileColor: AppTheme.primaryLight.withOpacity(0.12),
        onTap: onTap,
      ),
    );
  }

  Color _statusColor(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.online:
        return AppTheme.success;
      case PrinterStatus.offline:
        return AppTheme.danger;
      case PrinterStatus.unknown:
        return AppTheme.muted;
    }
  }

  String _statusText(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.online:
        return '在线';
      case PrinterStatus.offline:
        return '离线';
      case PrinterStatus.unknown:
        return '未知';
    }
  }
}
