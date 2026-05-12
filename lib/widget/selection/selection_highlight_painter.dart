import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:markdown_widget/widget/selection/selection_models.dart';

/// 选中高亮绘制器
///
/// 使用 [CustomPainter] 在文本下方绘制半透明高亮背景。
/// 通过 [RenderParagraph.getBoxesForSelection()] 获取选中文本的矩形区域列表，
/// 对选择范围内的每个元素分别绘制高亮。
///
/// 支持：
/// - 单元素选中高亮
/// - 跨元素连续选中高亮
/// - 自定义高亮颜色
class SelectionHighlightPainter extends CustomPainter {
  /// 当前选择范围
  final TextSelectionRange? selectionRange;

  /// 所有 Markdown Widget 的 GlobalKey 列表，用于查找 RenderParagraph
  final List<GlobalKey> elementKeys;

  /// 高亮颜色，默认为半透明蓝色
  final Color highlightColor;

  /// 绘制器所在 Widget 的 BuildContext，用于坐标转换
  final BuildContext? paintContext;

  SelectionHighlightPainter({
    required this.selectionRange,
    required this.elementKeys,
    this.highlightColor = const Color(0x4D2196F3), // Colors.blue.withOpacity(0.3)
    this.paintContext,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRange == null) return;
    if (paintContext == null) return;

    final range = selectionRange!;
    final paint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    // 获取当前 painter 所在 Widget 的 RenderBox，用于坐标转换
    final paintRenderObject = paintContext!.findRenderObject();
    if (paintRenderObject == null || paintRenderObject is! RenderBox) return;

    // 遍历选择范围内的每个元素，分别绘制高亮
    for (int i = range.startElementIndex; i <= range.endElementIndex; i++) {
      if (i < 0 || i >= elementKeys.length) continue;

      final key = elementKeys[i];
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject == null) continue;

      // 在元素的 RenderObject 树中查找 RenderParagraph
      final renderParagraph = _findRenderParagraph(renderObject);
      if (renderParagraph == null) continue;

      // 确定该元素内的选择范围
      final textSelection = _getTextSelectionForElement(i, range, renderParagraph);
      if (textSelection == null) continue;

      // 获取选中文本的矩形区域列表
      final boxes = renderParagraph.getBoxesForSelection(textSelection);
      if (boxes.isEmpty) continue;

      // 将 RenderParagraph 的本地坐标转换为 painter 的本地坐标
      final paragraphToLocal = _getOffsetToLocal(renderParagraph, paintRenderObject);
      if (paragraphToLocal == null) continue;

      // 绘制每个矩形区域
      for (final box in boxes) {
        final rect = Rect.fromLTRB(
          box.left + paragraphToLocal.dx,
          box.top + paragraphToLocal.dy,
          box.right + paragraphToLocal.dx,
          box.bottom + paragraphToLocal.dy,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SelectionHighlightPainter oldDelegate) {
    return selectionRange != oldDelegate.selectionRange ||
        highlightColor != oldDelegate.highlightColor ||
        elementKeys != oldDelegate.elementKeys;
  }

  /// 获取指定元素在选择范围内的 [TextSelection]。
  ///
  /// - 对于起始元素：从 startOffset 到文本末尾
  /// - 对于结束元素：从文本开头到 endOffset
  /// - 对于中间元素：选中全部文本
  /// - 对于单元素选择：从 startOffset 到 endOffset
  TextSelection? _getTextSelectionForElement(
    int elementIndex,
    TextSelectionRange range,
    RenderParagraph renderParagraph,
  ) {
    final textLength = renderParagraph.text.toPlainText().length;
    if (textLength == 0) return null;

    int baseOffset;
    int extentOffset;

    if (range.startElementIndex == range.endElementIndex) {
      // 单元素选择
      baseOffset = range.startOffset.clamp(0, textLength);
      extentOffset = range.endOffset.clamp(0, textLength);
    } else if (elementIndex == range.startElementIndex) {
      // 起始元素：从 startOffset 到末尾
      baseOffset = range.startOffset.clamp(0, textLength);
      extentOffset = textLength;
    } else if (elementIndex == range.endElementIndex) {
      // 结束元素：从开头到 endOffset
      baseOffset = 0;
      extentOffset = range.endOffset.clamp(0, textLength);
    } else {
      // 中间元素：全部文本
      baseOffset = 0;
      extentOffset = textLength;
    }

    if (baseOffset == extentOffset) return null;

    return TextSelection(baseOffset: baseOffset, extentOffset: extentOffset);
  }

  /// 递归查找 RenderObject 树中的第一个 RenderParagraph。
  static RenderParagraph? _findRenderParagraph(RenderObject renderObject) {
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

  /// 计算从 [source] RenderBox 到 [target] RenderBox 的坐标偏移。
  ///
  /// 返回值表示 source 的原点在 target 坐标系中的位置。
  Offset? _getOffsetToLocal(RenderBox source, RenderBox target) {
    try {
      final sourceGlobal = source.localToGlobal(Offset.zero);
      final targetLocal = target.globalToLocal(sourceGlobal);
      return targetLocal;
    } catch (_) {
      return null;
    }
  }
}
