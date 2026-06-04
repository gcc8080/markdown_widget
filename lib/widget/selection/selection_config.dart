import 'package:flutter/material.dart';

/// The semantic Markdown unit that a custom selection gesture targets.
enum MarkdownSelectionTargetType {
  heading,
  paragraph,
  listItem,
  blockquote,
  codeBlock,
  tableCell,
  image,
  horizontalRule,
  checkbox,
  inline,
  unknown,
}

/// Metadata exposed to custom selection menus and internal selection handling.
class MarkdownSelectionTarget {
  final String id;
  final MarkdownSelectionTargetType type;
  final String tag;
  final String plainText;
  final List<String> parentTags;
  final bool canSelectText;
  final Map<String, Object?> metadata;

  const MarkdownSelectionTarget({
    required this.id,
    required this.type,
    required this.tag,
    required this.plainText,
    this.parentTags = const [],
    this.canSelectText = true,
    this.metadata = const {},
  });

  bool get hasText => plainText.trim().isNotEmpty;
}

/// A menu action that can be rendered by application-provided menu builders.
class MarkdownSelectionMenuAction {
  final String id;
  final String label;
  final Widget? icon;
  final void Function(MarkdownSelectionMenuContext context) onPressed;

  const MarkdownSelectionMenuAction({
    required this.id,
    required this.label,
    this.icon,
    required this.onPressed,
  });
}

/// Context passed to initial and selected-text menu builders.
class MarkdownSelectionMenuContext {
  final MarkdownSelectionTarget target;
  final Offset globalPosition;
  final Rect? selectedRect;
  final String selectedText;
  final bool hasSelection;
  final List<MarkdownSelectionMenuAction> builtInActions;
  final List<MarkdownSelectionMenuAction> applicationActions;
  final VoidCallback dismiss;
  final VoidCallback selectText;
  final VoidCallback copy;
  final VoidCallback clearSelection;

  const MarkdownSelectionMenuContext({
    required this.target,
    required this.globalPosition,
    required this.selectedRect,
    required this.selectedText,
    required this.hasSelection,
    required this.builtInActions,
    required this.applicationActions,
    required this.dismiss,
    required this.selectText,
    required this.copy,
    required this.clearSelection,
  });

  List<MarkdownSelectionMenuAction> get allActions => [
        ...builtInActions,
        ...applicationActions,
      ];
}

typedef MarkdownSelectionMenuBuilder = Widget Function(
  BuildContext context,
  MarkdownSelectionMenuContext menuContext,
);

/// Configuration that enables the opt-in custom selection mode.
class MarkdownSelectionConfig {
  final MarkdownSelectionMenuBuilder? initialMenuBuilder;
  final MarkdownSelectionMenuBuilder? selectedTextMenuBuilder;
  final List<MarkdownSelectionMenuAction> initialMenuActions;
  final List<MarkdownSelectionMenuAction> selectedTextMenuActions;
  final Color selectionColor;
  final Color handleColor;

  const MarkdownSelectionConfig({
    this.initialMenuBuilder,
    this.selectedTextMenuBuilder,
    this.initialMenuActions = const [],
    this.selectedTextMenuActions = const [],
    this.selectionColor = const Color(0x663399FF),
    this.handleColor = const Color(0xFF1E88E5),
  });
}

typedef MarkdownSelectionTargetBuilder = Widget Function(
  Widget child,
  MarkdownSelectionTarget target,
);
