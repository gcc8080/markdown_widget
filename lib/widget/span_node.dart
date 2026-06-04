import 'package:flutter/material.dart';

import 'selection/selection_config.dart';

///the basic node
abstract class SpanNode {
  InlineSpan build();

  SpanNode? _parent;

  TextStyle? style;

  TextStyle? get parentStyle => _parent?.style;

  SpanNode? get parent => _parent;

  String get plainText => '';

  String get markdownTag => '';

  MarkdownSelectionTargetType get selectionTargetType =>
      MarkdownSelectionTargetType.unknown;

  bool get canSelectText => plainText.trim().isNotEmpty;

  List<String> get parentTags {
    final result = <String>[];
    SpanNode? current = parent;
    while (current != null) {
      final tag = current.markdownTag;
      if (tag.isNotEmpty) result.add(tag);
      current = current.parent;
    }
    return result;
  }

  ///use [_acceptParent] to accept a parent
  void _acceptParent(SpanNode node) {
    _parent = node;
    onAccepted(node);
  }

  ///when this node was accepted by it's parent, [onAccepted] will be triggered
  void onAccepted(SpanNode parent) {}
}

///this node will accept other SpanNode as children
abstract class ElementNode extends SpanNode {
  final List<SpanNode> children = [];

  ///use [accept] to add a child
  void accept(SpanNode? node) {
    if (node != null) children.add(node);
    node?._acceptParent(this);
  }

  @override
  InlineSpan build() => childrenSpan;

  TextSpan get childrenSpan => TextSpan(
      children:
          List.generate(children.length, (index) => children[index].build()));

  @override
  String get plainText => children.map((e) => e.plainText).join();
}

///the default concrete node for ElementNode
class ConcreteElementNode extends ElementNode {
  final String tag;
  final TextStyle style;

  ConcreteElementNode({this.tag = '', TextStyle? style})
      : this.style = style ?? const TextStyle();

  @override
  InlineSpan build() => childrenSpan;

  @override
  String get markdownTag => tag;
}

///text node only displays text
class TextNode extends SpanNode {
  final String text;
  final TextStyle style;

  TextNode({this.text = '', this.style = const TextStyle()});

  @override
  InlineSpan build() => TextSpan(text: text, style: style.merge(parentStyle));

  @override
  String get plainText => text;
}
