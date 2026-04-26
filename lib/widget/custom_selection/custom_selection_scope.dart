import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../span_node.dart';
import 'custom_selection_config.dart';
import 'range_resolver.dart';

/// Information about a selectable block registered with the scope.
class CustomSelectableBlock {
  /// Index of the block in the rendering order.
  final int index;

  /// Root [SpanNode] for the block (may be null if the block is rendered as a
  /// non-text widget, e.g. images, in which case only block-level selection is
  /// available).
  final SpanNode? rootSpan;

  /// Whether this block contains rich text (i.e. has a [Text.rich]).
  final bool hasRichText;

  /// Key on the block's outermost selectable widget. Used to compute global
  /// rect.
  final GlobalKey containerKey;

  /// Key attached to the underlying [Text.rich] (if any) so the resolver can
  /// reach the [RenderParagraph].
  final GlobalKey? paragraphKey;

  CustomSelectableBlock({
    required this.index,
    required this.rootSpan,
    required this.hasRichText,
    required this.containerKey,
    this.paragraphKey,
  });
}

/// Active selection state for the scope.
class CustomSelectionState {
  final int blockIndex;
  final int start;
  final int end;
  final String text;

  const CustomSelectionState({
    required this.blockIndex,
    required this.start,
    required this.end,
    required this.text,
  });

  CustomSelectionState copyWith({int? start, int? end, String? text}) =>
      CustomSelectionState(
        blockIndex: blockIndex,
        start: start ?? this.start,
        end: end ?? this.end,
        text: text ?? this.text,
      );
}

/// Inherited registry the [SelectableMarkdownElement]s use to register
/// themselves and broadcast hit-test / selection requests.
class CustomSelectionScope extends StatefulWidget {
  final CustomSelectionConfig config;
  final Widget child;

  const CustomSelectionScope({
    Key? key,
    required this.config,
    required this.child,
  }) : super(key: key);

  static CustomSelectionScopeState? maybeOf(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_CustomSelectionInherited>();
    return inherited?.state;
  }

  @override
  State<CustomSelectionScope> createState() => CustomSelectionScopeState();
}

class CustomSelectionScopeState extends State<CustomSelectionScope> {
  final List<CustomSelectableBlock> _blocks = [];
  final Map<int, SpanNodeIndex> _indices = {};

  CustomSelectionConfig get config => widget.config;

  void registerBlock(CustomSelectableBlock block) {
    final existing = _blocks.indexWhere((b) => b.index == block.index);
    if (existing >= 0) {
      _blocks[existing] = block;
    } else {
      _blocks.add(block);
      _blocks.sort((a, b) => a.index - b.index);
    }
    if (block.rootSpan != null) {
      _indices[block.index] = SpanNodeIndex.build(block.rootSpan!);
    }
  }

  void unregisterBlock(int index) {
    _blocks.removeWhere((b) => b.index == index);
    _indices.remove(index);
  }

  /// Find the block at [globalPosition].
  CustomSelectableBlock? hitTestBlock(Offset globalPosition) {
    for (final b in _blocks) {
      final ctx = b.containerKey.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      if (rect.contains(globalPosition)) return b;
    }
    return null;
  }

  SpanNodeIndex? indexOf(int blockIndex) => _indices[blockIndex];

  /// Convert [globalPosition] to a character offset inside the block's
  /// [Text.rich] paragraph. Returns -1 if not available.
  int paragraphOffsetAt(CustomSelectableBlock block, Offset globalPosition) {
    final pkey = block.paragraphKey;
    if (pkey == null) return -1;
    final ctx = pkey.currentContext;
    if (ctx == null) return -1;
    final ro = ctx.findRenderObject();
    if (ro is! RenderParagraph) return -1;
    final local = ro.globalToLocal(globalPosition);
    final pos = ro.getPositionForOffset(local);
    return pos.offset;
  }

  /// Compute the bounding rect (in global coords) of [start, end) within the
  /// block's paragraph. If unavailable falls back to the container rect.
  Rect rangeGlobalRect(CustomSelectableBlock block, int start, int end) {
    final pkey = block.paragraphKey;
    if (pkey != null) {
      final ctx = pkey.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is RenderParagraph) {
        final boxes = ro.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        if (boxes.isNotEmpty) {
          Rect rect = boxes.first.toRect();
          for (final b in boxes.skip(1)) {
            rect = rect.expandToInclude(b.toRect());
          }
          final topLeft = ro.localToGlobal(rect.topLeft);
          return topLeft & rect.size;
        }
      }
    }
    final ctx = block.containerKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is RenderBox) {
      final tl = ro.localToGlobal(Offset.zero);
      return tl & ro.size;
    }
    return Rect.zero;
  }

  /// Selection rectangles in global coordinates (one per text line). Used to
  /// paint the highlight overlay.
  List<Rect> selectionRectsGlobal(
      CustomSelectableBlock block, int start, int end) {
    final pkey = block.paragraphKey;
    if (pkey != null) {
      final ctx = pkey.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is RenderParagraph) {
        final boxes = ro.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        return boxes.map((b) {
          final r = b.toRect();
          return ro.localToGlobal(r.topLeft) & r.size;
        }).toList();
      }
    }
    final ctx = block.containerKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is RenderBox) {
      final tl = ro.localToGlobal(Offset.zero);
      return [tl & ro.size];
    }
    return const [];
  }

  CustomSelectableBlock? blockByIndex(int index) {
    for (final b in _blocks) {
      if (b.index == index) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _CustomSelectionInherited(state: this, child: widget.child);
  }
}

class _CustomSelectionInherited extends InheritedWidget {
  final CustomSelectionScopeState state;

  const _CustomSelectionInherited({
    Key? key,
    required this.state,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(covariant _CustomSelectionInherited oldWidget) =>
      oldWidget.state != state;
}
