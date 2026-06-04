import 'package:flutter/material.dart';
import '../../../config/custom_selection_config.dart';
import '../element_context.dart';

/// Builder for menu widgets
class MenuBuilder {
  /// Build menu based on context
  static Widget buildMenu({
    required BuildContext context,
    required CustomSelectionConfig config,
    required ElementContext elementContext,
    required bool isInitialMenu,
    VoidCallback? onSelectText,
    VoidCallback? onCopy,
    required VoidCallback onDismiss,
  }) {
    final items = isInitialMenu
        ? _buildInitialMenuItems(
            config: config,
            elementContext: elementContext,
            onSelectText: onSelectText,
            onCopy: onCopy,
            onDismiss: onDismiss,
          )
        : _buildCopyMenuItems(
            config: config,
            elementContext: elementContext,
            onCopy: onCopy,
            onDismiss: onDismiss,
          );

    return _buildMenuLayout(items, config.menuStyle);
  }

  /// Build initial menu items (long press menu)
  static List<Widget> _buildInitialMenuItems({
    required CustomSelectionConfig config,
    required ElementContext elementContext,
    VoidCallback? onSelectText,
    VoidCallback? onCopy,
    required VoidCallback onDismiss,
  }) {
    final items = <Widget>[];

    // Built-in items
    if (!config.hiddenBuiltInItems.contains(BuiltInMenuItem.selectText)) {
      items.add(_buildMenuItem(
        config: config,
        label: '选取文字',
        icon: Icons.text_fields,
        onTap: () {
          // Call onSelectText first; it removes the menu itself via _removeMenu.
          // Do NOT call onDismiss here — that would call _clearAll which resets
          // _menuIsActive/_inSelectionPhase before _handleSelectText can set them.
          onSelectText?.call();
        },
      ));
    }

    if (!config.hiddenBuiltInItems.contains(BuiltInMenuItem.copy)) {
      items.add(_buildMenuItem(
        config: config,
        label: '复制',
        icon: Icons.copy,
        onTap: () {
          onDismiss();
          onCopy?.call();
        },
      ));
    }

    if (!config.hiddenBuiltInItems.contains(BuiltInMenuItem.bookmark)) {
      items.add(_buildMenuItem(
        config: config,
        label: '收藏',
        icon: Icons.bookmark,
        onTap: onDismiss,
      ));
    }

    if (!config.hiddenBuiltInItems.contains(BuiltInMenuItem.share)) {
      items.add(_buildMenuItem(
        config: config,
        label: '分享',
        icon: Icons.share,
        onTap: onDismiss,
      ));
    }

    // Add custom items based on position
    if (config.extension != null) {
      final customItems = _buildCustomMenuItems(
        config: config,
        elementContext: elementContext,
        onDismiss: onDismiss,
      );

      switch (config.extension!.position) {
        case MenuInsertPosition.afterBuiltIn:
          items.addAll(customItems);
          break;
        case MenuInsertPosition.afterSelectText:
          if (items.isNotEmpty) {
            items.insertAll(1, customItems);
          } else {
            items.addAll(customItems);
          }
          break;
        case MenuInsertPosition.afterCopy:
          if (items.length >= 2) {
            items.insertAll(2, customItems);
          } else {
            items.addAll(customItems);
          }
          break;
        case MenuInsertPosition.replaceAll:
          items.clear();
          items.addAll(customItems);
          break;
      }
    }

    return items;
  }

  /// Build copy menu items (after selection)
  static List<Widget> _buildCopyMenuItems({
    required CustomSelectionConfig config,
    required ElementContext elementContext,
    VoidCallback? onCopy,
    required VoidCallback onDismiss,
  }) {
    final items = <Widget>[];

    if (!config.hiddenBuiltInItems.contains(BuiltInMenuItem.copy)) {
      items.add(_buildMenuItem(
        config: config,
        label: '复制',
        icon: Icons.copy,
        onTap: () {
          onDismiss();
          onCopy?.call();
        },
      ));
    }

    // Add custom items if configured
    if (config.extension != null) {
      items.addAll(_buildCustomMenuItems(
        config: config,
        elementContext: elementContext,
        onDismiss: onDismiss,
      ));
    }

    return items;
  }

  /// Build custom menu items with context injection
  static List<Widget> _buildCustomMenuItems({
    required CustomSelectionConfig config,
    required ElementContext elementContext,
    required VoidCallback onDismiss,
  }) {
    if (config.extension == null) return [];

    return config.extension!.items.map((customItem) {
      return _buildMenuItem(
        config: config,
        label: customItem.label,
        icon: customItem.icon,
        onTap: () {
          onDismiss();
          if (customItem.onContextTap != null) {
            customItem.onContextTap!(elementContext);
          } else if (customItem.onTap != null) {
            customItem.onTap!();
          }
        },
        textColor: customItem.textColor,
        iconColor: customItem.iconColor,
        backgroundColor: customItem.backgroundColor,
      );
    }).toList();
  }

  /// Build a single menu item
  static Widget _buildMenuItem({
    required CustomSelectionConfig config,
    required String label,
    IconData? icon,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: config.menuStyle.iconSize ?? 20,
                color: iconColor ?? config.menuStyle.iconColor ?? Colors.black54,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: (config.menuStyle.textStyle ?? const TextStyle(fontSize: 14))
                  .copyWith(
                color: textColor ??
                    config.menuStyle.textStyle?.color ??
                    Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build menu layout based on style
  static Widget _buildMenuLayout(List<Widget> items, CustomMenuStyle style) {
    switch (style.layout) {
      case MenuLayout.horizontal:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: _intersperse(
            items,
            SizedBox(width: style.itemSpacing ?? 8),
          ),
        );
      case MenuLayout.vertical:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _intersperse(
            items,
            SizedBox(height: style.itemSpacing ?? 8),
          ),
        );
      case MenuLayout.grid:
        // Simple 2-column grid
        return Wrap(
          spacing: style.itemSpacing ?? 8,
          runSpacing: style.itemSpacing ?? 8,
          children: items,
        );
    }
  }

  /// Intersperse separator between items
  static List<Widget> _intersperse(List<Widget> items, Widget separator) {
    if (items.isEmpty) return items;

    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(separator);
      }
    }
    return result;
  }
}
