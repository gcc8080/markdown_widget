## Context

`markdown_widget` 是一个 Flutter Markdown 渲染库，当前使用 Flutter 原生 `SelectionArea` 包裹 `ListView`/`Column` 实现文本选择。`SelectionArea` 内部通过 `SelectableRegion` 管理选择状态，包括长按手势、选择手柄（handles）、上下文菜单（toolbar）和选区高亮。

当前架构的限制在于 `SelectableRegionState` 的核心方法（`_selectStartTo`、`_selectEndTo`、`_selectable`）均为私有，无法从外部进行编程式选择或修改手势行为。

目标 Flutter 版本：3.27.4，Dart SDK 3.6.2，`markdown` 包版本 7.1.1。

### 利益相关方

- **库使用者**：需要自定义长按菜单和按 Markdown 块级元素选择文本
- **库维护者**：需要保持向后兼容和可维护性

## Goals / Non-Goals

**Goals:**
- 提供两阶段自定义选择交互（长按菜单 → 选取文字菜单），菜单 UI 完全由使用者控制
- 按 Markdown 块级元素智能初始选中（标题、段落、列表项、代码块等）
- 暴露元素元数据（类型、纯文本、原始源码、坐标）给菜单构建器
- 同时支持 `MarkdownWidget`（ListView）和 `MarkdownBlock`（Column）
- 保持未配置时的完全向后兼容
- 第一阶段支持移动端（Android/iOS）

**Non-Goals:**
- 放大镜效果（Magnifier）— 暂不实现
- 桌面端/Web 端支持 — 后续迭代
- 库内置默认菜单 UI — 菜单完全由使用者自定义
- 表格单元格级别选中 — 第一版降级为整表选中
- 跨 `MarkdownWidget` 实例的选择

## Decisions

### 决策 1：CustomSelectableRegion 基于 Flutter SDK 源码改造

**选择**：从 Flutter 3.27.4 的 `SelectableRegion` 源码中提取核心逻辑，创建 `CustomSelectableRegion`。

**理由**：
- `SelectableRegionState` 的 `_selectable`、`_selectStartTo`、`_selectEndTo` 等方法为私有，无法通过继承或组合访问
- 需要替换默认长按行为（原版：长按→选一个词；自定义：长按→回调外部）
- 需要暴露编程式选择 API（`selectRange`、`showHandles`）

**备选方案**：
- **A: 使用 `contextMenuBuilder` + `onSelectionChanged`**：无法阻止原版的"长按立即选词"行为，不满足需求
- **B: 通过 `package:flutter/src/...` 导入私有 API**：不稳定且不推荐
- **C（选中）: 复制源码并最小化修改**：完全可控，但需与 Flutter 版本同步

**最小化修改范围**：仅修改手势处理层和 API 暴露层，保留原版的 Handle 渲染、选区高亮、ScrollNotifier 等核心逻辑。

### 决策 2：手势分层 — 统一由 CustomSelectableRegion 处理

**选择**：所有手势由 `CustomSelectableRegion` 统一处理，不在每个元素上单独添加 `GestureDetector`。

**理由**：
- 避免双层 `GestureDetector`（CustomSelectableRegion + SelectableElementWrapper）的手势竞争
- `CustomSelectableRegion` 在长按回调中做 hit-test，反查命中的元素及其元数据
- 元素元数据通过 `InheritedWidget` 或 Widget key 的方式附加到每个块级 Widget 上

**备选方案**：
- **A: SelectableElementWrapper 外层 GestureDetector**：实现简单但手势冲突风险高，特别是选中态下拖动 handle 时
- **B（选中）: 统一手势 + hit-test 反查**：无手势冲突，架构更清晰

### 决策 3：sourceText 通过原始行号匹配提取

**选择**：利用 markdown AST 顶层节点与原始文本行的顺序对应关系，在 `buildWidgetsWithInfo()` 中跟踪行号区间，从原始 `data` 中截取对应行作为 `sourceText`。

**理由**：
- `markdown` 7.1.1 包的 AST 节点（`m.Element`）不保留源码行号
- `textContent` 只返回递归拼接的纯文本，丢失 markdown 语法标记
- 但 `document.parseLines(lines)` 按顺序消费行，顶层块级元素与行的对应关系可推算

**实现思路**：
1. 在 `parseLines` 前保留原始行列表
2. 通过比较每个顶层节点的 `textContent` 与原始行的文本内容，确定行号区间
3. 从原始行中截取对应区间作为 `sourceText`

**风险**：空行和多行元素（代码块、表格）的边界判定需要特殊处理。

### 决策 4：Overlay 管理封装在 CustomSelectableRegion 内部

**选择**：将菜单的 Overlay 生命周期管理封装在 `CustomSelectableRegion`（StatefulWidget）内部，而非 `MarkdownWidget`/`MarkdownBlock` 中。

**理由**：
- `MarkdownBlock` 当前是 StatelessWidget，改为 StatefulWidget 是不必要的破坏
- `CustomSelectableRegion` 已经是 StatefulWidget，天然适合管理 Overlay 和选择状态
- 状态机（空闲→阶段1→阶段2）的逻辑集中在一处，避免分散

### 决策 5：MarkdownConfig 构造函数扩展（非 WidgetConfig 体系）

**选择**：`customSelectionConfig` 作为 `MarkdownConfig` 构造函数的独立命名参数，不纳入 `WidgetConfig` tag 体系。

**理由**：
- `WidgetConfig` 通过 `tag` 做 Map 映射，适合单个 markdown 元素的配置
- `CustomSelectionConfig` 是全局行为配置，不属于任何特定 tag
- `copy()` 方法需要同步传递 `customSelectionConfig`（否则会丢失）

## Risks / Trade-offs

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| Flutter SDK 升级后 `SelectableRegion` 源码变化 | `CustomSelectableRegion` 可能不兼容 | 保持最小化修改；每次 Flutter 升级时 diff 检查 |
| `sourceText` 行号匹配不精确 | 嵌套元素（引用套列表）的源码截取可能偏移 | 对复杂嵌套场景做回归测试；提供 fallback（纯文本） |
| 手势 hit-test 性能 | 元素很多时 hit-test 遍历开销 | Markdown 文档通常元素数有限（<100）；ListView 只渲染可见项 |
| `MarkdownConfig.copy()` 丢失配置 | 用户通过 `copy()` 覆盖配置时 `customSelectionConfig` 被丢弃 | `copy()` 方法必须同步支持新参数 |
