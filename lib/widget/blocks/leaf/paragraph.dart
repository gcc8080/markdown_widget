import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../config/configs.dart';
import '../../selection/selection_config.dart';
import '../../span_node.dart';

///Tag: [MarkdownTag.p]
///
///A sequence of non-blank lines that cannot be interpreted as other kinds of blocks forms a paragraph
class ParagraphNode extends ElementNode {
  final PConfig pConfig;

  ParagraphNode(this.pConfig);

  @override
  InlineSpan build() {
    return TextSpan(
        children: List.generate(children.length, (index) {
      final child = children[index];
      return child.build();
    }));
  }

  @override
  TextStyle? get style => pConfig.textStyle.merge(parentStyle);

  @override
  String get markdownTag => MarkdownTag.p.name;

  @override
  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.paragraph;
}

///config class for paragraphs, tag: p
class PConfig implements LeafConfig {
  final TextStyle textStyle;

  const PConfig({this.textStyle = const TextStyle(fontSize: 16)});

  static PConfig get darkConfig =>
      PConfig(textStyle: const TextStyle(fontSize: 16));

  @nonVirtual
  @override
  String get tag => MarkdownTag.p.name;
}

///Tag: [MarkdownTag.del]
///
///double '~'swill be wrapped with an HTML <del> tag.
class DelNode extends ElementNode {
  @override
  String get markdownTag => MarkdownTag.del.name;

  @override
  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.inline;

  @override
  TextStyle get style =>
      parentStyle?.merge(_defaultDelStyle) ?? _defaultDelStyle;
}

///Tag: [MarkdownTag.strong]
///
/// double '*'s or '_'s will be wrapped with an HTML <strong> tag.
class StrongNode extends ElementNode {
  @override
  String get markdownTag => MarkdownTag.strong.name;

  @override
  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.inline;

  @override
  TextStyle get style =>
      parentStyle?.merge(_defaultStrongStyle) ?? _defaultStrongStyle;
}

///Tag: [MarkdownTag.em]
///
/// emphasis, Markdown treats asterisks (*) and underscores (_) as indicators of emphasis
class EmNode extends ElementNode {
  @override
  String get markdownTag => MarkdownTag.em.name;

  @override
  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.inline;

  @override
  TextStyle get style => parentStyle?.merge(_defaultEmStyle) ?? _defaultEmStyle;
}

///Tag: [MarkdownTag.br]
///
///  a hard line break
class BrNode extends SpanNode {
  @override
  InlineSpan build() {
    return TextSpan(text: '\n', style: parentStyle);
  }

  @override
  String get plainText => '\n';

  @override
  String get markdownTag => MarkdownTag.br.name;
}

///see [DelNode]
const _defaultDelStyle = TextStyle(decoration: TextDecoration.lineThrough);

///see [StrongNode]
const _defaultStrongStyle = TextStyle(fontWeight: FontWeight.bold);

///see [EmNode]
const _defaultEmStyle = TextStyle(fontStyle: FontStyle.italic);
