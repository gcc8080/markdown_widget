import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as m;

import '../widget/blocks/leaf/heading.dart';
import '../widget/selection/selection_config.dart';
import '../widget/span_node.dart';
import '../widget/widget_visitor.dart';
import 'configs.dart';
import 'toc.dart';

///use [MarkdownGenerator] to transform markdown data to [Widget] list, so you can render it by any type of [ListView]
class MarkdownGenerator {
  final Iterable<m.InlineSyntax> inlineSyntaxList;
  final Iterable<m.BlockSyntax> blockSyntaxList;
  final EdgeInsets linesMargin;
  final List<SpanNodeGeneratorWithTag> generators;
  final SpanNodeAcceptCallback? onNodeAccepted;
  final m.ExtensionSet? extensionSet;
  final TextNodeGenerator? textGenerator;
  final SpanNodeBuilder? spanNodeBuilder;
  final RichTextBuilder? richTextBuilder;

  MarkdownGenerator({
    this.inlineSyntaxList = const [],
    this.blockSyntaxList = const [],
    this.linesMargin = const EdgeInsets.symmetric(vertical: 8),
    this.generators = const [],
    this.onNodeAccepted,
    this.extensionSet,
    this.textGenerator,
    this.spanNodeBuilder,
    this.richTextBuilder,
  });

  ///convert [data] to widgets
  ///[onTocList] can provider [Toc] list
  List<Widget> buildWidgets(
    String data, {
    ValueCallback<List<Toc>>? onTocList,
    MarkdownConfig? config,
    MarkdownSelectionTargetBuilder? selectionTargetBuilder,
  }) {
    final mdConfig = config ?? MarkdownConfig.defaultConfig;
    final m.Document document = m.Document(
      extensionSet: extensionSet ?? m.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      inlineSyntaxes: inlineSyntaxList,
      blockSyntaxes: blockSyntaxList,
    );
    final List<String> lines = data.split(RegExp(r'(\r?\n)|(\r?\t)|(\r)'));
    final List<m.Node> nodes = document.parseLines(lines);
    final List<Toc> tocList = [];
    final visitor = WidgetVisitor(
        config: mdConfig,
        generators: generators,
        textGenerator: textGenerator,
        selectionTargetBuilder: selectionTargetBuilder,
        onNodeAccepted: (node, index) {
          onNodeAccepted?.call(node, index);
          if (node is HeadingNode) {
            final listLength = tocList.length;
            tocList.add(
                Toc(node: node, widgetIndex: index, selfIndex: listLength));
          }
        });
    final spans = visitor.visit(nodes);
    onTocList?.call(tocList);
    final List<Widget> widgets = [];
    spans.asMap().forEach((index, span) {
      final textSpan = spanNodeBuilder?.call(span) ?? span.build();
      final richText = _buildTopLevelWidget(
        textSpan,
        unwrapBlockWidgetSpan: selectionTargetBuilder != null,
      );
      Widget child = richText;
      if (selectionTargetBuilder != null) {
        final targetNode =
            span is ConcreteElementNode && span.children.length == 1
                ? span.children.first
                : span;
        if (_shouldWrapTopLevelSelectionTarget(targetNode)) {
          final target = MarkdownSelectionTarget(
            id: 'markdown-selection-block-$index',
            type: targetNode.selectionTargetType,
            tag: targetNode.markdownTag,
            plainText: targetNode.plainText,
            parentTags: targetNode.parentTags,
            canSelectText: targetNode.canSelectText,
          );
          child = selectionTargetBuilder(child, target);
        }
      }
      widgets.add(Padding(padding: linesMargin, child: child));
    });
    return widgets;
  }

  bool _shouldWrapTopLevelSelectionTarget(SpanNode targetNode) {
    if (targetNode is HeadingNode && targetNode.headingConfig.divider != null) {
      return false;
    }
    switch (targetNode.markdownTag) {
      case 'blockquote':
      case 'pre':
      case 'table':
      case 'ul':
      case 'ol':
        return false;
    }
    return true;
  }

  Widget _buildTopLevelWidget(
    InlineSpan textSpan, {
    required bool unwrapBlockWidgetSpan,
  }) {
    if (unwrapBlockWidgetSpan) {
      if (textSpan is WidgetSpan) return textSpan.child;
      if (textSpan is TextSpan &&
          (textSpan.text == null || textSpan.text!.isEmpty) &&
          textSpan.children?.length == 1) {
        final child = textSpan.children!.single;
        if (child is WidgetSpan) return child.child;
      }
    }
    return richTextBuilder?.call(textSpan) ?? Text.rich(textSpan);
  }
}

typedef SpanNodeBuilder = TextSpan Function(SpanNode spanNode);

typedef RichTextBuilder = Widget Function(InlineSpan span);
