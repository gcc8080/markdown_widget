import 'package:flutter/material.dart';

/// 自定义选择模式的状态
enum SelectionState {
  /// 无选择，无菜单
  idle,

  /// 功能菜单已显示（长按后）
  contextMenuShown,

  /// 文本已选中，复制菜单显示
  textSelected,

  /// 正在拖动选择手柄
  draggingHandle,
}

/// 自定义选择模式中的菜单项
class SelectionMenuItem {
  /// 菜单项显示文本
  final String title;

  /// 菜单项图标（可选）
  final IconData? icon;

  /// 点击回调。参数为当前选中的文本内容（若有）和关闭菜单的回调。
  final void Function(String? selectedText, VoidCallback closeMenu) onPressed;

  const SelectionMenuItem({
    required this.title,
    this.icon,
    required this.onPressed,
  });
}

/// 表示跨元素的文本选择范围
class TextSelectionRange {
  /// 起始元素在 widget 列表中的索引
  final int startElementIndex;

  /// 起始元素内的字符偏移
  final int startOffset;

  /// 结束元素在 widget 列表中的索引
  final int endElementIndex;

  /// 结束元素内的字符偏移
  final int endOffset;

  const TextSelectionRange({
    required this.startElementIndex,
    required this.startOffset,
    required this.endElementIndex,
    required this.endOffset,
  });

  /// 是否跨越多个元素
  bool get isMultiElement => startElementIndex != endElementIndex;

  /// 确保 start 在 end 之前（规范化）。
  /// 如果起始位置在结束位置之后，则交换起始和结束。
  TextSelectionRange normalize() {
    if (startElementIndex > endElementIndex ||
        (startElementIndex == endElementIndex && startOffset > endOffset)) {
      return TextSelectionRange(
        startElementIndex: endElementIndex,
        startOffset: endOffset,
        endElementIndex: startElementIndex,
        endOffset: startOffset,
      );
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextSelectionRange &&
        other.startElementIndex == startElementIndex &&
        other.startOffset == startOffset &&
        other.endElementIndex == endElementIndex &&
        other.endOffset == endOffset;
  }

  @override
  int get hashCode => Object.hash(
        startElementIndex,
        startOffset,
        endElementIndex,
        endOffset,
      );

  @override
  String toString() =>
      'TextSelectionRange(start: [$startElementIndex:$startOffset], end: [$endElementIndex:$endOffset])';
}

/// Context Menu 自定义构建器类型。
/// [position] 为长按位置或选中区域中心位置。
/// [menuItems] 为完整的菜单项列表（默认项 + 自定义项）。
/// [selectedText] 为当前选中的文本（选中状态下才有值）。
/// [closeMenu] 为关闭菜单的回调。
typedef ContextMenuWidgetBuilder = Widget Function(
  Offset position,
  List<SelectionMenuItem> menuItems,
  String? selectedText,
  VoidCallback closeMenu,
);
