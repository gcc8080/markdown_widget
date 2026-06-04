import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class CustomSelectionPage extends StatelessWidget {
  const CustomSelectionPage({Key? key}) : super(key: key);

  static const _markdown = '''
# Custom selection mode

Long press this paragraph. The first menu appears before text is selected.
Tap **Select text** to select the complete paragraph and show draggable handles.

> A block quote can contain multiple paragraphs.
>
> Long pressing either paragraph selects the nearest quote block.

- The first list item is independent.
- The second list item has direct text.
  - Nested child text is not part of the initial list-item selection.

| Element | Initial selection |
| --- | --- |
| Table cell | Current cell |
| Code block | Entire code block |

```dart
void main() {
  print('code keeps line breaks');
}
```

![Example image](assets/script_medias/1676100926803.png)

---
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom selection')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownWidget(
          data: _markdown,
          selectionConfig: MarkdownSelectionConfig(
            initialMenuActions: [
              MarkdownSelectionMenuAction(
                id: 'example.favorite',
                label: 'Favorite',
                icon: const Icon(Icons.star_border, size: 18),
                onPressed: (menuContext) {
                  menuContext.dismiss();
                  _showSnack(
                    context,
                    'Favorite: ${menuContext.target.tag}',
                  );
                },
              ),
            ],
            selectedTextMenuActions: [
              MarkdownSelectionMenuAction(
                id: 'example.explain',
                label: 'Explain',
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                onPressed: (menuContext) {
                  _showSnack(
                    context,
                    'Explain ${menuContext.selectedText.length} chars',
                  );
                },
              ),
            ],
            initialMenuBuilder: _buildInitialMenu,
            selectedTextMenuBuilder: _buildSelectedTextMenu,
          ),
        ),
      ),
    );
  }

  static Widget _buildInitialMenu(
    BuildContext context,
    MarkdownSelectionMenuContext menuContext,
  ) {
    final actions = [
      ...menuContext.applicationActions,
      ...menuContext.builtInActions,
    ];
    return _ExampleMenu(actions: actions, menuContext: menuContext);
  }

  static Widget _buildSelectedTextMenu(
    BuildContext context,
    MarkdownSelectionMenuContext menuContext,
  ) {
    return _ExampleMenu(
      actions: menuContext.allActions,
      menuContext: menuContext,
    );
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ExampleMenu extends StatelessWidget {
  final List<MarkdownSelectionMenuAction> actions;
  final MarkdownSelectionMenuContext menuContext;

  const _ExampleMenu({
    Key? key,
    required this.actions,
    required this.menuContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions
              .map(
                (action) => TextButton.icon(
                  onPressed: () => action.onPressed(menuContext),
                  icon: action.icon ?? const SizedBox.shrink(),
                  label: Text(action.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
