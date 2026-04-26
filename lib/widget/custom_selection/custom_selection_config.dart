import 'package:flutter/material.dart';

/// Phase of the custom selection interaction.
///
/// [longPress] is the moment user just long-pressed but no text has been
/// selected yet. [selection] is after user tapped "Select Text" and a region
/// of the markdown is highlighted.
enum CustomSelectionPhase { longPress, selection }

/// Context passed to the menu callbacks.
class CustomSelectionContext {
  final CustomSelectionPhase phase;

  /// The text content of the markdown element that is (or will be) selected.
  final String? selectedText;

  /// Global position where the menu is anchored (the long-press position
  /// during [CustomSelectionPhase.longPress] or the top-center of the
  /// selection rect during [CustomSelectionPhase.selection]).
  final Offset anchorGlobalPosition;

  /// Call to dismiss the menu overlay.
  final VoidCallback dismiss;

  /// Call to programmatically clear current selection (no-op during
  /// long-press phase).
  final VoidCallback clearSelection;

  CustomSelectionContext({
    required this.phase,
    required this.selectedText,
    required this.anchorGlobalPosition,
    required this.dismiss,
    required this.clearSelection,
  });
}

/// Single menu item shown in the custom selection menu.
class CustomSelectionMenuItem {
  final String label;
  final IconData? icon;
  final void Function(CustomSelectionContext ctx) onTap;

  /// If true, the item is shown only during [CustomSelectionPhase.longPress].
  /// If false, only during [CustomSelectionPhase.selection]. If null, both.
  final bool? longPressOnly;

  const CustomSelectionMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.longPressOnly,
  });
}

/// Builds the menu floating widget. If null a default Material card is used.
typedef CustomSelectionMenuBuilder = Widget Function(
  BuildContext context,
  CustomSelectionPhase phase,
  List<CustomSelectionMenuItem> items,
  CustomSelectionContext ctx,
);

/// Top-level configuration for the custom selection mode of [MarkdownWidget].
class CustomSelectionConfig {
  /// Whether the custom selection mode is enabled. When false [MarkdownWidget]
  /// keeps its existing [SelectionArea]-based behavior.
  final bool enable;

  /// Extra menu items shown during the long-press phase, after the built-in
  /// "Select Text" item.
  final List<CustomSelectionMenuItem> longPressMenuItems;

  /// Extra menu items shown during the selection phase, after the built-in
  /// "Copy" item.
  final List<CustomSelectionMenuItem> selectionMenuItems;

  /// Optional custom builder that fully replaces the menu UI.
  final CustomSelectionMenuBuilder? menuBuilder;

  /// Label of the built-in "Select Text" menu item.
  final String selectTextLabel;

  /// Label of the built-in "Copy" menu item.
  final String copyLabel;

  /// Color used to paint the highlight overlay covering the current selection.
  final Color highlightColor;

  /// Vertical gap (logical pixels) between the menu and its anchor.
  final double menuGap;

  const CustomSelectionConfig({
    this.enable = true,
    this.longPressMenuItems = const [],
    this.selectionMenuItems = const [],
    this.menuBuilder,
    this.selectTextLabel = '选取文字',
    this.copyLabel = '复制',
    this.highlightColor = const Color(0x553B82F6),
    this.menuGap = 12,
  });
}
