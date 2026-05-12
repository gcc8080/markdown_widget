import 'package:flutter/material.dart';
import 'package:markdown_widget/widget/selection/hit_test_helper.dart';
import 'package:markdown_widget/widget/selection/selection_models.dart';
import 'package:markdown_widget/widget/span_node.dart';

/// 选择状态管理器
///
/// 管理自定义选择模式的完整状态机，包括：
/// - 状态转换（idle → contextMenuShown → textSelected → draggingHandle）
/// - 命中测试（将触摸坐标映射到 Markdown 元素）
/// - 选择范围管理（元素级选中、手柄拖动调整）
/// - 手柄角色交换（当起始手柄越过结束手柄时）
class SelectionManager extends ChangeNotifier {
  /// 所有 Markdown Widget 的 GlobalKey 列表，用于命中测试
  final List<GlobalKey> elementKeys;

  /// 所有 Markdown 元素对应的 SpanNode 列表，用于文本提取和可选性判断
  final List<SpanNode> spanNodes;

  SelectionManager({
    required this.elementKeys,
    required this.spanNodes,
  });

  /// 当前选择状态
  SelectionState _state = SelectionState.idle;

  /// 当前选中的文本范围
  TextSelectionRange? _selectionRange;

  /// 当前长按命中的元素索引（用于 contextMenuShown 状态）
  int? _hitElementIndex;

  /// 当前选择状态
  SelectionState get state => _state;

  /// 当前选中的文本范围
  TextSelectionRange? get selectionRange => _selectionRange;

  /// 当前长按命中的元素索引
  int? get hitElementIndex => _hitElementIndex;

  /// 当前选中的纯文本内容
  String? get selectedText {
    if (_selectionRange == null) return null;
    return getPlainText();
  }

  // ---------------------------------------------------------------------------
  // 状态转换方法
  // ---------------------------------------------------------------------------

  /// 处理长按事件：idle → contextMenuShown
  ///
  /// 执行命中测试，如果命中了有效元素则转换到 contextMenuShown 状态。
  /// 返回命中的元素索引，如果未命中任何元素则返回 null。
  int? onLongPress(Offset globalPosition) {
    final elementIndex = hitTestElement(globalPosition);
    if (elementIndex != null) {
      _hitElementIndex = elementIndex;
      _transitionTo(SelectionState.contextMenuShown);
    }
    return elementIndex;
  }

  /// 处理菜单外部点击：contextMenuShown → idle 或 textSelected → idle
  void onOutsideTap() {
    if (_state == SelectionState.contextMenuShown ||
        _state == SelectionState.textSelected) {
      clearSelection();
    }
  }

  /// 处理「选取文字」菜单项点击：contextMenuShown → textSelected
  ///
  /// 如果当前命中的元素是可选中的文本元素，则选中该元素全部文本。
  /// 如果是非文本元素，则不执行选中操作，回到 idle 状态。
  void onSelectTextMenuItemClicked() {
    if (_state != SelectionState.contextMenuShown) return;
    if (_hitElementIndex == null) {
      _transitionTo(SelectionState.idle);
      return;
    }
    selectElement(_hitElementIndex!);
  }

  /// 处理其他菜单项点击：contextMenuShown → idle
  void onOtherMenuItemClicked() {
    if (_state == SelectionState.contextMenuShown) {
      _transitionTo(SelectionState.idle);
      _hitElementIndex = null;
    }
  }

  /// 处理手柄拖动开始：textSelected → draggingHandle
  void onHandleDragStart() {
    if (_state == SelectionState.textSelected) {
      _transitionTo(SelectionState.draggingHandle);
    }
  }

  /// 处理手柄拖动结束：draggingHandle → textSelected
  void onHandleDragEnd() {
    if (_state == SelectionState.draggingHandle) {
      _transitionTo(SelectionState.textSelected);
    }
  }

  /// 处理再次长按：textSelected → contextMenuShown
  void onLongPressAgain(Offset globalPosition) {
    if (_state == SelectionState.textSelected) {
      final elementIndex = hitTestElement(globalPosition);
      if (elementIndex != null) {
        _hitElementIndex = elementIndex;
        _transitionTo(SelectionState.contextMenuShown);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 命中测试
  // ---------------------------------------------------------------------------

  /// 执行命中测试，返回长按位置对应的元素索引。
  ///
  /// 使用 [HitTestHelper.findElementIndex] 将全局坐标映射到 Widget 索引。
  int? hitTestElement(Offset globalPosition) {
    return HitTestHelper.findElementIndex(globalPosition, elementKeys);
  }

  // ---------------------------------------------------------------------------
  // 选择操作
  // ---------------------------------------------------------------------------

  /// 选中指定索引的整个 Markdown 元素。
  ///
  /// 如果元素是可选中的文本元素（标题、段落、列表项、引用块、代码块），
  /// 则选中该元素的全部纯文本内容。
  /// 如果元素是非文本元素（表格、图片、水平分割线），则不执行选中操作。
  void selectElement(int elementIndex) {
    if (elementIndex < 0 || elementIndex >= spanNodes.length) {
      _transitionTo(SelectionState.idle);
      return;
    }

    // 检查元素是否可选中（非文本元素不可选中）
    if (!HitTestHelper.isSelectableElement(elementIndex, spanNodes)) {
      _transitionTo(SelectionState.idle);
      _hitElementIndex = null;
      return;
    }

    // 获取元素的纯文本内容长度
    final plainText =
        HitTestHelper.getElementPlainText(elementIndex, spanNodes);
    if (plainText.isEmpty) {
      _transitionTo(SelectionState.idle);
      _hitElementIndex = null;
      return;
    }

    // 选中整个元素的文本
    _selectionRange = TextSelectionRange(
      startElementIndex: elementIndex,
      startOffset: 0,
      endElementIndex: elementIndex,
      endOffset: plainText.length,
    );

    _transitionTo(SelectionState.textSelected);
  }

  /// 更新选择范围的起始边界。
  ///
  /// 在手柄拖动过程中调用，将起始边界更新到手指当前所在的字符位置。
  /// 支持跨元素选择：当手指移动到其他元素时，更新 startElementIndex。
  /// 实现手柄角色交换：如果起始位置越过结束位置，则交换两者角色。
  /// 当手柄拖出可视区域时，将选择边界限制在首/末元素的首/末字符。
  void updateSelectionStart(Offset globalPosition) {
    if (_selectionRange == null) return;

    int? elementIndex = hitTestElement(globalPosition);
    int? textOffset;

    if (elementIndex == null) {
      // 手柄拖出可视区域：clamp 到首/末元素边界
      final clamped = _clampToVisibleBoundary(globalPosition);
      if (clamped == null) return;
      elementIndex = clamped.elementIndex;
      textOffset = clamped.offset;
    } else {
      // 检查目标元素是否可选中
      if (!HitTestHelper.isSelectableElement(elementIndex, spanNodes)) return;

      // 获取字符偏移
      textOffset = _findTextOffsetForElement(globalPosition, elementIndex);
      if (textOffset == null) return;
    }

    // 创建新的选择范围（起始位置更新）
    final newRange = TextSelectionRange(
      startElementIndex: elementIndex,
      startOffset: textOffset,
      endElementIndex: _selectionRange!.endElementIndex,
      endOffset: _selectionRange!.endOffset,
    );

    // 应用手柄角色交换逻辑并确保至少选中 1 个字符
    _selectionRange = _normalizeWithMinimumSelection(newRange);
    notifyListeners();
  }

  /// 更新选择范围的结束边界。
  ///
  /// 在手柄拖动过程中调用，将结束边界更新到手指当前所在的字符位置。
  /// 支持跨元素选择：当手指移动到其他元素时，更新 endElementIndex。
  /// 实现手柄角色交换：如果结束位置越过起始位置，则交换两者角色。
  /// 当手柄拖出可视区域时，将选择边界限制在首/末元素的首/末字符。
  void updateSelectionEnd(Offset globalPosition) {
    if (_selectionRange == null) return;

    int? elementIndex = hitTestElement(globalPosition);
    int? textOffset;

    if (elementIndex == null) {
      // 手柄拖出可视区域：clamp 到首/末元素边界
      final clamped = _clampToVisibleBoundary(globalPosition);
      if (clamped == null) return;
      elementIndex = clamped.elementIndex;
      textOffset = clamped.offset;
    } else {
      // 检查目标元素是否可选中
      if (!HitTestHelper.isSelectableElement(elementIndex, spanNodes)) return;

      // 获取字符偏移
      textOffset = _findTextOffsetForElement(globalPosition, elementIndex);
      if (textOffset == null) return;
    }

    // 创建新的选择范围（结束位置更新）
    final newRange = TextSelectionRange(
      startElementIndex: _selectionRange!.startElementIndex,
      startOffset: _selectionRange!.startOffset,
      endElementIndex: elementIndex,
      endOffset: textOffset,
    );

    // 应用手柄角色交换逻辑并确保至少选中 1 个字符
    _selectionRange = _normalizeWithMinimumSelection(newRange);
    notifyListeners();
  }

  /// 清除选择状态，回到 idle。
  void clearSelection() {
    _selectionRange = null;
    _hitElementIndex = null;
    _transitionTo(SelectionState.idle);
  }

  /// 获取选中文本的纯文本内容（不含 Markdown 标记）。
  ///
  /// 遍历选择范围内的所有元素，提取纯文本并根据偏移量截取。
  String getPlainText() {
    if (_selectionRange == null) return '';

    final range = _selectionRange!;
    final buffer = StringBuffer();

    for (int i = range.startElementIndex; i <= range.endElementIndex; i++) {
      if (i < 0 || i >= spanNodes.length) continue;

      final elementText = HitTestHelper.getElementPlainText(i, spanNodes);
      if (elementText.isEmpty) continue;

      if (range.startElementIndex == range.endElementIndex) {
        // 单元素选择：截取 startOffset 到 endOffset
        final start = range.startOffset.clamp(0, elementText.length);
        final end = range.endOffset.clamp(0, elementText.length);
        buffer.write(elementText.substring(start, end));
      } else if (i == range.startElementIndex) {
        // 跨元素选择的第一个元素：从 startOffset 到末尾
        final start = range.startOffset.clamp(0, elementText.length);
        buffer.write(elementText.substring(start));
      } else if (i == range.endElementIndex) {
        // 跨元素选择的最后一个元素：从开头到 endOffset
        final end = range.endOffset.clamp(0, elementText.length);
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(elementText.substring(0, end));
      } else {
        // 跨元素选择的中间元素：全部文本
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(elementText);
      }
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 私有辅助方法
  // ---------------------------------------------------------------------------

  /// 当手柄拖出所有可见元素区域时，将选择边界 clamp 到首/末元素。
  ///
  /// 判断逻辑：
  /// - 如果触摸位置在所有元素的上方 → clamp 到第一个可选中元素的 offset 0
  /// - 如果触摸位置在所有元素的下方 → clamp 到最后一个可选中元素的 text.length
  /// - 如果无法确定方向（例如所有 RenderObject 都为 null）→ 返回 null
  _ClampedPosition? _clampToVisibleBoundary(Offset globalPosition) {
    if (elementKeys.isEmpty || spanNodes.isEmpty) return null;

    // 找到第一个和最后一个有效的可选中元素
    int? firstSelectableIndex;
    int? lastSelectableIndex;

    for (int i = 0; i < elementKeys.length; i++) {
      if (i >= spanNodes.length) break;
      if (!HitTestHelper.isSelectableElement(i, spanNodes)) continue;

      final key = elementKeys[i];
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderBox) continue;
      if (!renderObject.hasSize) continue;

      firstSelectableIndex ??= i;
      lastSelectableIndex = i;
    }

    if (firstSelectableIndex == null || lastSelectableIndex == null) {
      return null;
    }

    // 获取第一个可选中元素的顶部 y 坐标
    final firstKey = elementKeys[firstSelectableIndex];
    final firstRenderObject = firstKey.currentContext?.findRenderObject();
    if (firstRenderObject == null || firstRenderObject is! RenderBox) {
      return null;
    }
    final firstTopLeft = firstRenderObject.localToGlobal(Offset.zero);

    // 获取最后一个可选中元素的底部 y 坐标
    final lastKey = elementKeys[lastSelectableIndex];
    final lastRenderObject = lastKey.currentContext?.findRenderObject();
    if (lastRenderObject == null || lastRenderObject is! RenderBox) {
      return null;
    }
    final lastTopLeft = lastRenderObject.localToGlobal(Offset.zero);
    final lastBottom = lastTopLeft.dy + lastRenderObject.size.height;

    // 判断触摸位置相对于可见元素区域的方向
    if (globalPosition.dy < firstTopLeft.dy) {
      // 触摸位置在所有元素上方 → clamp 到第一个可选中元素的 offset 0
      return _ClampedPosition(
        elementIndex: firstSelectableIndex,
        offset: 0,
      );
    } else if (globalPosition.dy > lastBottom) {
      // 触摸位置在所有元素下方 → clamp 到最后一个可选中元素的 text.length
      final lastText = HitTestHelper.getElementPlainText(
          lastSelectableIndex, spanNodes);
      return _ClampedPosition(
        elementIndex: lastSelectableIndex,
        offset: lastText.length,
      );
    }

    // 触摸位置在元素区域内但未命中任何元素（可能在元素间的间隙中）
    // 找到最近的可选中元素
    return _findNearestSelectableElement(globalPosition);
  }

  /// 在元素间隙中找到最近的可选中元素。
  ///
  /// 当触摸位置在可见区域内但未命中任何元素时（例如在两个元素之间的间隙），
  /// 找到垂直距离最近的可选中元素，并根据位置 clamp 到该元素的首/末字符。
  _ClampedPosition? _findNearestSelectableElement(Offset globalPosition) {
    double minDistance = double.infinity;
    int? nearestIndex;
    bool isAboveNearest = false;

    for (int i = 0; i < elementKeys.length; i++) {
      if (i >= spanNodes.length) break;
      if (!HitTestHelper.isSelectableElement(i, spanNodes)) continue;

      final key = elementKeys[i];
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderBox) continue;
      if (!renderObject.hasSize) continue;

      final topLeft = renderObject.localToGlobal(Offset.zero);
      final bottom = topLeft.dy + renderObject.size.height;

      // 计算触摸点到元素的垂直距离
      double distance;
      bool above;
      if (globalPosition.dy < topLeft.dy) {
        distance = topLeft.dy - globalPosition.dy;
        above = true;
      } else if (globalPosition.dy > bottom) {
        distance = globalPosition.dy - bottom;
        above = false;
      } else {
        // 触摸点在元素的垂直范围内（但水平方向未命中）
        distance = 0;
        above = false;
      }

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
        isAboveNearest = above;
      }
    }

    if (nearestIndex == null) return null;

    // 如果触摸点在最近元素上方，clamp 到该元素的 offset 0
    // 如果在下方或水平未命中，clamp 到该元素的 text.length
    if (isAboveNearest) {
      return _ClampedPosition(elementIndex: nearestIndex, offset: 0);
    } else {
      final text =
          HitTestHelper.getElementPlainText(nearestIndex, spanNodes);
      return _ClampedPosition(
        elementIndex: nearestIndex,
        offset: text.length,
      );
    }
  }

  /// 状态转换，通知监听者。
  void _transitionTo(SelectionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// 获取指定元素中的字符偏移。
  ///
  /// 使用 HitTestHelper.findTextOffset 进行精确的字符级命中测试。
  /// 如果无法获取精确偏移（例如元素未渲染），则根据触摸位置估算。
  int? _findTextOffsetForElement(Offset globalPosition, int elementIndex) {
    if (elementIndex < 0 || elementIndex >= elementKeys.length) return null;

    final key = elementKeys[elementIndex];
    final offset = HitTestHelper.findTextOffset(globalPosition, key);

    if (offset != null) return offset;

    // 如果无法获取精确偏移，根据触摸位置相对于元素的位置估算
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return null;

    final localPosition = renderObject.globalToLocal(globalPosition);
    final elementText =
        HitTestHelper.getElementPlainText(elementIndex, spanNodes);
    if (elementText.isEmpty) return 0;

    // 如果触摸点在元素上方，返回 0；在下方，返回文本长度
    if (localPosition.dy < 0) return 0;
    if (localPosition.dy > renderObject.size.height) {
      return elementText.length;
    }

    // 默认返回文本中间位置
    return elementText.length ~/ 2;
  }

  /// 规范化选择范围并确保至少选中 1 个字符。
  ///
  /// 实现手柄角色交换逻辑（Requirement 6.7）：
  /// 如果起始位置在结束位置之后，则交换两者，使起始手柄始终位于前端。
  /// 同时确保选中区域至少包含 1 个字符。
  TextSelectionRange _normalizeWithMinimumSelection(TextSelectionRange range) {
    // 先规范化（确保 start 在 end 之前）
    final normalized = range.normalize();

    // 确保至少选中 1 个字符
    if (normalized.startElementIndex == normalized.endElementIndex &&
        normalized.startOffset >= normalized.endOffset) {
      final elementText = HitTestHelper.getElementPlainText(
          normalized.startElementIndex, spanNodes);
      final maxOffset = elementText.length;

      // 尝试将 endOffset 设为 startOffset + 1
      if (normalized.startOffset < maxOffset) {
        return TextSelectionRange(
          startElementIndex: normalized.startElementIndex,
          startOffset: normalized.startOffset,
          endElementIndex: normalized.endElementIndex,
          endOffset: (normalized.startOffset + 1).clamp(0, maxOffset),
        );
      } else {
        // startOffset 已经在末尾，将 startOffset 前移一位
        return TextSelectionRange(
          startElementIndex: normalized.startElementIndex,
          startOffset: (normalized.endOffset - 1).clamp(0, maxOffset),
          endElementIndex: normalized.endElementIndex,
          endOffset: normalized.endOffset.clamp(1, maxOffset),
        );
      }
    }

    return normalized;
  }
}

/// 辅助类：表示 clamp 到边界后的位置信息
class _ClampedPosition {
  /// 元素索引
  final int elementIndex;

  /// 字符偏移
  final int offset;

  const _ClampedPosition({
    required this.elementIndex,
    required this.offset,
  });
}
