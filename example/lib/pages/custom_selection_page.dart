import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../state/root_state.dart';

class CustomSelectionPage extends StatelessWidget {
  const CustomSelectionPage({Key? key}) : super(key: key);

  static const _sample = '''
# 自定义选择模式示例

长按任意段落，会先弹出自定义菜单。

- 点击“选取文字”进入文本选择模式
- 点击“复制段落”直接复制当前块内容

> 支持复制、扩展业务菜单。

```dart
print('custom selection mode');
```
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: StoreConnector<RootState, ThemeState>(
          converter: ThemeState.storeConverter,
          builder: (context, snapshot) {
            final config =
                isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
            return MarkdownWidget(
              data: _sample,
              config: config,
              enableCustomSelection: true,
              customSelectionActions: [
                MarkdownCustomSelectionAction(
                  label: '复制段落',
                  onTap: (ctx, contextData) async {
                    await Clipboard.setData(
                        ClipboardData(text: contextData.blockText));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('已复制当前段落')),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
