import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// 自定义选择模式示例
///
/// 本示例演示如何在 MarkdownWidget 中启用自定义选择模式，
/// 包括自定义 Context Menu 样式和扩展菜单项。
///
/// 运行方式：在 example 目录下执行 `flutter run`，
/// 或将此页面集成到 example app 的路由中。
class CustomSelectionExample extends StatelessWidget {
  const CustomSelectionExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Selection Mode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildMarkdownContent(),
      ),
    );
  }

  Widget _buildMarkdownContent() {
    // 示例 Markdown 内容，包含标题、段落、代码块和列表
    const markdownData = '''
# Custom Selection Mode Demo

This is a paragraph demonstrating the custom selection mode feature. Long press on any text element to see the custom context menu.

## Features

- Element-level text selection
- Custom context menu styling
- Draggable selection handles
- Cross-element continuous selection

## Code Example

```dart
final widget = MarkdownWidget(
  data: markdownContent,
  customSelectionMode: true,
);
```

> This is a blockquote. Long press here to select the entire quote block as a single unit.

### Summary

The custom selection mode provides a more flexible text selection experience compared to Flutter's default SelectionArea.
''';

    // Step 1: 通过设置 customSelectionMode: true 开启自定义选择模式。
    // 开启后，长按内容区域将弹出自定义功能菜单，而非 Flutter 原生的文本选择行为。
    return MarkdownWidget(
      data: markdownData,
      customSelectionMode: true,

      // Step 2: 使用 contextMenuBuilder 自定义 Context Menu 的外观样式。
      // 该回调接收菜单位置、菜单项列表、选中文本和关闭回调，返回完全自定义的菜单 Widget。
      contextMenuBuilder: (
        Offset position,
        List<SelectionMenuItem> menuItems,
        String? selectedText,
        VoidCallback closeMenu,
      ) {
        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          // 自定义菜单背景色为深蓝色
          color: const Color(0xFF1A237E),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: menuItems.map((item) {
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => item.onPressed(selectedText, closeMenu),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.icon != null)
                          Icon(item.icon, color: Colors.white, size: 18),
                        if (item.icon != null) const SizedBox(width: 6),
                        // 自定义菜单文字样式为白色、14号字体
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },

      // Step 3: 使用 contextMenuItems 追加自定义菜单项。
      // 自定义项会追加到默认菜单项（「选取文字」「复制」）之后。
      contextMenuItems: [
        SelectionMenuItem(
          title: '分享',
          icon: Icons.share,
          onPressed: (String? selectedText, VoidCallback closeMenu) {
            // 自定义「分享」菜单项的回调逻辑
            closeMenu();
            debugPrint('Share text: $selectedText');
          },
        ),
      ],
    );
  }
}

/// 独立运行入口（可选）
///
/// 如果需要独立运行此示例，取消注释以下 main 函数：
// void main() {
//   runApp(const MaterialApp(
//     home: CustomSelectionExample(),
//   ));
// }
