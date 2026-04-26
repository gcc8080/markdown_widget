import 'package:flutter/material.dart';

import '../span_node.dart';
import 'custom_selection_scope.dart';

/// Wraps a single rendered markdown block so the [CustomSelectionScope] can
/// hit-test and read range information.
class SelectableMarkdownElement extends StatefulWidget {
  final int index;
  final SpanNode? rootSpan;
  final GlobalKey? paragraphKey;
  final Widget child;

  const SelectableMarkdownElement({
    Key? key,
    required this.index,
    required this.rootSpan,
    required this.child,
    this.paragraphKey,
  }) : super(key: key);

  @override
  State<SelectableMarkdownElement> createState() =>
      _SelectableMarkdownElementState();
}

class _SelectableMarkdownElementState extends State<SelectableMarkdownElement> {
  final GlobalKey _containerKey = GlobalKey();
  CustomSelectionScopeState? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = CustomSelectionScope.maybeOf(context);
    _scope = scope;
    scope?.registerBlock(CustomSelectableBlock(
      index: widget.index,
      rootSpan: widget.rootSpan,
      hasRichText: widget.paragraphKey != null,
      containerKey: _containerKey,
      paragraphKey: widget.paragraphKey,
    ));
  }

  @override
  void dispose() {
    _scope?.unregisterBlock(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _containerKey, child: widget.child);
  }
}
