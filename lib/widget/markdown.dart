import 'dart:collection';

import 'package:flutter/cupertino.dart' show cupertinoTextSelectionHandleControls;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'custom_selection/vendor/selectable_region_fork.dart';

class MarkdownWidget extends StatefulWidget {
  final String data;
  final TocController? tocController;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final bool selectable;
  final MarkdownConfig? config;
  final MarkdownGenerator? markdownGenerator;
  final bool enableCustomSelection;
  final CustomSelectionConfig? customSelectionConfig;

  const MarkdownWidget({
    Key? key,
    required this.data,
    this.tocController,
    this.physics,
    this.shrinkWrap = false,
    this.selectable = true,
    this.padding,
    this.config,
    this.markdownGenerator,
    this.enableCustomSelection = false,
    this.customSelectionConfig,
  }) : super(key: key);

  @override
  _MarkdownWidgetState createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget> {
  late MarkdownGenerator markdownGenerator;
  List<Widget> _widgets = [];
  TocController? _tocController;
  final AutoScrollController controller = AutoScrollController();
  final indexTreeSet = SplayTreeSet<int>((a, b) => a - b);
  bool isForward = true;

  // Shared across all elements when custom selection is active.
  final _regionKey = GlobalKey<MdSelectableRegionState>();
  final _selectedTextNotifier = ValueNotifier<String>('');
  final _regionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tocController = widget.tocController;
    _tocController?.jumpToIndexCallback = (index) {
      controller.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
    };
    updateState();
  }

  void updateState() {
    indexTreeSet.clear();
    markdownGenerator = widget.markdownGenerator ?? MarkdownGenerator();
    final effectiveConfig = widget.enableCustomSelection
        ? (widget.customSelectionConfig ?? const CustomSelectionConfig(enabled: true))
        : null;
    final result = markdownGenerator.buildWidgets(
      widget.data,
      onTocList: (tocList) => _tocController?.setTocList(tocList),
      config: widget.config,
      customSelectionConfig: effectiveConfig,
      regionKey: widget.enableCustomSelection ? _regionKey : null,
      selectedTextNotifier: widget.enableCustomSelection ? _selectedTextNotifier : null,
    );
    _widgets.addAll(result);
  }

  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
  }

  @override
  void dispose() {
    clearState();
    controller.dispose();
    _tocController?.jumpToIndexCallback = null;
    _selectedTextNotifier.dispose();
    _regionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildMarkdownWidget();

  Widget buildMarkdownWidget() {
    final listView = NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        isForward = notification.direction == ScrollDirection.forward;
        return true;
      },
      child: ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        controller: controller,
        itemBuilder: (ctx, index) => wrapByAutoScroll(
            index, wrapByVisibilityDetector(index, _widgets[index]), controller),
        itemCount: _widgets.length,
        padding: widget.padding,
      ),
    );

    if (widget.enableCustomSelection) {
      // Single forked MdSelectableRegion for the entire content.
      // • handle-only controls → no native toolbar competes with our custom menu
      // • contextMenuBuilder returns empty → native toolbar suppressed
      // • onSelectionChanged → feeds selectedTextNotifier for all element wrappers
      // • selectRange (added on the fork) lets a wrapper select just its element
      return MdSelectableRegion(
        key: _regionKey,
        focusNode: _regionFocusNode,
        selectionControls: _platformHandleControls(context),
        contextMenuBuilder: (context, state) => const SizedBox.shrink(),
        onSelectionChanged: (content) {
          _selectedTextNotifier.value = content?.plainText ?? '';
        },
        child: listView,
      );
    }

    return widget.selectable ? SelectionArea(child: listView) : listView;
  }

  TextSelectionControls _platformHandleControls(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return cupertinoTextSelectionHandleControls;
      default:
        return materialTextSelectionHandleControls;
    }
  }

  Widget wrapByVisibilityDetector(int index, Widget child) {
    return VisibilityDetector(
      key: ValueKey(index.toString()),
      onVisibilityChanged: (info) {
        final v = info.visibleFraction;
        if (isForward) {
          v == 0 ? indexTreeSet.remove(index) : indexTreeSet.add(index);
        } else {
          v == 1.0 ? indexTreeSet.add(index) : indexTreeSet.remove(index);
        }
        if (indexTreeSet.isNotEmpty) _tocController?.onIndexChanged(indexTreeSet.first);
      },
      child: child,
    );
  }

  @override
  void didUpdateWidget(MarkdownWidget oldWidget) {
    clearState();
    updateState();
    super.didUpdateWidget(widget);
  }
}

Widget wrapByAutoScroll(int index, Widget child, AutoScrollController controller) {
  return AutoScrollTag(
    key: Key(index.toString()),
    controller: controller,
    index: index,
    child: child,
    highlightColor: Colors.black.withValues(alpha: 0.1),
  );
}
