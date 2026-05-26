# 自定义选择模式需求评审报告

## 评审对象

[自定义选择模式需求文档.md](./自定义选择模式需求文档.md)

## 评审日期

2026-05-27

---

## 一、总体评价

需求方向清晰，解决了当前 `SelectionArea` 全量包裹、不可定制的痛点——目前 `MarkdownWidget` 和 `MarkdownBlock` 仅在顶层用 `SelectionArea` 包裹整个内容树，用户无法定制长按菜单样式，也无法做元素级别的精准选择。需求文档抓住了这两个核心问题。

但文档在**技术细节、边界条件和 API 设计**上存在较多空白，直接进入实现阶段会遇到大量需要临场决策的问题。以下逐项展开。

---

## 二、需求明确性问题

### 2.1 "长按"的手势定义不够精确

当前 Flutter 的 `SelectionArea` 在移动端的默认触发手势是**长按（long press）**，在 Web / Desktop 端还可以是**双击**或**点击拖拽**。文档只说"长按"，未明确：

- 在 Web / Desktop 平台，自定义选择模式的触发手势是否也是长按？还是应遵循平台原生选择行为？
- 长按的持续时间是否沿用系统默认（约 500ms），还是可配置？
- 是否需要区分"轻点"和"长按"？（例如轻点不触发任何选择行为）

**建议**：明确各平台触发手势，或声明仅支持移动端长按作为第一阶段目标。

### 2.2 "markdown 元素的全部内容"存在歧义

需求 3 说点击"选取文字"后选中"当前点击处的 markdown 元素的全部内容"。但 markdown 存在嵌套结构，这句话缺少精确的粒度定义：

- 用户点击了**引用块内的一段加粗文字**（`> **bold text**`）→ 选中整个引用块？当前段落？仅加粗文字？
- 用户点击了**列表项内的内联代码**（`- some \`code\` here`）→ 选中整个列表项？仅内联代码？
- 用户点击了**表格中某个单元格**的文字 → 选中该单元格？整行？整个表格？
- 用户点击了**嵌套列表**的子项 → 选中子项内容还是包含父级？

**建议**：补充明确的选中粒度规则——"以最小独立块级元素为选中单位"。块级元素包括：heading（h1-h6）、paragraph（p）、list-item（li）、code-block（pre）、blockquote、table、hr（分隔线无文字，忽略）。块级元素内的内联元素（strong、em、code、a、del 等）不单独作为选中单元。

### 2.3 选中后的交互状态机不完整

需求 2 说选中后弹出"复制"菜单，同时需求 3 说用户"还可以拖动选中区域开始或者结束位置的光标调整选择范围"。两者之间的交互关系需要明确：

- 拖动光标调整范围时，浮窗是跟随移动还是暂时消失？
- 如果用户先点了"复制"，再拖动光标调整范围，浮窗还在吗？
- 如果用户点击了浮窗外的空白区域，选中状态是取消还是保持？
- 浮窗是否有一个隐式的"取消/关闭"按钮？还是只能通过点击空白区域取消？

**建议**：补充一个完整的交互状态图：

```
初始状态
  → 长按（拦截，不选中文字）
    → 弹出自定义菜单浮窗
      → 点击"选取文字" → 选中当前块级元素 → 弹出复制菜单浮窗
        → 点击"复制" → 执行复制 → 浮窗消失 → 选中状态保持/取消？
        → 拖动光标 → 浮窗跟随/消失 → 调整选择范围
        → 点击空白区域 → 取消选中 → 浮窗消失
      → 点击其他自定义菜单项 → 执行对应回调 → 浮窗消失
      → 点击浮窗外区域 → 浮窗消失 → 回到初始状态
```

### 2.4 MarkdownBlock 是否也需要支持？

文档只提了 `MarkdownWidget`，但 `MarkdownBlock`（位于 [markdown_block.dart](../lib/widget/markdown_block.dart)）同样有 `selectable` 参数和 `SelectionArea` 实现，逻辑几乎一致：

```dart
return selectable ? SelectionArea(child: column) : column;
```

**建议**：明确 `MarkdownBlock` 是否纳入自定义选择模式的支持范围。

---

## 三、技术可行性分析

### 3.1 核心架构冲突：SelectionArea 的手势拦截

**这是本需求最大的技术难点。** 当前实现代码在 [markdown.dart:128-130](../lib/widget/markdown.dart#L128-L130)：

```dart
return widget.selectable
    ? SelectionArea(child: markdownWidget)
    : markdownWidget;
```

`SelectionArea` 内部通过 `SelectionGestureDetector` 在长按时自动触发选择行为。如果在 `MarkdownWidget` 外层直接加 `GestureDetector` 监听长按，会与 `SelectionArea` 的内部手势产生竞争，结果取决于 Flutter 的手势仲裁机制（通常 `SelectionArea` 内部的手势会更优先）。

**两条技术路线对比：**

| | 方案 A：弃用 SelectionArea | 方案 B：分层状态切换 |
|---|---|---|
| 做法 | 用 `SelectableRegion` + `SelectionHandle` 手动管理选择状态，完全自己实现选择交互 | 非自定义模式保持现状；自定义模式下先禁用 SelectionArea，弹出菜单后再按需启用 |
| 优点 | 完全控制手势和菜单，灵活性最高 | 复用现有 SelectionArea，改动范围小 |
| 缺点 | 需要重新实现大量 Flutter 已提供的选择交互（光标拖拽、选择范围渲染等），工作量大且容易遗漏细节 | 状态切换复杂，SelectionArea 的启用/禁用可能导致 widget 重建和视觉闪烁；两次长按（第一次弹出菜单 + 第二次真正选中后调整范围）的手势流转难处理 |
| 推荐 | 长期来看是更干净的方案 | 可作为快速验证原型 |

**建议**：文档中应做出技术路线决策，或至少标注此为实现阶段需要首先解决的技术选型问题。

### 3.2 程序化选中"整个元素"的文本有难度

`MarkdownGenerator.buildWidgets()`（[markdown_generator.dart:36-69](../lib/config/markdown_generator.dart#L36-L69)）返回的是 `List<Widget>`，每个 widget 是 `Padding > Text.rich(TextSpan)`。`Text.rich` 不是 `EditableText`，不支持通过 `TextEditingController.selection` 设置选择范围。

可行的实现方式：
- 给每个 ListView item 包一个独立的 `SelectableRegion`（或其更轻量的变体），在"选取文字"时程序化设置选择范围
- 使用 `RenderParagraph` 层的底层 API 控制选择

无论哪种方式，都需要**深入 Flutter 的 `SelectionArea` / `SelectableRegion` / `SelectionHandler` 体系**，不是简单的上层封装。

### 3.3 浮窗定位需要准确的全局坐标

需求说"在用户手按住的位置上方弹出自定义功能菜单浮窗"。技术上可行，需要：

- 在 ListView item 层级捕获长按事件的 `globalPosition`
- 使用 `Overlay` 或 `showMenu` 在指定坐标上方显示浮窗
- 处理边界情况：长按位置在屏幕顶部时浮窗应在下方，靠近左右边缘时需水平偏移以避免溢出

这部分属于常规 UI 开发，无特别技术风险，但需要显式实现。

### 3.4 与现有 ListView item 层级结构的适配

当前 `ListView.builder` 中每个 item 已经有多层包裹：`AutoScrollTag` → `VisibilityDetector` → `Padding` → `Text.rich`。新增手势检测需要在不破坏现有 TOC 滚动和可见性检测的前提下加入，需要仔细处理事件穿透。

---

## 四、API 设计缺失

文档只描述了行为，完全没有涉及 API 设计。如果需求评审阶段不确定 API 形态，后续开发中 API 设计会成为持续的争论点。

**建议新增参数示例：**

```dart
MarkdownWidget(
  data: markdownContent,
  selectable: true,
  // 新增：自定义选择模式配置
  customSelectionConfig: CustomSelectionConfig(
    enabled: false,  // 默认关闭，保持向后兼容
    // 长按后弹出的自定义菜单构建器
    longPressMenuBuilder: (
      BuildContext context,
      MarkdownElementInfo elementInfo,  // 被按住的元素信息（类型、文本等）
      Offset globalPosition,            // 按住的位置
      VoidCallback onSelectText,        // 触发"选取文字"的回调
    ) => Widget,
    // "选取文字"后弹出的菜单构建器（默认含"复制"）
    selectionMenuBuilder: (
      BuildContext context,
      VoidCallback onCopy,
      String selectedText,
    ) => Widget,
    // 扩展菜单项（在"选取文字"之外的功能）
    extraMenuItems: [],
  ),
)
```

**建议**：在需求文档中补充 API 设计草案，至少覆盖参数命名、类型和主要回调签名。

---

## 五、边界情况遗漏

以下场景在文档中均未提及，但实现时必然遇到：

| 场景 | 风险等级 | 说明 |
|------|---------|------|
| markdown 内容为空字符串 | 低 | 长按行为应优雅降级 |
| 点击位置落在图片上 | 中 | 图片由 `ImageNode` 渲染为 `WidgetSpan`，无文字可选，需要特殊处理 |
| 点击位置落在代码块上 | 中 | 代码块有独立的 copy 按钮（示例 app 中的 `CodeWrapperWidget`），与自定义选择模式如何共存？ |
| 点击位置落在两个 block 之间的 padding 间隙 | 低 | 应向上或向下归入最近的块级元素 |
| 已选中状态下再次长按另一位置 | 中 | 是否切换选中目标？还是先取消再重新选择？ |
| 自定义选择模式下 `selectable=false` | 中 | 此时是完全没有选择能力，还是仅禁用自定义菜单？ |
| 与 TOC 功能的交互 | 中 | TOC 跳转会触发 ListView 滚动，选中状态是否应清除？ |
| 平板/桌面端的鼠标右键 | 中 | 桌面端用户习惯右键弹出上下文菜单，是否也需要支持自定义？ |
| 复选框（`<input>` 元素）区域 | 高 | 复选框是可交互元素（勾选/取消），长按应触发勾选还是选择菜单？文档需要明确优先级 |
| 链接区域 | 高 | 链接可点击跳转，长按是触发链接行为还是选择行为？当前链接使用 `TapGestureRecognizer`，可能与长按手势冲突 |

---

## 六、Flutter 版本约束

`.fvmrc` 中已配置 `3.27.4`（2024 年 12 月 stable 版本），但 `pubspec.yaml` 中 SDK 约束为 `>=3.0.0 <4.0.0`，范围很宽。需要注意：

- `SelectionArea` 自 Flutter 3.3 引入，在 3.27 中已经较为成熟稳定
- 如果在实现中使用了 Flutter 3.27 的特定 API，应将 SDK 下限收窄至 `>=3.27.0`
- `SelectableRegion` 等更底层的 API 在 3.27 中也可用，无版本兼容性问题

---  

## 七、总结与改进建议

### 建议在需求文档中补齐的内容（按优先级排列）

1. **选中粒度规则**（P0）— 明确"以最小独立块级元素为选中单位"以及嵌套场景的优先级
2. **交互状态机图**（P0）— 完整描述从初始状态到各个状态之间的转换条件和行为
3. **API 设计草案**（P0）— 新增参数的命名、类型、主要回调签名，降低后续返工风险
4. **MarkdownBlock 的支持范围**（P1）— 是否需要同步支持
5. **平台差异说明**（P1）— 移动端 / Desktop / Web 的交互差异
6. **边界情况处理表**（P1）— 覆盖第五节列出的场景，至少标注处理策略
7. **技术路线决策**（P1）— 弃用 SelectionArea vs 分层状态切换，给出倾向性选择

### 整体可行性判断

| 维度 | 评估 |
|------|------|
| 需求合理性 | 合理，解决了真实痛点 |
| 技术可行性 | 可落地，但复杂度**中高** |
| 工作量 | 预估 5-8 人天（含调试和测试） |
| 核心风险 | SelectionArea 手势拦截与程序化选择范围控制 |
| 对现有代码的侵入性 | 中等，需要重构 `MarkdownWidget.build()` 中的选择逻辑 |

**结论**：建议补齐上述内容后进入技术方案设计和 API 设计阶段，不要直接开始编码。
