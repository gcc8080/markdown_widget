import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MarkdownWidget extends StatefulWidget {
  ///the markdown data
  final String data;

  ///if [tocController] is not null, you can use [tocListener] to get current TOC index
  final TocController? tocController;

  ///set the desired scroll physics for the markdown item list
  final ScrollPhysics? physics;

  ///set shrinkWrap to obtained [ListView] (only available when [tocController] is null)
  final bool shrinkWrap;

  /// [ListView] padding
  final EdgeInsetsGeometry? padding;

  ///make text selectable
  final bool selectable;

  ///the configs of markdown
  final MarkdownConfig? config;

  ///config for [MarkdownGenerator]
  final MarkdownGeneratorConfig? markdownGeneratorConfig;

  /// 是否开启自定义选择模式。
  /// 为 true 时不使用 SelectionArea，启用自定义长按菜单和元素级选中。
  /// 默认为 false。
  final bool customSelectionMode;

  /// 自定义 Context Menu 构建器。
  /// 接收长按位置和菜单项列表，返回自定义菜单 Widget。
  /// 若提供此参数，将完全替代默认 Context Menu 的渲染。
  final ContextMenuWidgetBuilder? contextMenuBuilder;

  /// 追加到默认菜单项列表末尾的自定义菜单项。
  final List<SelectionMenuItem>? contextMenuItems;

  const MarkdownWidget({
    Key? key,
    required this.data,
    this.tocController,
    this.physics,
    this.shrinkWrap = false,
    this.selectable = true,
    this.padding,
    this.config,
    this.markdownGeneratorConfig,
    this.customSelectionMode = false,
    this.contextMenuBuilder,
    this.contextMenuItems,
  }) : super(key: key);

  @override
  _MarkdownWidgetState createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget> {
  ///use [markdownGenerator] to transform markdown data to [Widget] list
  late MarkdownGenerator markdownGenerator;

  ///The markdown string converted by MarkdownGenerator will be retained in the [_widgets]
  List<Widget> _widgets = [];

  ///SpanNode list corresponding to each widget, used for custom selection mode
  List<SpanNode> _spanNodes = [];

  ///GlobalKey list for each widget, used for hit testing in custom selection mode
  List<GlobalKey> _elementKeys = [];

  ///[TocController] combines [TocWidget] and [MarkdownWidget]
  TocController? _tocController;

  ///[AutoScrollController] provides the scroll to index mechanism
  final AutoScrollController controller = AutoScrollController();

  ///every [VisibilityDetector]'s child which is visible will be kept with [indexTreeSet]
  final indexTreeSet = SplayTreeSet<int>((a, b) => a - b);

  ///if the [ScrollDirection] of [ListView] is [ScrollDirection.forward], [isForward] will be true
  bool isForward = true;

  @override
  void initState() {
    super.initState();
    _tocController = widget.tocController;
    _tocController?.jumpToIndexCallback = (index) {
      controller.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
    };
    updateState();
  }

  ///when we've got the data, we need update data without setState() to avoid the flicker of the view
  void updateState() {
    indexTreeSet.clear();
    final generatorConfig =
        widget.markdownGeneratorConfig ?? MarkdownGeneratorConfig();
    markdownGenerator = MarkdownGenerator(
      config: widget.config,
      inlineSyntaxes: generatorConfig.inlineSyntaxList,
      blockSyntaxes: generatorConfig.blockSyntaxList,
      linesMargin: generatorConfig.linesMargin,
      generators: generatorConfig.generators,
      onNodeAccepted: generatorConfig.onNodeAccepted,
      textGenerator: generatorConfig.textGenerator,
    );
    final result =
        markdownGenerator.buildWidgets(widget.data, onTocList: (tocList) {
      _tocController?.setTocList(tocList);
    }, onSpanNodes: (spanNodes) {
      _spanNodes = spanNodes;
    });
    _widgets.addAll(result);
    // Generate GlobalKeys for each widget (used for hit testing in custom selection mode)
    _elementKeys =
        List.generate(_widgets.length, (_) => GlobalKey());
  }

  ///this method will be called when [updateState] or [dispose]
  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
    _spanNodes.clear();
    _elementKeys.clear();
  }

  @override
  void dispose() {
    clearState();
    controller.dispose();
    _tocController?.jumpToIndexCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildMarkdownWidget();

  ///
  Widget buildMarkdownWidget() {
    final markdownWidget = NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        final ScrollDirection direction = notification.direction;
        isForward = direction == ScrollDirection.forward;
        return true;
      },
      child: ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        controller: controller,
        itemBuilder: (ctx, index) {
          Widget item = _widgets[index];
          // Wrap each widget with a KeyedSubtree using its GlobalKey for hit testing
          if (widget.customSelectionMode && index < _elementKeys.length) {
            item = KeyedSubtree(
              key: _elementKeys[index],
              child: item,
            );
          }
          return wrapByAutoScroll(
              index, wrapByVisibilityDetector(index, item), controller);
        },
        itemCount: _widgets.length,
        padding: widget.padding,
      ),
    );

    if (widget.customSelectionMode) {
      // 自定义选择模式：不使用 SelectionArea，使用 CustomSelectionOverlay
      return CustomSelectionOverlay(
        child: markdownWidget,
        widgets: _widgets,
        spanNodes: _spanNodes,
        elementKeys: _elementKeys,
        contextMenuBuilder: widget.contextMenuBuilder,
        contextMenuItems: widget.contextMenuItems,
      );
    } else if (widget.selectable) {
      // 原有行为：使用 SelectionArea
      return SelectionArea(child: markdownWidget);
    } else {
      // 禁用选择
      return markdownWidget;
    }
  }

  ///wrap widget by [VisibilityDetector] that can know if [child] is visible
  Widget wrapByVisibilityDetector(int index, Widget child) {
    return VisibilityDetector(
      key: ValueKey(index.toString()),
      onVisibilityChanged: (VisibilityInfo info) {
        final visibleFraction = info.visibleFraction;
        if (isForward) {
          visibleFraction == 0
              ? indexTreeSet.remove(index)
              : indexTreeSet.add(index);
        } else {
          visibleFraction == 1.0
              ? indexTreeSet.add(index)
              : indexTreeSet.remove(index);
        }
        if (indexTreeSet.isNotEmpty) {
          _tocController?.onIndexChanged(indexTreeSet.first);
        }
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

///wrap widget by [AutoScrollTag] that can use [AutoScrollController] to scrollToIndex
Widget wrapByAutoScroll(
    int index, Widget child, AutoScrollController controller) {
  return AutoScrollTag(
    key: Key(index.toString()),
    controller: controller,
    index: index,
    child: child,
    highlightColor: Colors.black.withOpacity(0.1),
  );
}
