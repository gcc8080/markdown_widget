import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class CustomSelectionPage extends StatefulWidget {
  const CustomSelectionPage({Key? key}) : super(key: key);

  @override
  State<CustomSelectionPage> createState() => _CustomSelectionPageState();
}

class _CustomSelectionPageState extends State<CustomSelectionPage> {
  bool _customMode = false;
  String _selectedText = '';

  static const String _demoMarkdown = '''
# 自定义选区模式演示

这是一段用于验证选区行为的正文。你可以分别点击标题、段落、列表、引用与代码块，确认默认选区是否正确。

## 列表

- 第一项：支持普通文本选择
- 第二项：支持 **加粗** 与 `inline code`
- 第三项：[支持链接文本选择](https://pub.dev/packages/markdown_widget)

> 这是引用块。请长按或拖拽选择其中任意一部分文字。

```dart
void main() {
  final message = 'Hello markdown_widget';
  print(message);
}
```
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Selection Demo'),
      ),
      body: Column(
        children: [
          _buildModeSwitcher(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Text(
              _customMode
                  ? '当前模式：自定义模式（包含扩展菜单项“统计字数” + 自定义样式浮窗）'
                  : '当前模式：默认模式（对照组）',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _customMode ? _buildCustomMode() : _buildDefaultMode(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('默认模式'),
            selected: !_customMode,
            onSelected: (_) => setState(() => _customMode = false),
          ),
          ChoiceChip(
            label: const Text('自定义模式'),
            selected: _customMode,
            onSelected: (_) => setState(() => _customMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultMode() {
    return MarkdownWidget(
      data: _demoMarkdown,
      padding: const EdgeInsets.all(12),
    );
  }

  Widget _buildCustomMode() {
    return SelectionArea(
      onSelectionChanged: (selectedContent) {
        _selectedText = selectedContent?.plainText ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final buttonItems = <ContextMenuButtonItem>[
          ...selectableRegionState.contextMenuButtonItems,
          ContextMenuButtonItem(
            label: '统计字数',
            onPressed: () {
              ContextMenuController.removeAny();
              _showSelectionStatsDialog();
            },
          ),
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      child: MarkdownWidget(
        data: _demoMarkdown,
        selectable: false,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  void _showSelectionStatsDialog() {
    final selected = _selectedText.trim();
    final int length = selected.runes.length;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final color = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.primaryContainer, color.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.primary, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  color: Colors.black26,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选区统计',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('字符数：$length'),
                const SizedBox(height: 8),
                Text(
                  selected.isEmpty ? '请先选择文本后再点击“统计字数”。' : selected,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
