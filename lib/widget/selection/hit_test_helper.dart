import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/widget/span_node.dart';
import 'package:markdown_widget/widget/blocks/leaf/heading.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/blocks/container/list.dart';
import 'package:markdown_widget/widget/blocks/container/blockquote.dart';
import 'package:markdown_widget/widget/blocks/container/table.dart';
import 'package:markdown_widget/widget/blocks/leaf/horizontal_rules.dart';
import 'package:markdown_widget/widget/inlines/img.dart';

/// 命中测试辅助类，将全局坐标映射到 Markdown 元素和字符位置
class HitTestHelper {
  /// 根据全局坐标找到对应的 Widget 索引。
  /// 遍历 [elementKeys] 列表，使用 RenderBox 判断触摸点是否落在某个元素内。
  static int? findElementIndex(
    Offset globalPosition,
    List<GlobalKey> elementKeys,
  ) {
    for (int i = 0; i < elementKeys.length; i++) {
      final key = elementKeys[i];
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderBox) continue;
      if (!renderObject.hasSize) continue;

      final localPosition = renderObject.globalToLocal(globalPosition);
      final size = renderObject.size;

      if (localPosition.dx >= 0 &&
          localPosition.dx <= size.width &&
          localPosition.dy >= 0 &&
          localPosition.dy <= size.height) {
        return i;
      }
    }
    return null;
  }

  /// 根据全局坐标找到 RenderParagraph 中的字符偏移。
  /// 先获取元素的 RenderObject，然后遍历其 RenderObject 树找到 RenderParagraph，
  /// 最后调用 getPositionForOffset() 获取精确的字符偏移。
  static int? findTextOffset(
    Offset globalPosition,
    GlobalKey elementKey,
  ) {
    final renderObject = elementKey.currentContext?.findRenderObject();
    if (renderObject == null) return null;

    final renderParagraph = _findRenderParagraph(renderObject, globalPosition);
    if (renderParagraph == null) return null;

    final localPosition = renderParagraph.globalToLocal(globalPosition);
    final textPosition = renderParagraph.getPositionForOffset(localPosition);
    return textPosition.offset;
  }

  /// 判断指定索引的元素是否为可选中的文本元素。
  /// 表格（TableNode）、图片（ImageNode）、水平分割线（HrNode）为不可选中元素。
  static bool isSelectableElement(int elementIndex, List<SpanNode> nodes) {
    if (elementIndex < 0 || elementIndex >= nodes.length) return false;
    final node = nodes[elementIndex];
    return _isSelectableNode(node);
  }

  /// 获取指定元素的全部纯文本内容。
  /// 递归遍历 SpanNode 树，收集所有 TextNode 的文本。
  static String getElementPlainText(int elementIndex, List<SpanNode> nodes) {
    if (elementIndex < 0 || elementIndex >= nodes.length) return '';
    final node = nodes[elementIndex];
    return _extractPlainText(node);
  }

  /// 递归查找 RenderObject 树中包含指定全局坐标的 RenderParagraph。
  static RenderParagraph? _findRenderParagraph(
    RenderObject renderObject,
    Offset globalPosition,
  ) {
    if (renderObject is RenderParagraph) {
      return renderObject;
    }

    // 遍历子节点寻找包含触摸点的 RenderParagraph
    RenderParagraph? result;
    renderObject.visitChildren((child) {
      if (result != null) return;

      if (child is RenderBox && child.hasSize) {
        final localPosition = child.globalToLocal(globalPosition);
        final size = child.size;
        final isHit = localPosition.dx >= 0 &&
            localPosition.dx <= size.width &&
            localPosition.dy >= 0 &&
            localPosition.dy <= size.height;

        if (isHit) {
          if (child is RenderParagraph) {
            result = child;
          } else {
            result = _findRenderParagraph(child, globalPosition);
          }
        }
      } else {
        // For non-RenderBox children, still try to traverse
        result = _findRenderParagraph(child, globalPosition);
      }
    });

    // If no hit-tested child found, try to find any RenderParagraph in the tree
    if (result == null && renderObject is RenderParagraph) {
      result = renderObject;
    }

    return result;
  }

  /// 判断节点是否为可选中的文本节点。
  /// 非文本块级元素（表格、图片、水平分割线）不可选中。
  static bool _isSelectableNode(SpanNode node) {
    if (node is TableNode) return false;
    if (node is ImageNode) return false;
    if (node is HrNode) return false;

    // 文本类元素：标题、段落、列表项、引用块、代码块等
    if (node is HeadingNode) return true;
    if (node is ParagraphNode) return true;
    if (node is ListNode) return true;
    if (node is BlockquoteNode) return true;
    if (node is CodeBlockNode) return true;

    // 对于 ElementNode，检查是否包含文本子节点
    if (node is ElementNode) {
      return _hasTextContent(node);
    }

    // TextNode 本身是可选中的
    if (node is TextNode) return true;

    return false;
  }

  /// 检查 ElementNode 是否包含文本内容
  static bool _hasTextContent(ElementNode node) {
    for (final child in node.children) {
      if (child is TextNode && child.text.isNotEmpty) return true;
      if (child is ElementNode && _hasTextContent(child)) return true;
    }
    return false;
  }

  /// 递归提取 SpanNode 中的纯文本内容。
  static String _extractPlainText(SpanNode node) {
    if (node is CodeBlockNode) {
      // CodeBlockNode 直接存储了代码文本内容
      return node.content.trim();
    }

    if (node is TextNode) {
      return node.text;
    }

    if (node is ElementNode) {
      final buffer = StringBuffer();
      for (final child in node.children) {
        buffer.write(_extractPlainText(child));
      }
      return buffer.toString();
    }

    return '';
  }
}
