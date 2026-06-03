import 'package:flutter/material.dart';
import '../../../config/custom_selection_config.dart';

/// Base menu item class
class MenuItem {
  /// Display label
  final String label;

  /// Icon
  final IconData? icon;

  /// Callback when item is tapped
  final VoidCallback? onTap;

  /// Whether the item is enabled
  final bool enabled;

  // Style overrides
  final Color? textColor;
  final Color? iconColor;
  final Color? backgroundColor;

  const MenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
    this.textColor,
    this.iconColor,
    this.backgroundColor,
  });

  /// Build the menu item widget
  Widget build(
    BuildContext context,
    CustomMenuStyle style, {
    VoidCallback? onPressed,
  }) {
    final effectiveOnTap = enabled ? (onPressed ?? onTap) : null;

    return InkWell(
      onTap: effectiveOnTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: style.iconSize ?? 20,
                color: enabled
                    ? (iconColor ?? style.iconColor ?? Colors.black54)
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: (style.textStyle ?? const TextStyle(fontSize: 14)).copyWith(
                color: enabled
                    ? (textColor ?? style.textStyle?.color ?? Colors.black87)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
