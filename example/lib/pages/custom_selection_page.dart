import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

const _sampleMarkdown = '''
# 自定义选择模式 Demo

## 这是一个二级标题

这是一个普通的段落，里面有一些 **加粗文字** 和一个 [链接](https://flutter.dev) 以及 `行内代码`。
长按段落任意位置，可以看到自定义的功能菜单浮窗，而不是 Flutter 默认的选择菜单。

> 这是一段引用块。
> 它包含多行内容，长按引用区域并选择"选取文字"将选中整段引用。

- 列表项 A：苹果
- 列表项 B：香蕉，长按这一项试试
- 列表项 C：橘子

```dart
void main() {
  print('Hello, custom selection mode!');
  for (var i = 0; i < 3; i++) {
    print('i = \$i');
  }
}
```

正文末尾再来一段普通文字，验证段落级选择行为。
''';

class CustomSelectionPage extends StatelessWidget {
  const CustomSelectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = CustomSelectionConfig(
      enable: true,
      longPressMenuItems: [
        CustomSelectionMenuItem(
          label: '高亮',
          icon: Icons.brush,
          onTap: (ctx) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('点击了"高亮"（自定义扩展项）')),
            );
            ctx.dismiss();
          },
        ),
      ],
      selectionMenuItems: [
        CustomSelectionMenuItem(
          label: '分享',
          icon: Icons.share,
          onTap: (ctx) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已分享：${ctx.selectedText}')),
            );
            ctx.dismiss();
          },
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Selection Mode')),
      body: MarkdownWidget(
        data: _sampleMarkdown,
        customSelectionConfig: config,
      ),
    );
  }
}
