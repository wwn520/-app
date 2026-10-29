import 'package:flutter/material.dart';

import 'package:printer_app/models/print_settings.dart';

/// 黑白 / 彩色切换控件。
///
/// 映射到 IPP `print-color-mode`：grayscale→monochrome，color→color。
class ColorModeSwitch extends StatelessWidget {
  final ColorMode value;
  final ValueChanged<ColorMode> onChanged;

  const ColorModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ColorMode>(
      segments: const [
        ButtonSegment(
          value: ColorMode.grayscale,
          label: Text('黑白'),
          icon: Icon(Icons.filter_b_and_w),
        ),
        ButtonSegment(
          value: ColorMode.color,
          label: Text('彩色'),
          icon: Icon(Icons.color_lens),
        ),
      ],
      selected: {value},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) onChanged(set.first);
      },
    );
  }
}
