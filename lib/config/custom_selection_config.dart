import 'package:flutter/material.dart';
import '../widget/custom_selection/element_context.dart';

/// Configuration for custom selection mode
class CustomSelectionConfig {
  /// Whether custom selection mode is enabled
  final bool enabled;

  /// Menu style configuration
  final CustomMenuStyle menuStyle;

  /// Menu animation configuration
  final MenuAnimationConfig animationConfig;

  /// Menu extension configuration
  final MenuExtension? extension;

  /// Set of built-in menu items to hide
  final Set<BuiltInMenuItem> hiddenBuiltInItems;

  const CustomSelectionConfig({
    this.enabled = false,
    this.menuStyle = const CustomMenuStyle(),
    this.animationConfig = const MenuAnimationConfig(),
    this.extension,
    this.hiddenBuiltInItems = const {},
  });
}

/// Menu style configuration
class CustomMenuStyle {
  // Container styles
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final EdgeInsets? padding;

  // Text styles
  final TextStyle? textStyle;
  final Color? iconColor;
  final double? iconSize;

  // Layout styles
  final MenuLayout layout;
  final double? itemSpacing;
  final double? dividerThickness;
  final Color? dividerColor;

  const CustomMenuStyle({
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.border,
    this.padding,
    this.textStyle,
    this.iconColor,
    this.iconSize,
    this.layout = MenuLayout.horizontal,
    this.itemSpacing,
    this.dividerThickness,
    this.dividerColor,
  });

  /// Default light theme style
  factory CustomMenuStyle.light() {
    return CustomMenuStyle(
      backgroundColor: Colors.white,
      elevation: 8.0,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      textStyle: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
      iconColor: Colors.black54,
      iconSize: 20,
      layout: MenuLayout.horizontal,
      itemSpacing: 8,
    );
  }

  /// Default dark theme style
  factory CustomMenuStyle.dark() {
    return CustomMenuStyle(
      backgroundColor: const Color(0xFF2D2D2D),
      elevation: 8.0,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      textStyle: const TextStyle(
        fontSize: 14,
        color: Colors.white,
      ),
      iconColor: Colors.white70,
      iconSize: 20,
      layout: MenuLayout.horizontal,
      itemSpacing: 8,
    );
  }
}

/// Menu layout mode
enum MenuLayout {
  /// Horizontal layout (items in a row)
  horizontal,

  /// Vertical layout (items in a column)
  vertical,

  /// Grid layout
  grid,
}

/// Menu animation configuration
class MenuAnimationConfig {
  /// Enter animation duration
  final Duration enterDuration;

  /// Exit animation duration
  final Duration exitDuration;

  /// Enter animation curve
  final Curve enterCurve;

  /// Exit animation curve
  final Curve exitCurve;

  /// Animation type
  final MenuAnimationType type;

  const MenuAnimationConfig({
    this.enterDuration = const Duration(milliseconds: 200),
    this.exitDuration = const Duration(milliseconds: 150),
    this.enterCurve = Curves.easeOut,
    this.exitCurve = Curves.easeIn,
    this.type = MenuAnimationType.fadeScale,
  });
}

/// Menu animation type
enum MenuAnimationType {
  /// Fade in/out
  fade,

  /// Scale in/out
  scale,

  /// Fade + scale
  fadeScale,

  /// Slide from top
  slideFromTop,

  /// Slide from bottom
  slideFromBottom,

  /// Slide from left
  slideFromLeft,

  /// Slide from right
  slideFromRight,
}

/// Menu extension configuration
class MenuExtension {
  /// List of custom menu items
  final List<CustomMenuItem> items;

  /// Position to insert custom items
  final MenuInsertPosition position;

  const MenuExtension({
    required this.items,
    this.position = MenuInsertPosition.afterBuiltIn,
  });
}

/// Position to insert custom menu items
enum MenuInsertPosition {
  /// After all built-in items
  afterBuiltIn,

  /// After "Select Text" item
  afterSelectText,

  /// After "Copy" item
  afterCopy,

  /// Replace all built-in items
  replaceAll,
}

/// Built-in menu items
enum BuiltInMenuItem {
  /// Select text item
  selectText,

  /// Copy item
  copy,

  /// Bookmark item
  bookmark,

  /// Share item
  share,
}

/// Custom menu item with context support
class CustomMenuItem {
  /// Display label
  final String label;

  /// Icon
  final IconData? icon;

  /// Simple callback (no context)
  final VoidCallback? onTap;

  /// Context-aware callback
  final ElementContextAction? onContextTap;

  /// Whether the item is enabled
  final bool enabled;

  // Style overrides
  final Color? textColor;
  final Color? iconColor;
  final Color? backgroundColor;

  const CustomMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.onContextTap,
    this.enabled = true,
    this.textColor,
    this.iconColor,
    this.backgroundColor,
  });

  /// Create a custom menu item with context callback
  const CustomMenuItem.withContext({
    required this.label,
    this.icon,
    required ElementContextAction this.onContextTap,
    this.enabled = true,
    this.textColor,
    this.iconColor,
    this.backgroundColor,
  }) : onTap = null;
}

/// Callback that receives element context
typedef ElementContextAction = void Function(ElementContext context);
