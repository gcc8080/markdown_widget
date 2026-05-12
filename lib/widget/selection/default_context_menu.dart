import 'package:flutter/material.dart';

import 'selection_models.dart';

/// 默认的 Context Menu 样式
///
/// 使用圆角矩形背景、水平排列菜单项，每个菜单项支持图标 + 文字。
/// 点击菜单项时执行对应回调并关闭菜单。
class DefaultContextMenu extends StatelessWidget {
  /// 菜单项列表
  final List<SelectionMenuItem> items;

  /// 当前选中的文本内容（若有）
  final String? selectedText;

  /// 关闭菜单的回调
  final VoidCallback onClose;

  const DefaultContextMenu({
    super.key,
    required this.items,
    this.selectedText,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) => _buildMenuItem(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuItem(SelectionMenuItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(4.0),
      onTap: () {
        item.onPressed(selectedText, onClose);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 18.0,
                color: Colors.black87,
              ),
              const SizedBox(width: 4.0),
            ],
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
