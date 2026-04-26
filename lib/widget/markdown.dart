import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum CustomSelectionStatus {
  idle,
  menuShownAtLongPress,
  elementSelected,
}

class CustomSelectionController extends ChangeNotifier {
  CustomSelectionStatus _status = CustomSelectionStatus.idle;

  CustomSelectionStatus get status => _status;

  void toIdle() {
    _status = CustomSelectionStatus.idle;
    notifyListeners();
  }

  void showFirstMenu() {
    _status = CustomSelectionStatus.menuShownAtLongPress;
    notifyListeners();
  }

  void selectElement() {
    _status = CustomSelectionStatus.elementSelected;
    notifyListeners();
  }
}

@immutable
class MarkdownSelectionMenuItem {
  final String id;
  final String label;
  final VoidCallback? onTap;

  const MarkdownSelectionMenuItem({
    required this.id,
    required this.label,
    this.onTap,
  });
}

@immutable
class MarkdownSelectionMenuStyle {
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final List<PopupMenuEntry<MarkdownSelectionMenuItem>> Function(BuildContext context)?
      itemBuilder;

  const MarkdownSelectionMenuStyle({
    this.backgroundColor,
    this.borderRadius,
    this.shadows,
    this.itemBuilder,
  });
}

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

  ///enable custom selection workflow with two-stage menu.
  final bool enableCustomSelectionMenu;

  ///custom menu style for first-level and selection menus.
  final MarkdownSelectionMenuStyle? selectionMenuStyle;

  ///extra menu items shown in selection menu, e.g. share/comment.
  final List<MarkdownSelectionMenuItem> extraSelectionMenuItems;

  ///configurations for markdown
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
    this.enableCustomSelectionMenu = false,
    this.selectionMenuStyle,
    this.extraSelectionMenuItems = const [],
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

  final CustomSelectionController _selectionController =
      CustomSelectionController();

  /// block keys for hit-testing by long-press coordinate.
  final List<GlobalKey> _blockKeys = [];

  ///plain text per markdown block for fallback copy.
  final List<String> _blockTexts = [];

  Offset? _lastLongPressGlobalPosition;
  int? _selectedBlockIndex;
  String? _currentSelectedContent;

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
    _blockKeys.clear();
    _blockTexts.clear();
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
    for (final item in result) {
      _blockKeys.add(GlobalKey());
      _blockTexts.add(_extractPlainText(item));
    }
  }

  String _extractPlainText(Widget widget) {
    if (widget is Padding) {
      return _extractPlainText(widget.child ?? const SizedBox.shrink());
    }
    if (widget is Text) {
      final span = widget.textSpan;
      if (span != null) {
        return _flattenInlineSpan(span);
      }
      return widget.data ?? '';
    }
    if (widget is RichText) {
      return _flattenInlineSpan(widget.text);
    }
    return '';
  }

  String _flattenInlineSpan(InlineSpan span) {
    if (span is TextSpan) {
      final buffer = StringBuffer(span.text ?? '');
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          buffer.write(_flattenInlineSpan(child));
        }
      }
      return buffer.toString();
    }
    return '';
  }

  ///this method will be called when [updateState] or [dispose]
  void clearState() {
    indexTreeSet.clear();
    _widgets.clear();
    _blockKeys.clear();
    _blockTexts.clear();
    _selectedBlockIndex = null;
    _currentSelectedContent = null;
    _lastLongPressGlobalPosition = null;
    _selectionController.toIdle();
  }

  @override
  void dispose() {
    clearState();
    _selectionController.dispose();
    controller.dispose();
    _tocController?.jumpToIndexCallback = null;
    super.dispose();
  }

  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    if (!widget.selectable || !widget.enableCustomSelectionMenu) {
      return;
    }
    _lastLongPressGlobalPosition = details.globalPosition;
    _selectedBlockIndex = _findBlockIndexByPosition(details.globalPosition);
    if (_selectedBlockIndex == null) {
      return;
    }
    _selectionController.showFirstMenu();
    await _showFirstLevelMenu(details.globalPosition);
  }

  int? _findBlockIndexByPosition(Offset globalPosition) {
    for (var i = 0; i < _blockKeys.length; i++) {
      final currentContext = _blockKeys[i].currentContext;
      if (currentContext == null) {
        continue;
      }
      final renderBox = currentContext.findRenderObject();
      if (renderBox is! RenderBox) {
        continue;
      }
      final topLeft = renderBox.localToGlobal(Offset.zero);
      final rect = topLeft & renderBox.size;
      if (rect.contains(globalPosition)) {
        return i;
      }
    }
    return null;
  }

  RelativeRect _menuPositionFromGlobalOffset(Offset offset) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromCenter(center: offset, width: 1, height: 1),
      Offset.zero & overlay.size,
    );
  }

  List<PopupMenuEntry<MarkdownSelectionMenuItem>> _buildMenuEntries(
      List<MarkdownSelectionMenuItem> items) {
    final builder = widget.selectionMenuStyle?.itemBuilder;
    if (builder != null) {
      return builder(context);
    }
    return items
        .map((item) => PopupMenuItem<MarkdownSelectionMenuItem>(
              value: item,
              child: Text(item.label),
            ))
        .toList();
  }

  Future<void> _showFirstLevelMenu(Offset globalPosition) async {
    final selectTextItem = MarkdownSelectionMenuItem(
      id: 'select_text',
      label: '选取文字',
    );
    final selected = await showMenu<MarkdownSelectionMenuItem>(
      context: context,
      position: _menuPositionFromGlobalOffset(globalPosition),
      color: widget.selectionMenuStyle?.backgroundColor,
      elevation: widget.selectionMenuStyle?.shadows?.isNotEmpty == true ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius:
            widget.selectionMenuStyle?.borderRadius ?? BorderRadius.circular(8),
      ),
      items: _buildMenuEntries([selectTextItem]),
    );
    if (selected?.id == 'select_text') {
      _selectionController.selectElement();
      if (mounted) {
        setState(() {});
      }
      await _showSelectionMenu(globalPosition);
    } else {
      _selectionController.toIdle();
    }
  }

  Future<void> _showSelectionMenu(Offset globalPosition) async {
    final items = <MarkdownSelectionMenuItem>[
      MarkdownSelectionMenuItem(id: 'copy', label: '复制'),
      ...widget.extraSelectionMenuItems,
    ];
    final selected = await showMenu<MarkdownSelectionMenuItem>(
      context: context,
      position: _menuPositionFromGlobalOffset(globalPosition),
      color: widget.selectionMenuStyle?.backgroundColor,
      elevation: widget.selectionMenuStyle?.shadows?.isNotEmpty == true ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius:
            widget.selectionMenuStyle?.borderRadius ?? BorderRadius.circular(8),
      ),
      items: _buildMenuEntries(items),
    );
    if (selected == null) {
      return;
    }
    if (selected.id == 'copy') {
      await _copySelectionText();
    } else {
      selected.onTap?.call();
    }
  }

  Future<void> _copySelectionText() async {
    final fallback = (_selectedBlockIndex != null &&
            _selectedBlockIndex! >= 0 &&
            _selectedBlockIndex! < _blockTexts.length)
        ? _blockTexts[_selectedBlockIndex!]
        : '';
    final textToCopy = (_currentSelectedContent != null &&
            _currentSelectedContent!.trim().isNotEmpty)
        ? _currentSelectedContent!
        : fallback;
    if (textToCopy.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: textToCopy));
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
        itemBuilder: (ctx, index) => wrapByAutoScroll(
            index,
            wrapByVisibilityDetector(
              index,
              KeyedSubtree(
                key: _blockKeys[index],
                child: _widgets[index],
              ),
            ),
            controller),
        itemCount: _widgets.length,
        padding: widget.padding,
      ),
    );

    final useCustomSelection = widget.selectable && widget.enableCustomSelectionMenu;
    final activatedSelection = useCustomSelection &&
        _selectionController.status == CustomSelectionStatus.elementSelected;

    Widget result = markdownWidget;
    if (activatedSelection) {
      result = SelectionArea(
        onSelectionChanged: (selection) {
          _currentSelectedContent = selection?.plainText;
        },
        child: result,
      );
    } else if (widget.selectable && !widget.enableCustomSelectionMenu) {
      result = SelectionArea(child: result);
    }

    if (useCustomSelection) {
      result = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: _onLongPressStart,
        child: result,
      );
    }

    return result;
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
