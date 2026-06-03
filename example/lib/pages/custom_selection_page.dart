import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../config/custom_selection_config.dart';

const _demoMarkdown = '''
# 自定义选择模式示例

## 基础用法

长按下方内容查看自定义菜单。

### 标题选择

长按这个标题，可以选取整个标题内容。

## 正文段落

这是一段普通的正文内容。长按可以触发自定义菜单，点击"选取文字"后会选中整个段落。支持拖动滑块调整选择范围。

## 列表示例

- 列表项一：长按只会选中这一项
- 列表项二：每个列表项独立选择
- 列表项三：不会误选整个列表

## 代码块示例

```dart
// 长按代码块选中全部代码
void main() {
  print('Hello, World!');
}
```

## 引用示例

> 这是一段引用内容。长按会选中整个引用块的全部文字。

## 表格示例

| 功能 | 说明 |
|------|------|
| 长按 | 弹出自定义菜单 |
| 选取文字 | 选中当前元素 |
| 复制 | 复制到剪贴板 |
''';

/// Example page demonstrating custom selection mode
class CustomSelectionPage extends StatefulWidget {
  const CustomSelectionPage({Key? key}) : super(key: key);

  @override
  State<CustomSelectionPage> createState() => _CustomSelectionPageState();
}

class _CustomSelectionPageState extends State<CustomSelectionPage> {
  bool _isDarkMode = false;
  MenuLayout _layout = MenuLayout.horizontal;
  String _lastAction = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义选择模式'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            tooltip: '切换主题',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Text('菜单布局：'),
                SegmentedButton<MenuLayout>(
                  segments: const [
                    ButtonSegment(value: MenuLayout.horizontal, label: Text('横向')),
                    ButtonSegment(value: MenuLayout.vertical, label: Text('纵向')),
                  ],
                  selected: {_layout},
                  onSelectionChanged: (v) =>
                      setState(() => _layout = v.first),
                ),
                const Spacer(),
                if (_lastAction.isNotEmpty)
                  Text(
                    _lastAction,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Markdown content
          Expanded(
            child: _buildMarkdownWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownWidget() {
    final config = _isDarkMode
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    return MarkdownWidget(
      data: _demoMarkdown,
      config: config,
      enableCustomSelection: true,
      customSelectionConfig: CustomSelectionConfig(
        enabled: true,
        menuStyle: _isDarkMode
            ? CustomMenuStyle.dark()
            : CustomMenuStyle.light(),
        animationConfig: const MenuAnimationConfig(
          type: MenuAnimationType.fadeScale,
          enterDuration: Duration(milliseconds: 200),
        ),
        extension: MenuExtension(
          items: [
            CustomMenuItem.withContext(
              label: '翻译',
              icon: Icons.translate,
              onContextTap: (ctx) {
                setState(() => _lastAction = '翻译: ${ctx.plainText.substring(0, ctx.plainText.length.clamp(0, 20))}...');
              },
            ),
          ],
        ),
      ),
    );
  }
}
