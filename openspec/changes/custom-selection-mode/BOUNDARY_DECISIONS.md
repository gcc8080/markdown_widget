# 边界情况决策记录

本文档记录了针对评审报告中提到的边界情况的明确决策。

## 决策日期
2026-06-03

## 决策背景
多个评审报告（Opus 4.8, Kimi 2.6, Qwen 3.7 Max）指出需求文档对表格、图片、嵌套元素等边界情况定义不清晰，可能导致实现阶段的歧义和返工。

## 边界情况决策

### 1. 表格（Table）

**决策**：选项 B - 单元格级选中

**规则**：
- 长按表格单元格 → 选中该单元格的内容（不是整个表格）
- 用户可以拖动选择句柄扩展到相邻单元格
- 复制时仅复制文本内容，不包含表格格式

**理由**：
- 表格可能很大，整表选中粒度太粗
- 单元格级选中提供更精细的控制
- 用户可以通过拖动句柄实现多单元格选择

**实现位置**：
- Spec: `specs/custom-selection/spec.md` - "Requirement: Handle table element selection"
- Design: `design.md` - "Decision 7: Element-Specific Selection Rules"
- Tasks: `tasks.md` - Task 7.4 - "Add table cell selection logic"

---

### 2. 图片（Image）

**决策**：选项 A - 不触发选择菜单

**规则**：
- 长按图片 → 不显示自定义选择菜单
- 图片保持默认行为（如果有）
- 包含图片的段落中，文本部分仍可正常选择

**理由**：
- 图片没有文本内容，"选取文字"语义不匹配
- 图片相关操作（保存、分享）可通过扩展菜单项实现（非核心功能）
- 保持简单，避免混淆

**实现位置**：
- Spec: `specs/custom-selection/spec.md` - "Requirement: Handle image element behavior"
- Design: `design.md` - "Decision 7: Element-Specific Selection Rules"
- Tasks: `tasks.md` - Task 7.4 - "Add image element exclusion logic"

---

### 3. 链接（Link）

**决策**：选项 A - 选中显示文本

**规则**：
- 长按链接 → 触发自定义选择菜单，选中链接的显示文本（不包含 URL）
- 点击（tap）链接 → 保持正常导航行为
- 复制时仅复制显示文本，不包含 URL

**理由**：
- 与段落内其他文本行为保持一致
- 用户通常需要复制的是显示文本，而非 URL
- 保留点击导航的直观交互

**实现位置**：
- Spec: `specs/custom-selection/spec.md` - "Requirement: Handle link element selection"
- Design: `design.md` - "Decision 7: Element-Specific Selection Rules"
- Tasks: `tasks.md` - Task 7.4 - "Add link display text selection logic"

---

### 4. 嵌套元素（Nested Elements）

**决策**：选项 B - 选中最内层块级元素

**规则**：
- 引用内的列表项：长按列表项 → 仅选中该列表项（不选中整个引用）
- 列表项内的代码块：长按代码块 → 仅选中代码块（不选中整个列表项）
- 引用内的段落：长按段落 → 仅选中该段落（不选中整个引用）
- 拖动句柄可以跨越嵌套边界扩展选择

**理由**：
- 用户点击哪里，选中哪里，符合直觉
- 最外层选中会导致意外的大范围选择
- 如果需要选中外层，用户可以拖动句柄扩展

**示例场景**：
```markdown
> - Item 1
> - Item 2
```
长按 Item 1 → 仅选中 "Item 1"，不选中整个引用块

**实现位置**：
- Spec: `specs/custom-selection/spec.md` - "Requirement: Handle nested element selection"
- Design: `design.md` - "Decision 7: Element-Specific Selection Rules"
- Tasks: `tasks.md` - Task 7.4 - "Add nested element (innermost) selection logic"

---

### 5. 行内元素（Inline Elements）

**决策**：选项 A - 选中所在段落

**规则**：
- 长按行内代码（`code`）→ 选中整个段落
- 长按粗体文本（**bold**）→ 选中整个段落
- 长按斜体文本（*italic*）→ 选中整个段落
- 拖动句柄可以调整选择范围，包括或排除行内格式化文本

**理由**：
- 行内元素粒度太细，不适合作为独立选中单元
- 段落是自然的文本块边界
- 行内格式是段落内容的一部分，不应单独分离

**实现位置**：
- Spec: `specs/custom-selection/spec.md` - "Requirement: Handle inline element selection"
- Design: `design.md` - "Decision 7: Element-Specific Selection Rules"
- Tasks: `tasks.md` - Task 7.4 - "Add inline element (paragraph) selection logic"

---

### 6. 水平线和非内容元素（Horizontal Rule, Separators）

**决策**：选项 A - 不参与选择

**规则**：
- 长按水平线（`---`）→ 无反应，不显示菜单
- 长按元素之间的空白区域 → 无反应，不显示菜单
- 复选框（checkbox）→ 保持勾选/取消行为，复选框本身不触发选择菜单
- 任务列表项的文本部分 → 正常触发选择菜单

**理由**：
- 水平线是视觉元素，无实质文本内容
- 用户很少需要复制分隔符
- 复选框是交互元素，有自己的行为逻辑

**实现位置**：
- Spec: `specs/custom-selection/spec.md` - "Requirement: Handle non-selectable elements"
- Design: `design.md` - "Decision 7: Element-Specific Selection Rules"
- Tasks: `tasks.md` - Task 7.4 - "Add non-content element exclusion logic"

---

## 决策影响

### 对规范（Spec）的影响
- 添加了 6 个新的 Requirement，共 21 个新的 Scenario
- 覆盖了所有主要的边界情况
- 每个场景都有明确的 WHEN/THEN 断言，可直接转化为测试用例

### 对设计（Design）的影响
- 添加了 Decision 7，记录元素特定选择规则的设计理由
- 明确了实现时的优先级和权衡

### 对任务（Tasks）的影响
- 在 Task 7.4 中添加了 6 个子任务，对应 6 种边界情况
- 在 Task 12.4 中添加了相应的测试任务

### 对提案（Proposal）的影响
- 添加了"Element-Specific Selection Behavior"部分
- 为用户提供了清晰的功能预期

---

## 未来扩展可能性

虽然当前决策已经覆盖了主要场景，但以下情况可能在未来需要支持：

1. **表格行级选中**：长按行号区域 → 选中整行
2. **图片操作菜单**：通过扩展菜单项支持"保存图片"、"复制图片 URL"
3. **链接 URL 复制**：通过扩展菜单项支持"复制链接地址"
4. **多元素选中**：跨越多个块级元素的拖动选择（当前支持拖动扩展）

这些扩展不影响当前的核心设计，可以在后续版本中增量添加。

---

## 验证方式

每个边界情况的决策都已转化为：
1. **Spec 中的 Requirement 和 Scenario** - 定义"做什么"
2. **Design 中的 Decision** - 解释"为什么这样做"
3. **Tasks 中的实现任务** - 指导"如何实现"
4. **测试任务** - 确保"实现正确"

通过这种四层映射，确保决策被完整、准确地执行。
