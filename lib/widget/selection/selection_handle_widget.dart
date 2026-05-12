import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'selection_manager.dart';
import 'selection_models.dart';

/// 选择手柄类型：起始或结束
enum HandleType {
  /// 起始手柄（选中区域前端）
  start,

  /// 结束手柄（选中区域末端）
  end,
}

/// 选择手柄管理器
///
/// 管理两个可拖动的选择手柄（起始和结束），使用 Overlay + Positioned 定位。
/// 手柄位置通过 RenderParagraph.getOffsetForCaret() 计算。
/// 拖动过程中通知 SelectionManager 更新选择边界，并隐藏/显示 Context Menu。
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
class SelectionHandleWidget {
  /// SelectionManager 引用，用于通知拖动更新
  final SelectionManager selectionManager;

  /// 所有 Markdown Widget 的 GlobalKey 列表，用于查找 RenderParagraph
  final List<GlobalKey> elementKeys;

  /// 隐藏 Context Menu 的回调
  final VoidCallback onHideContextMenu;

  /// 显示 Context Menu 的回调
  final VoidCallback onShowContextMenu;

  /// 手柄颜色
  final Color handleColor;

  /// 手柄直径
  final double handleSize;

  /// 起始手柄的 Overlay Entry
  OverlayEntry? _startHandleEntry;

  /// 结束手柄的 Overlay Entry
  OverlayEntry? _endHandleEntry;

  /// 当前是否正在显示手柄
  bool _isShowing = false;

  /// 当前是否正在拖动
  bool _isDragging = false;

  SelectionHandleWidget({
    required this.selectionManager,
    required this.elementKeys,
    required this.onHideContextMenu,
    required this.onShowContextMenu,
    this.handleColor = Colors.blue,
    this.handleSize = 12.0,
  });

  /// 手柄是否正在显示
  bool get isShowing => _isShowing;

  /// 是否正在拖动
  bool get isDragging => _isDragging;

  /// 显示选择手柄
  ///
  /// 根据当前 [selectionRange] 计算起始和结束手柄的位置，
  /// 并通过 Overlay 显示手柄 Widget。
  void show(BuildContext context, TextSelectionRange selectionRange) {
    hide();

    final startPosition = _calculateHandlePosition(
      selectionRange.startElementIndex,
      selectionRange.startOffset,
    );
    final endPosition = _calculateHandlePosition(
      selectionRange.endElementIndex,
      selectionRange.endOffset,
    );

    if (startPosition == null && endPosition == null) return;

    final overlay = Overlay.of(context);

    _startHandleEntry = OverlayEntry(
      builder: (context) => _buildHandle(
        context,
        HandleType.start,
        startPosition,
        selectionRange,
      ),
    );

    _endHandleEntry = OverlayEntry(
      builder: (context) => _buildHandle(
        context,
        HandleType.end,
        endPosition,
        selectionRange,
      ),
    );

    overlay.insert(_startHandleEntry!);
    overlay.insert(_endHandleEntry!);
    _isShowing = true;
  }

  /// 隐藏选择手柄
  void hide() {
    _startHandleEntry?.remove();
    _startHandleEntry = null;
    _endHandleEntry?.remove();
    _endHandleEntry = null;
    _isShowing = false;
  }

  /// 更新手柄位置（选择范围变化时调用）
  void update(BuildContext context, TextSelectionRange selectionRange) {
    if (!_isShowing) {
      show(context, selectionRange);
      return;
    }
    // 移除旧的 entry 并重新插入
    hide();
    show(context, selectionRange);
  }

  /// 安全释放所有资源
  void dispose() {
    hide();
  }

  // ---------------------------------------------------------------------------
  // 私有方法
  // ---------------------------------------------------------------------------

  /// 构建单个手柄 Widget
  Widget _buildHandle(
    BuildContext context,
    HandleType type,
    Offset? position,
    TextSelectionRange selectionRange,
  ) {
    if (position == null) {
      return const SizedBox.shrink();
    }

    // 起始手柄在文本左侧下方，结束手柄在文本右侧下方
    final double left;
    if (type == HandleType.start) {
      left = position.dx - handleSize / 2;
    } else {
      left = position.dx - handleSize / 2;
    }
    final top = position.dy;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _onDragStart(type),
        onPanUpdate: (details) => _onDragUpdate(type, details),
        onPanEnd: (details) => _onDragEnd(type),
        child: _HandlePainterWidget(
          type: type,
          color: handleColor,
          size: handleSize,
        ),
      ),
    );
  }

  /// 计算手柄位置
  ///
  /// 使用 RenderParagraph.getOffsetForCaret() 获取光标位置，
  /// 然后将其转换为全局坐标。
  Offset? _calculateHandlePosition(int elementIndex, int offset) {
    if (elementIndex < 0 || elementIndex >= elementKeys.length) return null;

    final key = elementKeys[elementIndex];
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return null;

    // 查找 RenderParagraph
    final renderParagraph = _findRenderParagraph(renderObject);
    if (renderParagraph == null) return null;

    // 使用 getOffsetForCaret 获取光标位置
    final textPosition = TextPosition(offset: offset);
    final caretOffset =
        renderParagraph.getOffsetForCaret(textPosition, Rect.zero);

    // 获取行高以定位手柄在文本下方
    final lineHeight = renderParagraph.getFullHeightForCaret(textPosition) ??
        renderParagraph.size.height;

    // 将局部坐标转换为全局坐标
    final globalOffset = renderParagraph.localToGlobal(
      Offset(caretOffset.dx, caretOffset.dy + lineHeight),
    );

    return globalOffset;
  }

  /// 递归查找 RenderObject 树中的第一个 RenderParagraph
  RenderParagraph? _findRenderParagraph(RenderObject renderObject) {
    if (renderObject is RenderParagraph) {
      return renderObject;
    }

    RenderParagraph? result;
    renderObject.visitChildren((child) {
      if (result != null) return;
      result = _findRenderParagraph(child);
    });

    return result;
  }

  /// 手柄拖动开始
  void _onDragStart(HandleType type) {
    _isDragging = true;
    // 通知 SelectionManager 进入拖动状态
    selectionManager.onHandleDragStart();
    // 隐藏 Context Menu（Requirement 6.4）
    onHideContextMenu();
  }

  /// 手柄拖动更新
  ///
  /// 根据手柄类型更新选择范围的起始或结束边界。
  void _onDragUpdate(HandleType type, DragUpdateDetails details) {
    final globalPosition = details.globalPosition;

    if (type == HandleType.start) {
      // 更新选择起始边界（Requirement 6.2）
      selectionManager.updateSelectionStart(globalPosition);
    } else {
      // 更新选择结束边界（Requirement 6.3）
      selectionManager.updateSelectionEnd(globalPosition);
    }
  }

  /// 手柄拖动结束
  void _onDragEnd(HandleType type) {
    _isDragging = false;
    // 通知 SelectionManager 拖动结束
    selectionManager.onHandleDragEnd();
    // 显示 Context Menu（Requirement 6.5）
    onShowContextMenu();
  }
}

/// 手柄绘制 Widget
///
/// 绘制一个水滴形状的选择手柄，类似 Android/iOS 的文本选择手柄。
class _HandlePainterWidget extends StatelessWidget {
  final HandleType type;
  final Color color;
  final double size;

  const _HandlePainterWidget({
    required this.type,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + size / 2,
      child: CustomPaint(
        painter: _HandlePainter(
          type: type,
          color: color,
          size: size,
        ),
      ),
    );
  }
}

/// 手柄自定义绘制器
///
/// 绘制水滴形状：上方一条竖线连接到下方的圆形。
/// 起始手柄的竖线在圆形右侧，结束手柄的竖线在圆形左侧。
class _HandlePainter extends CustomPainter {
  final HandleType type;
  final Color color;
  final double size;

  _HandlePainter({
    required this.type,
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final radius = size / 2;
    final lineWidth = 2.0;

    // 竖线的 x 坐标：起始手柄在中心，结束手柄也在中心
    final lineX = canvasSize.width / 2;

    // 绘制竖线（从顶部到圆心）
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = lineWidth;

    canvas.drawRect(
      Rect.fromLTWH(lineX - lineWidth / 2, 0, lineWidth, radius),
      linePaint,
    );

    // 绘制圆形
    final circleCenter = Offset(canvasSize.width / 2, radius + radius / 2);
    canvas.drawCircle(circleCenter, radius / 1.5, paint);
  }

  @override
  bool shouldRepaint(covariant _HandlePainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.size != size;
  }
}
