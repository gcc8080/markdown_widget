import 'package:flutter/material.dart';

import '../config/configs.dart';
import '../config/markdown_generator.dart';
import 'custom_selection/all.dart';

///use [MarkdownBlock] to build markdown by [Column]
///it does not support scrolling by default, but it will adapt to the width automatically.
class MarkdownBlock extends StatelessWidget {
  ///the markdown data
  final String data;

  ///make text selectable
  final bool selectable;

  ///the configs of markdown
  final MarkdownConfig? config;

  ///config for [MarkdownGenerator]
  final MarkdownGeneratorConfig? markdownGeneratorConfig;

  ///optional configuration of the custom selection mode.
  final CustomSelectionConfig? customSelectionConfig;

  const MarkdownBlock({
    Key? key,
    required this.data,
    this.selectable = true,
    this.config,
    this.markdownGeneratorConfig,
    this.customSelectionConfig,
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
    );
    final useCustom = customSelectionConfig?.enable == true;
    final results = markdownGenerator.buildWidgetsWithSpans(data);
    final children = <Widget>[];
    for (var i = 0; i < results.length; i++) {
      final br = results[i];
      Widget w = br.widget;
      if (useCustom) {
        w = SelectableMarkdownElement(
          index: i,
          rootSpan: br.rootSpan,
          paragraphKey: br.paragraphKey,
          child: w,
        );
      }
      children.add(w);
    }
    final column = Column(
      children: children,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
    if (useCustom) {
      return CustomSelectionScope(
        config: customSelectionConfig!,
        child: CustomSelectionController(
          config: customSelectionConfig!,
          child: column,
        ),
      );
    }
    return selectable ? SelectionArea(child: column) : column;
  }
}
