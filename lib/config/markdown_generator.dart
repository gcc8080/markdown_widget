import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as m;

import '../widget/blocks/leaf/heading.dart';
import '../widget/widget_visitor.dart';
import 'configs.dart';
import 'toc.dart';

///use [MarkdownGenerator] to transform markdown data to [Widget] list, so you can render it by any type of [ListView]
class MarkdownGenerator {
  final MarkdownConfig config;
  final Iterable<m.InlineSyntax> inlineSyntaxes;
  final Iterable<m.BlockSyntax> blockSyntaxes;
  final EdgeInsets linesMargin;
  final List<SpanNodeGeneratorWithTag> generators;
  final SpanNodeAcceptCallback? onNodeAccepted;
  final TextNodeGenerator? textGenerator;
  final MarkdownBlockSelectionController? selectionController;
  final ValueChanged<MarkdownBlockMeta>? onBlockLongPress;

  MarkdownGenerator({
    MarkdownConfig? config,
    this.inlineSyntaxes = const [],
    this.blockSyntaxes = const [],
    this.linesMargin = const EdgeInsets.symmetric(vertical: 8),
    this.generators = const [],
    this.onNodeAccepted,
    this.textGenerator,
    this.selectionController,
    this.onBlockLongPress,
  }) : this.config = config ?? MarkdownConfig.defaultConfig;

  ///convert [data] to widgets
  ///[onTocList] can provider [Toc] list
  List<Widget> buildWidgets(String data,
      {ValueCallback<List<Toc>>? onTocList,
      ValueCallback<List<MarkdownBlockMeta>>? onBlockMetaList}) {
    final result = build(data, onTocList: onTocList);
    onBlockMetaList?.call(result.blockMetas);
    return result.widgets;
  }

  MarkdownBuildResult build(String data, {ValueCallback<List<Toc>>? onTocList}) {
    final m.Document document = m.Document(
      extensionSet: m.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      inlineSyntaxes: inlineSyntaxes,
      blockSyntaxes: blockSyntaxes,
    );
    final List<String> lines = data.split(RegExp(r'(\r?\n)|(\r?\t)|(\r)'));
    final List<m.Node> nodes = document.parseLines(lines);
    final List<Toc> tocList = [];
    final List<MarkdownBlockMeta> blockMetas = [];
    final List<_PendingBlockMeta> pendingBlockMetas = [];
    var textSearchOffset = 0;
    final visitor = WidgetVisitor(
        config: config,
        generators: generators,
        textGenerator: textGenerator,
        onElementVisitBefore: (element, nodeIndex, _) {
          final blockType = _tagToBlockType(element.tag);
          if (blockType == null) {
            return;
          }
          pendingBlockMetas.add(_PendingBlockMeta(
              blockType: blockType, widgetIndex: nodeIndex, tag: element.tag));
        },
        onElementVisitAfter: (element, _, __) {
          final blockType = _tagToBlockType(element.tag);
          if (blockType == null) {
            return;
          }
          for (var i = pendingBlockMetas.length - 1; i >= 0; i--) {
            final pending = pendingBlockMetas[i];
            if (pending.tag != element.tag) {
              continue;
            }
            pendingBlockMetas.removeAt(i);
            final plainText = element.textContent.trim();
            final charRange = _resolveCharRange(
                source: data, plainText: plainText, searchOffset: textSearchOffset);
            if (charRange != null) {
              textSearchOffset = charRange.end;
            }
            blockMetas.add(MarkdownBlockMeta(
                blockType: pending.blockType,
                plainText: plainText,
                blockIndex: blockMetas.length,
                widgetIndex: pending.widgetIndex,
                charRange: charRange));
            return;
          }
        },
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
    for (var index = 0; index < spans.length; index++) {
      final span = spans[index];
      InlineSpan inlineSpan = span.build();
      if (inlineSpan is TextSpan) {
        ///fix: line breaks are not effective when copying.
        ///see [https://github.com/asjqkkkk/markdown_widget/issues/105]
        ///see [https://github.com/asjqkkkk/markdown_widget/issues/95]
        inlineSpan.children?.add(TextSpan(text: '\r'));
      }
      final widget = Padding(
        padding: linesMargin,
        child: Text.rich(inlineSpan),
      );
      final blockMetaForCurrentWidget = blockMetas
          .where((meta) => meta.widgetIndex == index)
          .toList(growable: false);
      widgets.add(_wrapByBlockGesture(widget, blockMetaForCurrentWidget));
    }
    return MarkdownBuildResult(widgets: widgets, blockMetas: blockMetas);
  }

  Widget _wrapByBlockGesture(Widget child, List<MarkdownBlockMeta> blockMetas) {
    if (blockMetas.isEmpty) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        final blockMeta = blockMetas.first;
        selectionController?.selectBlock(blockMeta);
        onBlockLongPress?.call(blockMeta);
      },
      child: child,
    );
  }
}

///use [MarkdownGeneratorConfig] for [MarkdownGenerator]
class MarkdownGeneratorConfig {
  final Iterable<m.InlineSyntax> inlineSyntaxList;
  final Iterable<m.BlockSyntax> blockSyntaxList;
  final EdgeInsets linesMargin;
  final List<SpanNodeGeneratorWithTag> generators;
  final SpanNodeAcceptCallback? onNodeAccepted;
  final TextNodeGenerator? textGenerator;
  final MarkdownBlockSelectionController? selectionController;
  final ValueChanged<MarkdownBlockMeta>? onBlockLongPress;

  MarkdownGeneratorConfig({
    this.inlineSyntaxList = const [],
    this.blockSyntaxList = const [],
    this.linesMargin = const EdgeInsets.all(4),
    this.generators = const [],
    this.onNodeAccepted,
    this.textGenerator,
    this.selectionController,
    this.onBlockLongPress,
  });
}

MarkdownBlockType? _tagToBlockType(String tag) {
  switch (tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      return MarkdownBlockType.heading;
    case 'p':
      return MarkdownBlockType.paragraph;
    case 'li':
      return MarkdownBlockType.listItem;
    case 'blockquote':
      return MarkdownBlockType.blockquote;
    case 'pre':
      return MarkdownBlockType.codeBlock;
    case 'tr':
      return MarkdownBlockType.tableRow;
    default:
      return null;
  }
}

TextRange? _resolveCharRange(
    {required String source,
    required String plainText,
    required int searchOffset}) {
  if (plainText.isEmpty) {
    return null;
  }
  final start = source.indexOf(plainText, searchOffset);
  if (start < 0) {
    return null;
  }
  return TextRange(start: start, end: start + plainText.length);
}

class MarkdownBuildResult {
  final List<Widget> widgets;
  final List<MarkdownBlockMeta> blockMetas;

  const MarkdownBuildResult({required this.widgets, required this.blockMetas});
}

class MarkdownBlockMeta {
  final MarkdownBlockType blockType;
  final String plainText;
  final int blockIndex;
  final int widgetIndex;
  final TextRange? charRange;

  const MarkdownBlockMeta(
      {required this.blockType,
      required this.plainText,
      required this.blockIndex,
      required this.widgetIndex,
      this.charRange});
}

enum MarkdownBlockType { heading, paragraph, listItem, blockquote, codeBlock, tableRow }

class MarkdownBlockSelectionController extends ChangeNotifier {
  MarkdownBlockMeta? _currentBlock;

  MarkdownBlockMeta? get currentBlock => _currentBlock;

  void selectBlock(MarkdownBlockMeta blockMeta) {
    _currentBlock = blockMeta;
    notifyListeners();
  }
}

String extractPlainTextForBlock(MarkdownBlockMeta blockMeta) =>
    blockMeta.plainText;

class _PendingBlockMeta {
  final MarkdownBlockType blockType;
  final int widgetIndex;
  final String tag;

  _PendingBlockMeta(
      {required this.blockType, required this.widgetIndex, required this.tag});
}
