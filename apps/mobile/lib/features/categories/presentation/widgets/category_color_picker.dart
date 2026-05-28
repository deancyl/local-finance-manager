import 'package:flutter/material.dart';

/// Preset category colors
class CategoryColors {
  static const List<ColorSwatch<int>> presetColors = [
    MaterialColor(0xFFE53935, {
      100: Color(0xFFFFCDD2),
      500: Color(0xFFE53935),
      700: Color(0xFFD32F2F),
    }), // Red
    MaterialColor(0xFFE91E63, {
      100: Color(0xFFF8BBD9),
      500: Color(0xFFE91E63),
      700: Color(0xFFC2185B),
    }), // Pink
    MaterialColor(0xFF9C27B0, {
      100: Color(0xFFE1BEE7),
      500: Color(0xFF9C27B0),
      700: Color(0xFF7B1FA2),
    }), // Purple
    MaterialColor(0xFF673AB7, {
      100: Color(0xFFD1C4E9),
      500: Color(0xFF673AB7),
      700: Color(0xFF512DA8),
    }), // Deep Purple
    MaterialColor(0xFF3F51B5, {
      100: Color(0xFFC5CAE9),
      500: Color(0xFF3F51B5),
      700: Color(0xFF303F9F),
    }), // Indigo
    MaterialColor(0xFF2196F3, {
      100: Color(0xFFBBDEFB),
      500: Color(0xFF2196F3),
      700: Color(0xFF1976D2),
    }), // Blue
    MaterialColor(0xFF03A9F4, {
      100: Color(0xFFB3E5FC),
      500: Color(0xFF03A9F4),
      700: Color(0xFF0288D1),
    }), // Light Blue
    MaterialColor(0xFF00BCD4, {
      100: Color(0xFFB2EBF2),
      500: Color(0xFF00BCD4),
      700: Color(0xFF0097A7),
    }), // Cyan
    MaterialColor(0xFF009688, {
      100: Color(0xFFB2DFDB),
      500: Color(0xFF009688),
      700: Color(0xFF00796B),
    }), // Teal
    MaterialColor(0xFF4CAF50, {
      100: Color(0xFFC8E6C9),
      500: Color(0xFF4CAF50),
      700: Color(0xFF388E3C),
    }), // Green
    MaterialColor(0xFF8BC34A, {
      100: Color(0xFFDCEDC8),
      500: Color(0xFF8BC34A),
      700: Color(0xFF689F38),
    }), // Light Green
    MaterialColor(0xFFCDDC39, {
      100: Color(0xFFF0F4C3),
      500: Color(0xFFCDDC39),
      700: Color(0xFFAFB42B),
    }), // Lime
    MaterialColor(0xFFFFEB3B, {
      100: Color(0xFFFFF9C4),
      500: Color(0xFFFFEB3B),
      700: Color(0xFFFBC02D),
    }), // Yellow
    MaterialColor(0xFFFFC107, {
      100: Color(0xFFFFECB3),
      500: Color(0xFFFFC107),
      700: Color(0xFFFFA000),
    }), // Amber
    MaterialColor(0xFFFF9800, {
      100: Color(0xFFFFE0B2),
      500: Color(0xFFFF9800),
      700: Color(0xFFF57C00),
    }), // Orange
    MaterialColor(0xFFFF5722, {
      100: Color(0xFFFFCCBC),
      500: Color(0xFFFF5722),
      700: Color(0xFFE64A19),
    }), // Deep Orange
    MaterialColor(0xFF795548, {
      100: Color(0xFFD7CCC8),
      500: Color(0xFF795548),
      700: Color(0xFF5D4037),
    }), // Brown
    MaterialColor(0xFF9E9E9E, {
      100: Color(0xFFE0E0E0),
      500: Color(0xFF9E9E9E),
      700: Color(0xFF757575),
    }), // Grey
    MaterialColor(0xFF607D8B, {
      100: Color(0xFFCFD8DC),
      500: Color(0xFF607D8B),
      700: Color(0xFF455A64),
    }), // Blue Grey
  ];

  /// Convert color to hex string for storage
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Convert hex string to Color
  static Color hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return const Color(0xFF2196F3); // Default blue
    }
    try {
      final hexColor = hex.replaceFirst('#', '');
      final colorValue = int.tryParse('0xFF$hexColor');
        return colorValue != null ? Color(colorValue) : const Color(0xFF2196F3);
    } catch (e) {
      return const Color(0xFF2196F3);
    }
  }
}

/// Category color picker widget
class CategoryColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;

  const CategoryColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选择颜色',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: CategoryColors.presetColors.length,
          itemBuilder: (context, index) {
            final color = CategoryColors.presetColors[index];
            final colorHex = CategoryColors.colorToHex(color);
            final isSelected = selectedColor == colorHex;
            
            return InkWell(
              onTap: () => onColorSelected(colorHex),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 3,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
