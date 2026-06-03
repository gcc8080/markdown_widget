import 'package:flutter/material.dart';
import '../span_node.dart';

/// Utility to detect markdown element types and extract content
class ElementTypeDetector {
  /// Determine the element type string from a SpanNode
  static String detectType(SpanNode node) {
    final typeName = node.runtimeType.toString();

    // Map node class names to friendly element types
    if (typeName.contains('Heading')) return 'heading';
    if (typeName.contains('Paragraph')) return 'paragraph';
    if (typeName.contains('CodeBlock')) return 'codeBlock';
    if (typeName.contains('Blockquote')) return 'blockquote';
    if (typeName.contains('ListNode') || typeName.contains('UlOrOL')) {
      return 'list';
    }
    if (typeName.contains('Table')) return 'table';
    if (typeName.contains('Image')) return 'image';
    if (typeName.contains('Link')) return 'link';
    if (typeName.contains('Hr')) return 'horizontalRule';
    if (typeName.contains('Code')) return 'inlineCode';

    return 'unknown';
  }

  /// Extract plain text from an InlineSpan
  static String extractPlainText(InlineSpan span) {
    final buffer = StringBuffer();
    span.visitChildren((child) {
      if (child is TextSpan && child.text != null) {
        buffer.write(child.text);
      }
      return true;
    });
    return buffer.toString();
  }

  /// Check if an element type should be selectable
  static bool isSelectable(String elementType) {
    // Images and horizontal rules are not selectable
    if (elementType == 'image' || elementType == 'horizontalRule') {
      return false;
    }
    return true;
  }
}
