import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';

class CustomSelectionPage extends StatefulWidget {
  final String assetsPath;

  const CustomSelectionPage({
    Key? key,
    required this.assetsPath,
  }) : super(key: key);

  @override
  State<CustomSelectionPage> createState() => _CustomSelectionPageState();
}

class _CustomSelectionPageState extends State<CustomSelectionPage> {
  final Map<String, Future<String>> _markdownFutures = {};

  Future<String> _loadMarkdown(String assetPath) {
    return _markdownFutures.putIfAbsent(
      assetPath,
      () => rootBundle.loadString(assetPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom selection')),
      body: FutureBuilder<String>(
        key: ValueKey(widget.assetsPath),
        future: _loadMarkdown(widget.assetsPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load ${widget.assetsPath}'),
            );
          }
          final markdown = snapshot.data;
          if (markdown == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownWidget(
              data: markdown,
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
          );
        },
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
