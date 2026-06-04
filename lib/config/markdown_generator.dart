import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as m;

import '../widget/blocks/leaf/heading.dart';
import '../widget/custom_selection/custom_selectable_wrapper.dart';
import '../widget/custom_selection/element_context.dart';
import '../widget/custom_selection/element_type_detector.dart';
import '../widget/custom_selection/vendor/selectable_region_fork.dart';
import '../widget/span_node.dart';
import '../widget/widget_visitor.dart';
import 'configs.dart';
import 'custom_selection_config.dart';
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
  ///[customSelectionConfig] enables custom selection mode
  List<Widget> buildWidgets(String data,
      {ValueCallback<List<Toc>>? onTocList,
      MarkdownConfig? config,
      CustomSelectionConfig? customSelectionConfig,
      GlobalKey<MdSelectableRegionState>? regionKey,
      ValueNotifier<String>? selectedTextNotifier}) {
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
    final useCustomSelection = customSelectionConfig != null &&
        customSelectionConfig.enabled &&
        regionKey != null &&
        selectedTextNotifier != null;
    for (var i = 0; i < spans.length; i++) {
      final span = spans[i];
      final builtSpan = spanNodeBuilder?.call(span) ?? span.build();
      final richText = richTextBuilder?.call(builtSpan) ?? Text.rich(builtSpan);
      final paddedWidget = Padding(padding: linesMargin, child: richText);

      if (useCustomSelection) {
        final elementType = ElementTypeDetector.detectType(span);
        if (!ElementTypeDetector.isSelectable(elementType)) {
          widgets.add(paddedWidget);
          continue;
        }
        final plainText = ElementTypeDetector.extractPlainText(builtSpan);
        final elementContext = ElementContext(
          index: i,
          elementType: elementType,
          plainText: plainText,
          fullMarkdown: data,
        );
        widgets.add(Padding(
          padding: linesMargin,
          child: CustomSelectableWrapper(
            child: richText,
            elementContext: elementContext,
            config: customSelectionConfig,
            regionKey: regionKey,
            selectedTextNotifier: selectedTextNotifier,
          ),
        ));
      } else {
        widgets.add(paddedWidget);
      }
    }
    return widgets;
  }
}

typedef SpanNodeBuilder = TextSpan Function(SpanNode spanNode);

typedef RichTextBuilder = Widget Function(InlineSpan span);
