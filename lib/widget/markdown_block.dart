import 'package:flutter/material.dart';

import '../config/configs.dart';
import '../config/markdown_generator.dart';
import 'markdown.dart';

///use [MarkdownBlock] to build markdown by [Column]
///it does not support scrolling by default, but it will adapt to the width automatically.
class MarkdownBlock extends StatelessWidget {
  ///the markdown data
  final String data;

  ///make text selectable
  final bool selectable;

  /// Selection menu behavior when [selectable] is true.
  ///
  /// Defaults to [MarkdownSelectionMode.defaultSystem], which keeps the same
  /// behavior as previous versions.
  final MarkdownSelectionMode selectionMode;

  /// Custom builder for the first-level selection menu when
  /// [selectionMode] is [MarkdownSelectionMode.custom].
  final SelectableRegionContextMenuBuilder? customSelectionMenuBuilder;

  /// Additional selection actions appended to the default menu when
  /// [selectionMode] is [MarkdownSelectionMode.custom] and
  /// [customSelectionMenuBuilder] is not provided.
  final List<ContextMenuButtonItem>? customSelectionActions;

  ///the configs of markdown
  final MarkdownConfig? config;

  ///config for [MarkdownGenerator]
  final MarkdownGeneratorConfig? markdownGeneratorConfig;

  const MarkdownBlock({
    Key? key,
    required this.data,
    this.selectable = true,
    this.selectionMode = MarkdownSelectionMode.defaultSystem,
    this.customSelectionMenuBuilder,
    this.customSelectionActions,
    this.config,
    this.markdownGeneratorConfig,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final generatorConfig =
        markdownGeneratorConfig ?? MarkdownGeneratorConfig();
    final markdownGenerator = MarkdownGenerator(
      config: config,
      inlineSyntaxes: generatorConfig.inlineSyntaxList,
      blockSyntaxes: generatorConfig.blockSyntaxList,
      linesMargin: generatorConfig.linesMargin,
      generators: generatorConfig.generators,
      onNodeAccepted: generatorConfig.onNodeAccepted,
      textGenerator: generatorConfig.textGenerator,
      selectionController: generatorConfig.selectionController,
      onBlockLongPress: generatorConfig.onBlockLongPress,
    );
    final widgets = markdownGenerator.buildWidgets(data);
    final column = Column(
      children: widgets,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
    if (!selectable) {
      return column;
    }
    if (selectionMode == MarkdownSelectionMode.defaultSystem) {
      return SelectionArea(child: column);
    }
    return SelectionArea(
      contextMenuBuilder: customSelectionMenuBuilder ??
          (context, selectableRegionState) {
            final menuItems = [
              ...selectableRegionState.contextMenuButtonItems,
              ...?customSelectionActions,
            ];
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: menuItems,
            );
          },
      child: column,
    );
  }
}
