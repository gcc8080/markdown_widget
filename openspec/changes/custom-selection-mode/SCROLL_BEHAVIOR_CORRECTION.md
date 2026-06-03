# 滚动行为修正说明

## 修正日期
2026-06-03

## 修正原因
用户反馈原设计中"滚动时菜单保持显示"与需求不符。

## 正确的滚动行为

### 用户需求
当用户在**已选中文本**的状态下滚动页面时：
1. **滚动过程中**：菜单消失
2. **选择区域和拖动句柄**：保持显示
3. **停止滚动后**：菜单重新出现在选择区域上方

### 设计理由
- **菜单消失**：避免滚动时菜单遮挡内容，提供更好的浏览体验
- **句柄保留**：让用户清楚知道当前仍有选中状态
- **停止后重现**：方便用户继续操作（复制、扩展等）

### 类似行为参考
这个行为与"拖动选择句柄"时的行为一致：
- **拖动时**：菜单隐藏
- **拖动结束**：菜单重新出现

## 已修正的文档

### 1. 需求文档（docs/自定义选择模式需求文档修订版.md）

#### 修正位置 1：交互流程图
```diff
+ ├─ 滚动页面（选中状态）→ 菜单消失
+                       选择区域和句柄保留
+                       停止滚动后菜单重新出现
```

#### 修正位置 2：菜单生命周期表格
```diff
- | 滚动页面 | 菜单保持显示（跟随内容） |
+ | 滚动页面 | 菜单消失，选择区域和句柄保留，停止滚动后菜单重新出现 |
```

#### 修正位置 3：滚动手势说明
```diff
- 选中状态下滚动：选择状态保持，菜单保持显示
+ 选中状态下滚动：菜单消失，选择区域和句柄保留
+ 停止滚动后：菜单在选择区域上方重新出现
```

#### 修正位置 4：验收标准
```diff
- AC-10 | 选中状态下滚动页面，菜单位置正确或自动关闭，不崩溃
+ AC-10 | 选中状态下滚动页面，菜单消失，选择区域和句柄保留，停止滚动后菜单重新出现
```

### 2. OpenSpec Proposal（openspec/changes/custom-selection-mode/proposal.md）

```diff
- Scroll behavior: Selection and handles persist when scrolling in/out of view
+ Scroll behavior: Selection and handles persist when scrolling; menu hides during scroll and reappears when scrolling stops
```

### 3. OpenSpec Spec（openspec/changes/custom-selection-mode/specs/custom-selection/spec.md）

#### 修正了 Requirement: Persist selection during scroll

**原规范**：
```
#### Scenario: Scroll with active selection
- WHEN user scrolls the page while selection is active
- THEN selected area remains selected
- AND selection handles remain visible
- AND menu remains visible  ← 错误
```

**修正后**：
```
#### Scenario: Scroll with active selection
- WHEN user scrolls the page while selection is active
- THEN selected area remains selected
- AND selection handles remain visible
- AND menu disappears during scroll  ← 正确

#### Scenario: Stop scrolling with active selection  ← 新增
- WHEN user stops scrolling and selection is still active
- THEN menu reappears above selected area
- AND selection and handles remain visible
```

## 实现要点

### 技术实现建议

1. **监听滚动事件**：
```dart
ScrollController _scrollController;

_scrollController.addListener(() {
  if (_isScrolling) {
    _hideMenu();
  }
});
```

2. **检测滚动停止**：
```dart
Timer? _scrollEndTimer;

void _onScroll() {
  _scrollEndTimer?.cancel();
  _hideMenu();
  
  _scrollEndTimer = Timer(Duration(milliseconds: 200), () {
    // 200ms 内没有新的滚动事件，认为滚动停止
    if (_isInSelectionMode) {
      _showMenu();
    }
  });
}
```

3. **保持选择状态**：
```dart
// 隐藏菜单时不清除选择状态
void _hideMenu() {
  _menuOverlay?.remove();
  _menuOverlay = null;
  // 注意：不调用 _clearSelection()
}
```

## 状态机更新

```
选中状态 + 菜单显示
    ↓
  开始滚动
    ↓
选中状态 + 菜单隐藏 + 句柄显示
    ↓
  停止滚动
    ↓
选中状态 + 菜单重新显示 + 句柄显示
```

## 验证检查清单

- [ ] 选中文本后开始滚动，菜单立即消失
- [ ] 滚动过程中，选择区域高亮保持
- [ ] 滚动过程中，拖动句柄保持显示
- [ ] 停止滚动后 200ms 内，菜单重新出现
- [ ] 菜单出现位置在当前选择区域上方
- [ ] 快速滚动不会导致多个菜单叠加
- [ ] 滚动到选择区域不可见时，行为仍然正确

## 相关文档

- 需求文档：`docs/自定义选择模式需求文档修订版.md`
- Proposal：`openspec/changes/custom-selection-mode/proposal.md`
- Spec：`openspec/changes/custom-selection-mode/specs/custom-selection/spec.md`
- Design：`openspec/changes/custom-selection-mode/design.md`（无需修改）
- Tasks：`openspec/changes/custom-selection-mode/tasks.md`（现有任务已覆盖）
