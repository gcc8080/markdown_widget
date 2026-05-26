# 需求评审报告：`markdown_widget` 自定义选择模式

**评审人：** Gemini 3.1 Pro High (Agent)
**评审时间：** 2026-05-27
**针对文档：** `自定义选择模式需求文档.md`

---

## 1. 总体评价

该需求文档结构清晰、背景明确，精准地指出了当前基于 Flutter 原生 `SelectionArea` 构建的 `markdown_widget` 在内容选择互动上的局限性。所提出的“两段式”选择交互（长按弹自定义拓展菜单 -> 点击“选取”按块级元素选中 -> 拖拽细节并提供复制交互）极大提升了针对特定 Markdown 容器应用（如 AI 问答平台、笔记软件等）的用户体验，是一个高价值、具有创新性的需求项。

整体评定：**需求可行，业务价值高，但有一定的技术难度，特别是针对 Markdown 混合嵌套节点元素的定位选择。**

## 2. 需求可行性分析

- **向下兼容性（极佳）：**
  明确指出了“未开启自定义选择模式下逻辑保持不变”，这意味着通过扩展 `MarkdownWidget` 的配置项（例如暴露一个 `selectionConfig` 对象或 `customSelectable` 枚举），可做到对存量用户零影响，完全向后兼容。
- **自定义 UI 解析（可行）：**
  Flutter 中通过 `Overlay` 及 `CompositedTransformTarget` 等机制，可以很方便地在用户的“按捺位置”或者“元素上方”弹出完全由开发者自定义的 Widget（如操作菜单）。传入一个 Callback/Builder 暴露给接驳方即可。
- **块级元素边界识别（有挑战但可行）：**
  由于对 Flutter 3.27.4 有特定要求，考虑到 Flutter 较新版本对 `SelectableRegion` 和 `SelectionRegistrar` 暴露了更为丰富的 Selection Events API。挑战在于这需要 `markdown_widget` 的解释器和页面构建层 (AST Tree 至 Widget Tree 的映射过程) 为每个“独立块”感知自己的区域。

## 3. 功能细节与边界场景探讨 (Edge Cases & Suggestions)

在需求正式进入编码之前，建议明确以下几个边界场景以避免产生歧义和后续的返工：

1. **嵌套 Markdown 元素的“冒泡拦截”层级：**
   - **痛点**：Markdown 常有嵌套结构（如：`引用 > 列表 > 加粗文字`）。
   - **建议明确规则**：当长按“加粗文字”并点击选取文字时，默认是选取整条“列表项”，还是仅仅选取“加粗文字”区域，亦或是选取整个“引用块”？
   - **推荐策略**：建议按照**最底层的块级元素 (Block Node)** 为选中下限颗粒度，即选取对应的“列表项（list item）”或“段落（paragraph）”，而非内联元素（inline Node，如单一的一个超链接或加粗）。
2. **手势冲突问题：**
   - 如果 Markdown 中的元素包含图片（图片可能有他自己的长按放大、保存交互）、或包含链接（链接可能支持长按展示链接信息）。长按这些特定区域时，是优先触发元素的自定义行为，还是强制触发“自定义选择菜单”？
   - **推荐策略**：应提供事件消费机制或优先级参数设定，让内部元素的交互事件能选择性阻断外部 Selection Overlay 的弹出。
3. **滚动跟随与弹出层自动消失机制：**
   - 第一段菜单和第二段复制菜单在用户发生列表滚动时，应该如何表现？
   - **推荐策略**：通常在监测到包含 `MarkdownWidget` 的 ScrollView 发起滚动事件时，主动关闭菜单（Dismiss menus）以保证体验和视图的整洁。
4. **多端/多外设支持映射：**
   - 虽然需求侧重“长按”这类的触摸(Touch)式交互，但如果该组件也运行在 PC 端（macOS/Windows/Web），应明确鼠标“右键点击”或“双击”是否与“长按”等效，呼出相同功能。

## 4. 技术架构与实现思路指导

基于 Flutter `3.27.4` 推荐的技术实现思路：

### 4.1 API 层设计
可以在 `MarkdownWidget` 追加类似配置：
```dart
class MarkdownConfig {
  // ... 其他已有配置
  final MarkdownSelectionConfig selectionConfig;
}

class MarkdownSelectionConfig {
  final bool enableCustomSelection;
  // 长按第一阶段产生的菜单
  final Widget Function(BuildContext context, VoidCallback onSelectText)? firstStageMenuBuilder;
  // 第二阶段选中元素后的菜单
  final Widget Function(BuildContext context, String currentSelection)? secondStageMenuBuilder;
}
```

### 4.2 核心难点：元素追踪与区域选中
*不建议使用 Hack 手段重写原生手势库*。建议结合现有的 AST（抽象语法树）解析器生成 Widget 的阶段：
1. **Node 包装层（Wrapper）**：在核心的 `BlockBuilder` （如 P, Li, Blockquote）生成 Widget 时，用包含 `GlobalKey` 或者专属 `Builder` 包裹，记录触点 (Local Position) 到该节点的命中测试 (HitTest)。
2. **改写/挂载 SelectionRegistrar**：通过获取当前点击处命中的外层 Node，在用户点击 “选取文字” 后，主动向原生的 `SelectableRegion` 派发选中范围更新的 Delegate 指令（如使用 `SelectionEdgeUpdateEvent` 和 `SelectionEndEvent` 模拟拉起光标选中）。
3. **原生光标复用**：只有保持底层的 Selection 实体，才能复用原生的蓝色 / 主题色选区高亮和句柄（Drag handles），确保“用户可以二次拖拽”。

## 5. 项目规划评估

- **P1: API 设计与向后兼容框架 (代码骨架搭建，Overlay弹窗隔离)**
- **P2: Markdown 元素定位和点击测试 (HitTest映射，确认击中哪个AST Node)**
- **P3: Selection API 定制操作 (触发当前 Node 的纯文本选中全亮 & 光标渲染)**
- **P4: 拖拽联动与二段 `复制` 菜单展示**
- **P5: Example 范例编写与代码补全**

整体评估开发工作量中等，主要壁垒在 P2 和 P3 的 **Flutter 原生基础 Selection Framework 知识栈的掌握程度**。

## 6. 总结

该《自定义选择模式需求文档》梳理得相对完善，需求出发点很符合真实的 C 端复杂互动场景，**具有立项和开发的条件**。如果在开发前能够按照第3节稍加细化“嵌套选中边界条件”，实现过程将会非常顺利。期待见证该特性的成功落地。
