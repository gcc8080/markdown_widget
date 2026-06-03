import 'package:flutter/material.dart';

/// Context information for a markdown element
class ElementContext {
  /// Element index in ListView
  final int index;

  /// Element type (heading, paragraph, codeBlock, etc.)
  final String elementType;

  /// Plain text content of the element
  final String plainText;

  /// Full markdown document content
  final String fullMarkdown;

  /// Current selection range
  final TextSelection? selection;

  /// Selected text (if any)
  final String? selectedText;

  const ElementContext({
    required this.index,
    required this.elementType,
    required this.plainText,
    required this.fullMarkdown,
    this.selection,
    this.selectedText,
  });

  /// Create a copy with updated fields
  ElementContext copyWith({
    int? index,
    String? elementType,
    String? plainText,
    String? fullMarkdown,
    TextSelection? selection,
    String? selectedText,
  }) {
    return ElementContext(
      index: index ?? this.index,
      elementType: elementType ?? this.elementType,
      plainText: plainText ?? this.plainText,
      fullMarkdown: fullMarkdown ?? this.fullMarkdown,
      selection: selection ?? this.selection,
      selectedText: selectedText ?? this.selectedText,
    );
  }
}
