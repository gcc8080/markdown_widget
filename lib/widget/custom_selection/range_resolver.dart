import 'package:flutter/material.dart';

import '../span_node.dart';

/// Result of resolving a hit position against a block's [SpanNode] tree.
class ResolvedRange {
  /// Start offset in the block plain text (inclusive).
  final int start;

  /// End offset in the block plain text (exclusive).
  final int end;

  /// The plain text within [start, end).
  final String text;

  const ResolvedRange({
    required this.start,
    required this.end,
    required this.text,
  });
}

/// Walk a [SpanNode] tree and build:
/// - the concatenated plain text;
/// - the [start, end) character range of every visited node.
class SpanNodeIndex {
  final Map<SpanNode, _Range> ranges = {};
  final StringBuffer buffer = StringBuffer();

  SpanNodeIndex._();

  static SpanNodeIndex build(SpanNode root) {
    final idx = SpanNodeIndex._();
    idx._visit(root);
    return idx;
  }

  void _visit(SpanNode node) {
    final start = buffer.length;
    if (node is TextNode) {
      buffer.write(node.text);
    } else if (node is ElementNode) {
      for (final child in node.children) {
        _visit(child);
      }
    } else {
      // Unknown leaf - try to render its inline span text content.
      final span = node.build();
      if (span is TextSpan) {
        final t = span.toPlainText();
        buffer.write(t);
      }
    }
    final end = buffer.length;
    ranges[node] = _Range(start, end);
  }

  String get text => buffer.toString();

  /// Find the deepest [TextNode] / [ElementNode] whose range contains
  /// [charOffset]. Returns the most specific inline node; if the deepest match
  /// is the root itself the whole block range is returned.
  ResolvedRange resolve(SpanNode root, int charOffset, {bool inlinePreferred = true}) {
    SpanNode? best;
    int bestLen = 1 << 30;
    ranges.forEach((node, r) {
      if (charOffset >= r.start && charOffset < r.end) {
        final len = r.end - r.start;
        if (len < bestLen) {
          bestLen = len;
          best = node;
        }
      }
    });
    SpanNode target = best ?? root;
    if (!inlinePreferred) target = root;
    // Skip degenerate single-char wrappers that are not real inline nodes.
    if (target is TextNode && target.parent != null && target.parent != root) {
      // Use the parent inline element so the user gets the styled token,
      // e.g. selecting a link includes its surrounding text styling node.
      final parent = target.parent!;
      final pr = ranges[parent];
      if (pr != null) {
        return ResolvedRange(
          start: pr.start,
          end: pr.end,
          text: text.substring(pr.start, pr.end),
        );
      }
    }
    final r = ranges[target] ?? _Range(0, text.length);
    return ResolvedRange(
      start: r.start,
      end: r.end,
      text: text.substring(r.start, r.end),
    );
  }

  ResolvedRange wholeRange(SpanNode root) {
    final r = ranges[root] ?? _Range(0, text.length);
    return ResolvedRange(
      start: r.start,
      end: r.end,
      text: text.substring(r.start, r.end),
    );
  }
}

class _Range {
  final int start;
  final int end;
  _Range(this.start, this.end);
}
