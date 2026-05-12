import 'package:flutter/material.dart';

import 'default_context_menu.dart';
import 'selection_models.dart';

/// Context Menu 浮窗管理
///
/// 负责通过 Flutter Overlay API 显示和隐藏功能菜单。
/// 菜单默认定位在锚点位置上方 8 逻辑像素处，若上方空间不足则显示在下方。
/// 支持通过 [ContextMenuWidgetBuilder] 自定义菜单渲染。
class ContextMenuOverlay {
  /// 当前的 OverlayEntry（若菜单正在显示）
  OverlayEntry? _overlayEntry;

  /// 菜单是否正在显示
  bool get isShowing => _overlayEntry != null;

  /// 菜单与锚点之间的间距（逻辑像素）
  static const double _menuGap = 8.0;

  /// 显示功能菜单
  ///
  /// [context] 用于获取 Overlay 和屏幕尺寸。
  /// [anchorPosition] 为长按位置或选中区域中心位置（全局坐标）。
  /// [items] 为菜单项列表。
  /// [selectedText] 为当前选中的文本（选中状态下才有值）。
  /// [customBuilder] 为自定义菜单构建器，若提供则完全替代默认渲染。
  void show({
    required BuildContext context,
    required Offset anchorPosition,
    required List<SelectionMenuItem> items,
    String? selectedText,
    ContextMenuWidgetBuilder? customBuilder,
  }) {
    // 先关闭已有菜单
    hide();

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _ContextMenuOverlayWidget(
          anchorPosition: anchorPosition,
          items: items,
          selectedText: selectedText,
          customBuilder: customBuilder,
          onDismiss: hide,
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  /// 关闭功能菜单
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// 内部 Widget，负责菜单的定位和外部点击检测
class _ContextMenuOverlayWidget extends StatelessWidget {
  final Offset anchorPosition;
  final List<SelectionMenuItem> items;
  final String? selectedText;
  final ContextMenuWidgetBuilder? customBuilder;
  final VoidCallback onDismiss;

  const _ContextMenuOverlayWidget({
    required this.anchorPosition,
    required this.items,
    this.selectedText,
    this.customBuilder,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // 如果使用自定义构建器，直接调用并包裹在全屏手势检测中
    if (customBuilder != null) {
      return Stack(
        children: [
          // 全屏透明层，检测外部点击以关闭菜单
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          // 自定义菜单
          customBuilder!(
            anchorPosition,
            items,
            selectedText,
            onDismiss,
          ),
        ],
      );
    }

    // 默认菜单：使用 LayoutBuilder 获取可用空间进行定位
    return Stack(
      children: [
        // 全屏透明层，检测外部点击以关闭菜单
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // 定位菜单
        _PositionedMenu(
          anchorPosition: anchorPosition,
          items: items,
          selectedText: selectedText,
          onDismiss: onDismiss,
        ),
      ],
    );
  }
}

/// 负责测量菜单尺寸并计算最终位置的 Widget
class _PositionedMenu extends StatefulWidget {
  final Offset anchorPosition;
  final List<SelectionMenuItem> items;
  final String? selectedText;
  final VoidCallback onDismiss;

  const _PositionedMenu({
    required this.anchorPosition,
    required this.items,
    this.selectedText,
    required this.onDismiss,
  });

  @override
  State<_PositionedMenu> createState() => _PositionedMenuState();
}

class _PositionedMenuState extends State<_PositionedMenu> {
  final GlobalKey _menuKey = GlobalKey();
  Offset? _menuPosition;

  @override
  void initState() {
    super.initState();
    // 在第一帧渲染后测量菜单尺寸并计算位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePosition();
    });
  }

  void _calculatePosition() {
    final menuContext = _menuKey.currentContext;
    if (menuContext == null) return;

    final renderBox = menuContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final menuSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // 计算水平位置：菜单水平居中于锚点，但不超出屏幕边界
    double dx = widget.anchorPosition.dx - menuSize.width / 2;
    dx = dx.clamp(8.0, screenSize.width - menuSize.width - 8.0);

    // 计算垂直位置：优先显示在锚点上方 8 逻辑像素处
    final double aboveY =
        widget.anchorPosition.dy - menuSize.height - ContextMenuOverlay._menuGap;
    final double belowY =
        widget.anchorPosition.dy + ContextMenuOverlay._menuGap;

    double dy;
    if (aboveY >= padding.top) {
      // 上方有足够空间
      dy = aboveY;
    } else {
      // 上方空间不足，显示在下方
      dy = belowY;
    }

    if (mounted) {
      setState(() {
        _menuPosition = Offset(dx, dy);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuWidget = DefaultContextMenu(
      key: _menuKey,
      items: widget.items,
      selectedText: widget.selectedText,
      onClose: widget.onDismiss,
    );

    if (_menuPosition == null) {
      // 第一帧：渲染但不可见（用于测量尺寸）
      return Positioned(
        left: -9999,
        top: -9999,
        child: menuWidget,
      );
    }

    return Positioned(
      left: _menuPosition!.dx,
      top: _menuPosition!.dy,
      child: menuWidget,
    );
  }
}
