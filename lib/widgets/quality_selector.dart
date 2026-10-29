import 'package:flutter/material.dart';

import 'package:printer_app/models/print_settings.dart';

/// 打印质量档位选择（草稿 / 标准 / 高质量）。
///
/// 映射到 IPP 分辨率/质量（P1-5）。
class QualitySelector extends StatelessWidget {
  final PrintQuality value;
  final ValueChanged<PrintQuality> onChanged;

  const QualitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PrintQuality>(
      segments: const [
        ButtonSegment(
          value: PrintQuality.draft,
          label: Text('草稿'),
        ),
        ButtonSegment(
          value: PrintQuality.normal,
          label: Text('标准'),
        ),
        ButtonSegment(
          value: PrintQuality.high,
          label: Text('高质量'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
    );
  }
}
