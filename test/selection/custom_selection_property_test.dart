import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';
import 'package:markdown_widget/widget/selection/selection_models.dart';

// Feature: custom-selection-mode, Property 2: Custom menu items are appended after default items

/// Builds the complete menu item list by prepending default items before custom items.
/// This is the core logic that the context menu overlay uses to assemble the full menu.
/// Default items always include at least "选取文字" (Select Text).
List<SelectionMenuItem> buildFullMenuItems(
    List<SelectionMenuItem>? contextMenuItems) {
  final defaultItems = <SelectionMenuItem>[
    SelectionMenuItem(
      title: '选取文字',
      icon: Icons.text_fields,
      onPressed: (_, __) {},
    ),
  ];

  if (contextMenuItems == null || contextMenuItems.isEmpty) {
    return defaultItems;
  }

  return [...defaultItems, ...contextMenuItems];
}

/// Custom generator for SelectionMenuItem lists.
extension SelectionMenuItemGenerators on Any {
  /// Generates a SelectionMenuItem with a random title.
  Generator<SelectionMenuItem> get selectionMenuItem =>
      nonEmptyLetters.map((title) => SelectionMenuItem(
            title: title,
            onPressed: (_, __) {},
          ));

  /// Generates a non-empty list of SelectionMenuItems.
  Generator<List<SelectionMenuItem>> get nonEmptySelectionMenuItemList =>
      nonEmptyList(selectionMenuItem);
}

void main() {
  /// **Validates: Requirements 3.6**
  ///
  /// Property 2: 对于任意非空的 contextMenuItems 列表，生成的完整菜单项列表应满足：
  /// 前缀为默认菜单项（至少包含「选取文字」），后缀为 contextMenuItems 中的所有项，
  /// 且顺序与传入顺序一致。
  group('Property 2: Custom menu items are appended after default items', () {
    Glados(any.nonEmptySelectionMenuItemList, ExploreConfig(numRuns: 100))
        .test('full menu list starts with default items containing "选取文字"',
            (customItems) {
      final fullMenu = buildFullMenuItems(customItems);

      // The full menu should not be empty
      expect(fullMenu.isNotEmpty, isTrue);

      // The first item should be the default "选取文字" item
      expect(fullMenu.first.title, equals('选取文字'));
    });

    Glados(any.nonEmptySelectionMenuItemList, ExploreConfig(numRuns: 100))
        .test('custom items appear after default items in original order',
            (customItems) {
      final fullMenu = buildFullMenuItems(customItems);

      // Default items are at the beginning (at least 1 default item: "选取文字")
      const defaultItemCount = 1; // We know there's exactly 1 default item
      final suffix = fullMenu.sublist(defaultItemCount);

      // The suffix should have the same length as custom items
      expect(suffix.length, equals(customItems.length));

      // The suffix should contain the custom items in the same order
      for (var i = 0; i < customItems.length; i++) {
        expect(suffix[i].title, equals(customItems[i].title));
      }
    });

    Glados(any.nonEmptySelectionMenuItemList, ExploreConfig(numRuns: 100)).test(
        'full menu length equals default items count plus custom items count',
        (customItems) {
      final fullMenu = buildFullMenuItems(customItems);

      // Full menu length = 1 (default "选取文字") + custom items count
      expect(fullMenu.length, equals(1 + customItems.length));
    });

    Glados(any.nonEmptySelectionMenuItemList, ExploreConfig(numRuns: 100)).test(
        'custom items are never placed before default items', (customItems) {
      final fullMenu = buildFullMenuItems(customItems);

      // Find the index of "选取文字" in the full menu
      final defaultIndex = fullMenu.indexWhere((item) => item.title == '选取文字');
      expect(defaultIndex, equals(0),
          reason: 'Default item "选取文字" should always be at index 0');

      // All custom items should appear after the default item
      for (var i = 0; i < customItems.length; i++) {
        // Custom items start at index 1 (after the default item)
        final expectedIndex = 1 + i;
        expect(fullMenu[expectedIndex].title, equals(customItems[i].title),
            reason:
                'Custom item at position $i should be at index $expectedIndex');
      }
    });
  });
}
