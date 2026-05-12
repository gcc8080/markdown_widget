import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:markdown_widget/widget/span_node.dart';

import 'context_menu_overlay.dart';
import 'selection_handle_widget.dart';
import 'selection_highlight_painter.dart';
import 'selection_manager.dart';
import 'selection_models.dart';

/// 自定义选择模式的顶层容器 Widget
///
/// 包裹子 ListView，通过 GestureDetector 监听长按手势（500ms 阈值），
/// 协调 [SelectionManager]、[ContextMenuOverlay]、[SelectionHighlightPainter]
/// 和 [SelectionHandleWidget] 的交互。
///
/// 状态流程：
/// 长按 → 显示菜单 → 选取文字 → 拖动手柄 → 复制
///
/// Requirements: 3.1, 3.2, 3.7, 4.1, 4.9, 4.10, 5.4, 6.4, 6.5
class CustomSelectionOverlay extends StatefulWidget {
  /// 子 Widget（即 ListView），已使用 [elementKeys] 中的 GlobalKey 包裹各元素
  final Widget child;

  /// 所有渲染的 Markdown Widget 列表（用于命中测试）
  final List<Widget> widgets;

  /// 所有 Markdown 元素对应的 SpanNode 列表，用于文本提取和可选性判断
  final List<SpanNode> spanNodes;

  /// 为每个 Markdown Widget 分配的 GlobalKey 列表，用于命中测试定位
  final List<GlobalKey> elementKeys;

  /// Context Menu 构建器
  final ContextMenuWidgetBuilder? contextMenuBuilder;

  /// 自定义菜单项
  final List<SelectionMenuItem>? contextMenuItems;

  const CustomSelectionOverlay({
    super.key,
    required this.child,
    required this.widgets,
    required this.spanNodes,
    required this.elementKeys,
    this.contextMenuBuilder,
    this.contextMenuItems,
  });

  @override
  State<CustomSelectionOverlay> createState() => _CustomSelectionOverlayState();
}

class _CustomSelectionOverlayState extends State<CustomSelectionOverlay> {
  /// 选择状态管理器
  late SelectionManager _selectionManager;

  /// Context Menu 浮窗管理器
  final ContextMenuOverlay _contextMenuOverlay = ContextMenuOverlay();

  /// 选择手柄管理器
  late SelectionHandleWidget _selectionHandleWidget;

  /// 长按位置（全局坐标）
  Offset? _longPressPosition;

  @override
  void initState() {
    super.initState();
    _initializeManagers();
  }

  @override
  void didUpdateWidget(CustomSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.widgets.length != widget.widgets.length ||
        oldWidget.spanNodes.length != widget.spanNodes.length ||
        oldWidget.elementKeys != widget.elementKeys) {
      _disposeManagers();
      _initializeManagers();
    }
  }

  @override
  void dispose() {
    _disposeManagers();
    super.dispose();
  }

  /// 初始化管理器
  void _initializeManagers() {
    _selectionManager = SelectionManager(
      elementKeys: widget.elementKeys,
      spanNodes: widget.spanNodes,
    );
    _selectionManager.addListener(_onSelectionStateChanged);

    _selectionHandleWidget = SelectionHandleWidget(
      selectionManager: _selectionManager,
      elementKeys: widget.elementKeys,
      onHideContextMenu: _hideContextMenu,
      onShowContextMenu: _showCopyMenu,
    );
  }

  /// 释放管理器资源
  void _disposeManagers() {
    _selectionManager.removeListener(_onSelectionStateChanged);
    _selectionManager.dispose();
    _selectionHandleWidget.dispose();
    _contextMenuOverlay.hide();
  }

  /// 选择状态变化回调
  void _onSelectionStateChanged() {
    // 当手柄拖动更新选择范围时，同步更新手柄位置
    if (_selectionManager.state == SelectionState.draggingHandle) {
      _updateSelectionHandles();
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // 手势处理
  // ---------------------------------------------------------------------------

  /// 长按开始回调（500ms 是 Flutter 默认的 kLongPressTimeout）
  ///
  /// Requirement 3.1: 长按 500ms 后弹出 Context Menu
  /// Requirement 3.2: 长按不选中任何文字
  void _onLongPressStart(LongPressStartDetails details) {
    _longPressPosition = details.globalPosition;

    if (_selectionManager.state == SelectionState.textSelected) {
      // 已有选中文本时再次长按：隐藏当前菜单和手柄，重新进入 contextMenuShown
      _hideContextMenu();
      _selectionHandleWidget.hide();
      _selectionManager.onLongPressAgain(details.globalPosition);
    } else {
      // idle 状态下的长按
      _selectionManager.onLongPress(details.globalPosition);
    }

    // 如果命中了有效元素，显示功能菜单
    if (_selectionManager.state == SelectionState.contextMenuShown) {
      _showFunctionMenu(details.globalPosition);
    }
  }

  /// 点击事件：用于检测外部点击以关闭菜单和清除选择
  ///
  /// Requirement 3.7: 点击菜单外部关闭菜单
  /// Requirement 5.4: 点击外部清除选中状态
  void _onTapDown(TapDownDetails details) {
    if (_selectionManager.state == SelectionState.contextMenuShown ||
        _selectionManager.state == SelectionState.textSelected) {
      // 如果手柄正在拖动，不处理点击
      if (_selectionHandleWidget.isDragging) return;

      // 关闭菜单并清除选择
      _hideContextMenu();
      _selectionHandleWidget.hide();
      _selectionManager.onOutsideTap();
    }
  }

  // ---------------------------------------------------------------------------
  // 菜单管理
  // ---------------------------------------------------------------------------

  /// 显示功能菜单（长按后的初始菜单，包含「选取文字」等项）
  ///
  /// Requirement 3.1: 在手指位置上方 8 逻辑像素处弹出
  void _showFunctionMenu(Offset position) {
    final menuItems = _buildFunctionMenuItems();

    _contextMenuOverlay.show(
      context: context,
      anchorPosition: position,
      items: menuItems,
      customBuilder: widget.contextMenuBuilder,
    );
  }

  /// 显示复制菜单（文本选中后的菜单，包含「复制」等项）
  ///
  /// Requirement 4.10: 文本选中后弹出包含「复制」的 Context Menu
  /// Requirement 6.5: 停止拖动后重新显示 Context Menu
  void _showCopyMenu() {
    if (_selectionManager.selectionRange == null) return;

    final selectedText = _selectionManager.selectedText;
    final menuItems = _buildCopyMenuItems();

    // 计算菜单位置：使用长按位置或选中区域的参考位置
    final menuPosition = _calculateCopyMenuPosition();

    _contextMenuOverlay.show(
      context: context,
      anchorPosition: menuPosition,
      items: menuItems,
      selectedText: selectedText,
      customBuilder: widget.contextMenuBuilder,
    );
  }

  /// 隐藏 Context Menu
  ///
  /// Requirement 6.4: 拖动手柄时隐藏菜单
  void _hideContextMenu() {
    _contextMenuOverlay.hide();
  }

  /// 构建功能菜单项列表（长按后显示）
  ///
  /// Requirement 3.3: 默认包含「选取文字」
  /// Requirement 3.6: 自定义菜单项追加到默认项之后
  List<SelectionMenuItem> _buildFunctionMenuItems() {
    final items = <SelectionMenuItem>[
      SelectionMenuItem(
        title: '选取文字',
        icon: Icons.text_fields,
        onPressed: (_, closeMenu) {
          closeMenu();
          _onSelectTextMenuItemClicked();
        },
      ),
    ];

    // 追加自定义菜单项到默认项之后
    if (widget.contextMenuItems != null) {
      items.addAll(widget.contextMenuItems!);
    }

    return items;
  }

  /// 构建复制菜单项列表（文本选中后显示）
  ///
  /// 注意：复制菜单项不在 onPressed 中调用 closeMenu，
  /// 因为需要等待剪贴板写入成功后才关闭菜单（Requirement 5.5）。
  List<SelectionMenuItem> _buildCopyMenuItems() {
    final items = <SelectionMenuItem>[
      SelectionMenuItem(
        title: '复制',
        icon: Icons.copy,
        onPressed: (selectedText, closeMenu) {
          _onCopyMenuItemClicked();
        },
      ),
    ];

    // 追加自定义菜单项
    if (widget.contextMenuItems != null) {
      items.addAll(widget.contextMenuItems!);
    }

    return items;
  }

  /// 计算复制菜单的位置
  ///
  /// 优先使用选中区域的上方中心位置，回退到长按位置
  Offset _calculateCopyMenuPosition() {
    // 尝试根据选中范围计算位置
    final range = _selectionManager.selectionRange;
    if (range != null && widget.elementKeys.isNotEmpty) {
      final startKey = range.startElementIndex < widget.elementKeys.length
          ? widget.elementKeys[range.startElementIndex]
          : null;
      if (startKey != null) {
        final renderObject = startKey.currentContext?.findRenderObject();
        if (renderObject != null && renderObject is RenderBox && renderObject.hasSize) {
          final topLeft = renderObject.localToGlobal(Offset.zero);
          // 菜单位置在选中元素的上方居中
          return Offset(
            topLeft.dx + renderObject.size.width / 2,
            topLeft.dy,
          );
        }
      }
    }

    // 回退到长按位置
    if (_longPressPosition != null) {
      return _longPressPosition!;
    }

    // 最终回退到屏幕中心
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height / 2);
  }

  // ---------------------------------------------------------------------------
  // 菜单项回调
  // ---------------------------------------------------------------------------

  /// 「选取文字」菜单项点击回调
  ///
  /// Requirement 4.1: 关闭当前 Context Menu 并选中元素文本
  /// Requirement 4.9: 显示可拖动的选择手柄
  /// Requirement 4.10: 弹出包含「复制」的 Context Menu
  void _onSelectTextMenuItemClicked() {
    _selectionManager.onSelectTextMenuItemClicked();

    // 如果成功选中了文本，显示高亮、手柄和复制菜单
    if (_selectionManager.state == SelectionState.textSelected) {
      _showSelectionHandles();
      _showCopyMenu();
    }
  }

  /// 「复制」菜单项点击回调
  ///
  /// 将选中文本复制到剪贴板。
  /// - 成功：关闭菜单、隐藏手柄、清除选择状态（Requirement 5.3）
  /// - 失败：保持当前选中状态和菜单显示不变（Requirement 5.5）
  Future<void> _onCopyMenuItemClicked() async {
    final text = _selectionManager.getPlainText();
    if (text.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: text));
      // 成功：关闭菜单，清除选择状态
      _hideContextMenu();
      _selectionHandleWidget.hide();
      _selectionManager.clearSelection();
    } catch (e) {
      // 失败：保持当前状态不变（选中高亮、手柄、菜单均保留）
      debugPrint('Clipboard write failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 选择手柄管理
  // ---------------------------------------------------------------------------

  /// 显示选择手柄
  void _showSelectionHandles() {
    final range = _selectionManager.selectionRange;
    if (range == null) return;
    _selectionHandleWidget.show(context, range);
  }

  /// 更新选择手柄位置
  void _updateSelectionHandles() {
    final range = _selectionManager.selectionRange;
    if (range == null) return;
    _selectionHandleWidget.update(context, range);
  }

  // ---------------------------------------------------------------------------
  // 构建 Widget 树
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _onLongPressStart,
      onTapDown: _onTapDown,
      child: Stack(
        children: [
          // 子 Widget（ListView），其中的 item 已通过 elementKeys 包裹
          widget.child,
          // 选中高亮层
          if (_selectionManager.selectionRange != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SelectionHighlightPainter(
                    selectionRange: _selectionManager.selectionRange,
                    elementKeys: widget.elementKeys,
                    paintContext: context,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
