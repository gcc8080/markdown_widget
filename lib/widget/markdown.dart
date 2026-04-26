import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  ///Enable a custom selection entry mode.
  ///
  ///When enabled, long-pressing a markdown block opens a custom menu first.
  ///Users need to choose [customSelectionLabel] to enter native text selection.
  final bool enableCustomSelection;

  ///Label for the default action that enters text-selection mode.
  final String customSelectionLabel;

  ///Label for the default copy action in custom selection mode.
  final String customCopyLabel;

  ///Additional custom actions displayed together with [customSelectionLabel]
  ///when users long press a markdown block.
  final List<MarkdownCustomSelectionAction> customSelectionActions;

  ///the configs of markdown
  final MarkdownConfig? config;

  ///config for [MarkdownGenerator]
  final MarkdownGeneratorConfig? markdownGeneratorConfig;

  const MarkdownWidget({
    Key? key,
    required this.data,
    this.tocController,
    this.physics,
    this.shrinkWrap = false,
    this.selectable = true,
    this.enableCustomSelection = false,
    this.customSelectionLabel = '选取文字',
    this.customCopyLabel = '复制',
    this.customSelectionActions = const [],
    this.padding,
    this.config,
    this.markdownGeneratorConfig,
  }) : super(key: key);

  @override
  _MarkdownWidgetState createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget> {
  ///use [markdownGenerator] to transform markdown data to [Widget] list
  late MarkdownGenerator markdownGenerator;

  ///The markdown string converted by MarkdownGenerator will be retained in the [_widgets]
  List<Widget> _widgets = [];

  ///the plain text list for each rendered markdown block
  List<String> _blockTexts = [];

  ///[TocController] combines [TocWidget] and [MarkdownWidget]
  TocController? _tocController;

  ///[AutoScrollController] provides the scroll to index mechanism
  final AutoScrollController controller = AutoScrollController();

  ///every [VisibilityDetector]'s child which is visible will be kept with [indexTreeSet]
  final indexTreeSet = SplayTreeSet<int>((a, b) => a - b);

  ///if the [ScrollDirection] of [ListView] is [ScrollDirection.forward], [isForward] will be true
  bool isForward = true;

  ///currently selected block index in custom selection mode
  int? _customSelectedIndex;

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
    _customSelectedIndex = null;
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
    });
    _widgets.addAll(result);
    _blockTexts = List.generate(_widgets.length, _extractPlainTextFromWidget);
  }

  String _extractPlainTextFromWidget(int index) {
    final widget = _widgets[index];
    if (widget is Padding && widget.child is RichText) {
      return (widget.child as RichText).text.toPlainText().trim();
    }
    if (widget is Padding && widget.child is Text) {
      final textWidget = widget.child as Text;
      return textWidget.data?.trim() ?? textWidget.textSpan?.toPlainText().trim() ?? '';
    }
    return '';
  }

  ///this method will be called when [updateState] or [dispose]
  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
    _blockTexts.clear();
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
    final listView = NotificationListener<UserScrollNotification>(
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
          Widget child = _widgets[index];
          if (widget.enableCustomSelection && widget.selectable) {
            final isSelected = _customSelectedIndex == index;
            child = AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: child,
            );
            if (_customSelectedIndex != null && !isSelected) {
              child = SelectionContainer.disabled(child: child);
            }
            child = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) =>
                  _handleCustomLongPress(index, details.globalPosition),
              child: child,
            );
          }
          return wrapByAutoScroll(
              index, wrapByVisibilityDetector(index, child), controller);
        },
        itemCount: _widgets.length,
        padding: widget.padding,
      ),
    );

    if (!widget.selectable) return listView;

    if (!widget.enableCustomSelection) {
      return SelectionArea(child: listView);
    }

    return _customSelectedIndex == null
        ? listView
        : SelectionArea(child: listView);
  }

  Future<void> _handleCustomLongPress(int index, Offset globalPosition) async {
    final selectedAction = await showMenu<_CustomMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem<_CustomMenuAction>(
          value: _CustomMenuAction.selectText,
          child: Text(widget.customSelectionLabel),
        ),
        ...widget.customSelectionActions.map(
          (action) => PopupMenuItem<_CustomMenuAction>(
            value: _CustomMenuAction.custom,
            onTap: () => action.onTap(
              context,
              MarkdownCustomSelectionContext(
                blockIndex: index,
                blockText: _blockTexts[index],
                globalPosition: globalPosition,
              ),
            ),
            child: Text(action.label),
          ),
        ),
      ],
    );

    if (selectedAction != _CustomMenuAction.selectText) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _customSelectedIndex = index;
    });

    final copyAction = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem<bool>(
          value: true,
          child: Text(widget.customCopyLabel),
        )
      ],
    );

    if (copyAction == true) {
      await Clipboard.setData(ClipboardData(text: _blockTexts[index]));
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

class MarkdownCustomSelectionAction {
  final String label;
  final void Function(BuildContext context, MarkdownCustomSelectionContext contextData)
      onTap;

  const MarkdownCustomSelectionAction({
    required this.label,
    required this.onTap,
  });
}

class MarkdownCustomSelectionContext {
  final int blockIndex;
  final String blockText;
  final Offset globalPosition;

  const MarkdownCustomSelectionContext({
    required this.blockIndex,
    required this.blockText,
    required this.globalPosition,
  });
}

enum _CustomMenuAction { selectText, custom }

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
