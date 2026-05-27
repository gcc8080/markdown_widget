# 自定义选择模式需求文档 — 评审报告

> **评审对象**：[自定义选择模式需求文档.md](./自定义选择模式需求文档.md)
>
> **评审日期**：2026-05-27
>
> **评审人**：Kimi 2.6

---

## 一、总体评价

该需求文档准确地识别了当前 `markdown_widget` 在文本选择和复制体验上的核心痛点：

1. `SelectionArea` 的菜单样式完全不可定制，无法满足业务侧的 branding 需求
2. 默认的全量选中行为粒度太粗，无法针对 Markdown 的语义结构（块级元素）做精准选择

需求方向正确，业务价值明确。但从工程实现角度看，当前文档距离可执行的设计阶段**仍有明显差距**。主要问题在于：文档对底层架构现状的理解不足，导致对实现复杂度的预估偏低；同时缺少对交互边界、API 形态、验收标准的明确定义。

---

## 二、当前架构深度分析

### 2.1 Widget 树的构建链路

理解该需求的实现难度，必须先理清当前 `markdown_widget` 的渲染链路：

```
Markdown 字符串
  → m.Document.parseLines()  // markdown 包解析为 AST (List<m.Node>)
  → WidgetVisitor.visit()     // 遍历 AST，生成 List<SpanNode>
  → MarkdownGenerator.buildWidgets()  // SpanNode → InlineSpan → Widget
  → MarkdownWidget.build()    // 将 Widget 列表放入 ListView.builder
```

最终每个顶层块级元素（heading、paragraph、list 等）被渲染为 `ListView` 的一个 item，结构大致为：

```
ListView
  ├── item 0: AutoScrollTag → VisibilityDetector → Padding → Text.rich(TextSpan(...))
  ├── item 1: AutoScrollTag → VisibilityDetector → Padding → Text.rich(TextSpan(...))
  └── ...
```

### 2.2 关键问题：SpanNode 到 Widget 的映射信息丢失

当前架构存在一个**关键的信息断层**：

- `SpanNode` 树（AST 的映射）保留了 markdown 的语义结构（h1、p、li、blockquote 等），知道"这是标题"、"这是列表项"
- 但 `buildWidgets()` 最终只返回 `List<Widget>`，每个 widget 已经失去了对应的 `SpanNode` 元数据
- 当用户在某处长按时，我们只能得到触摸点在屏幕上的坐标，**无法直接反查到该坐标对应的 markdown 元素类型和内容**

这意味着，实现"长按选中当前 markdown 元素"这一核心需求，必须要在现有架构中**补一条从触摸位置到 SpanNode 的反向映射通道**。这不是一个 UI 层的简单改造，而是涉及渲染管线元数据保留的架构级改动。

---

## 三、需求明确性问题

### 3.1 "开启自定义选择模式"的入口未定义

文档多次提到"开启"和"未开启"自定义选择模式，但未说明：

- **如何开启？** 是新增一个 `bool` 参数（如 `customSelectionMode`）？还是通过配置对象（如 `CustomSelectionConfig`）？
- **与现有 `selectable` 参数的关系？**
  - 若 `selectable: false`，自定义选择模式是否还有效？
  - 若 `selectable: true` 且开启了自定义模式，是否意味着两套选择逻辑共存？
- **`MarkdownBlock` 是否需要同步支持？** 当前代码中 `MarkdownBlock` 和 `MarkdownWidget` 都有 `selectable` 参数，需求文档只提到了 `MarkdownWidget`

**建议**：明确新增参数，推荐设计如下：

```dart
MarkdownWidget(
  data: markdownData,
  selectable: true,
  // 新增配置对象，默认 null 表示不开启自定义选择模式
  customSelectionConfig: CustomSelectionConfig(
    enabled: true,
    initialMenuBuilder: (context, elementInfo, position) => ...,
    selectionMenuBuilder: (context, selectedText, position) => ...,
  ),
)
```

### 3.2 "Markdown 元素"的选中粒度缺乏精确定义

需求第 3 条描述了不同 markdown 元素的选中行为，但存在以下模糊地带：

| 元素 | 当前描述 | 待澄清问题 |
|------|---------|-----------|
| 标题 (h1-h6) | "将整个标题渲染的区域全部选中" | 是否包含 heading 下方可能存在的分割线？ |
| 正文段落 (p) | "将选中全部正文部分" | "全部正文"是指当前段落，还是整个文档的非标题文本？ |
| 列表项 (li) | "选中的是当前列表对应的列表项" | 嵌套列表时，选中的是最内层子项，还是包含子列表的整个项？ |
| 引用 (blockquote) | "选中该区块内的全部文字" | 引用内可能包含多个段落、列表，是否全部选中？ |
| 代码块 (pre) | 同引用 | 复制时是否保留原始换行和缩进？ |
| 表格 (table) | ❌ 未定义 | 选中单元格？整行？还是整个表格？ |
| 图片 (img) | ❌ 未定义 | 长按图片是否弹出菜单？复制什么内容？ |
| 链接 (a) | ❌ 未定义 | 选中链接的显示文本还是包含 URL？ |
| 行内代码 (code) | ❌ 未定义 | 选所在段落，还是仅选中行内代码自身？ |

**建议**：采用"以**最小独立块级元素**为默认选中单位"的规则，明确内联元素（如 strong、em、code、a）不单独作为选中单元。

### 3.3 交互状态机缺少关键状态定义

需求描述的交互流程是线性的（长按 → 菜单 → 选取文字 → 选中 → 复制菜单 → 复制），但实际使用中存在大量分支：

```
初始状态
  │
  ├── 长按可选区域
  │    ├── 弹出初始自定义菜单（包含"选取文字"）
  │    │    ├── 点击"选取文字"
  │    │    │    ├── 选中当前块级元素全部内容
  │    │    │    ├── 弹出"复制"菜单
  │    │    │    │    ├── 点击"复制" → 复制内容 → 菜单消失？选中状态保留？
  │    │    │    │    └── 点击其他区域 → 菜单消失？选中状态保留？
  │    │    │    └── 拖动光标调整选择范围 → "复制"菜单如何处理？
  │    │    └── 点击其他自定义项 → 执行自定义逻辑 → 菜单消失？
  │    └── 点击菜单外区域 → 菜单消失 → 回到初始状态
  │
  ├── 已选中状态下再次长按其他区域 → 切换选中目标？先取消再重新选择？
  │
  └── 滚动页面时 → 菜单是否跟随？是否自动关闭？
```

以下问题必须在需求中明确：

1. **菜单关闭时机**：点击菜单外区域、滚动页面、点击另一处并长按时，菜单是否关闭？
2. **选中状态持久性**：点击"复制"后，选中状态是保留还是清除？
3. **光标拖动时菜单行为**：用户拖动选择手柄调整范围时，"复制"菜单是隐藏、跟随还是保持不变？
4. **多元素选中**：是否支持跨块级元素的选中？如果支持，选中范围如何定义？

### 3.4 自定义菜单的扩展机制未定义

需求提到"支持自定义其他功能菜单扩展"，但缺少以下关键信息：

- 自定义菜单项的数据结构是什么？（文本、图标、点击回调？）
- 自定义菜单项是否能获取当前 markdown 元素的上下文信息（类型、纯文本内容、原始 markdown 源码）？
- 自定义菜单项点击后是否自动关闭菜单？
- 是否允许移除默认的"选取文字"项？
- 自定义菜单浮窗的样式是否全部由业务方控制，还是提供一套默认样式？

**建议**：定义菜单项的统一接口：

```dart
class SelectionMenuItem {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool Function(MarkdownElementInfo element)? visible;
  
  const SelectionMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.visible,
  });
}
```

---

## 四、技术可行性分析

### 4.1 核心技术难点一：手势拦截与 `SelectionArea` 的冲突

当前 `MarkdownWidget` 的实现：

```dart
// lib/widget/markdown.dart:128-130
return widget.selectable
    ? SelectionArea(child: markdownWidget)
    : markdownWidget;
```

`SelectionArea` 内部已经注册了长按手势来触发文本选择。如果在 `MarkdownWidget` 外层或内部叠加 `GestureDetector` 监听长按，会产生**手势竞争**。根据 Flutter 的手势仲裁机制，`SelectionArea` 内部的手势通常会优先被识别。

**可行的技术路线**：

| 方案 | 描述 | 优点 | 缺点 | 推荐度 |
|------|------|------|------|--------|
| **A：弃用 `SelectionArea`，自行实现选择体系** | 使用 `SelectableRegion` + `SelectionHandler` 手动管理选择状态 | 完全可控，灵活性最高 | 工作量大，需要自行实现光标渲染、拖动手柄、选区高亮等 | ⭐⭐⭐ |
| **B：自定义模式下禁用 `SelectionArea`** | 自定义模式下不包裹 `SelectionArea`，通过 `GestureDetector` + `Overlay` 实现菜单，点击"选取文字"后再启用选择 | 改动范围小，可复用现有逻辑 | 状态切换复杂，启用/禁用 `SelectionArea` 可能导致 widget 重建和视觉闪烁 | ⭐⭐⭐⭐ |
| **C：利用 `SelectionArea.contextMenuBuilder`（Flutter 3.7+）** | Flutter 3.27 中 `SelectionArea` 已支持 `contextMenuBuilder`，可以自定义长按弹出的菜单 | 改动最小，复用 Flutter 原生选择体系 | 无法控制"选取文字"的行为（即无法实现"选中整个元素"的需求），只能定制菜单外观 | ⭐⭐ |

**结论**：方案 C 无法满足"选中整个 markdown 元素"的核心需求；方案 A 工作量过大且容易遗漏细节。**方案 B 是更现实的起点**：自定义模式下先禁用 `SelectionArea` 的长按行为，自行管理"长按弹出菜单 → 点击选取文字 → 启用选择"的状态流转。

### 4.2 核心技术难点二：从触摸位置定位到 Markdown 元素

如前所述，当前架构中 `buildWidgets()` 返回的 `List<Widget>` 已经丢失了对应的 `SpanNode` 元数据。要实现"长按选中当前元素"，需要在以下两个方向之一进行改造：

**方向一：保留 Widget → SpanNode 的映射**

在 `MarkdownGenerator.buildWidgets()` 中，为每个生成的 widget 附加一个标识（如 `GlobalKey` 或 `Metadata`），并在 widget 层级中保留对应的 `SpanNode` 引用。当用户长按时，通过 `RenderBox` 的 hitTest 找到对应的 widget，再通过映射获取 `SpanNode`。

**方向二：重构渲染管线，让 SpanNode 直接参与选择**

在 `SpanNode` 的 `build()` 方法中，让每个块级元素的 `InlineSpan` 包裹一层带标识的 `WidgetSpan`，或者让 `TextSpan` 携带语义信息。这种方式侵入性更小，但实现"选中整个元素"时，需要遍历 `SpanNode` 树获取纯文本。

**推荐**：方向一更为直接。可在 `MarkdownGenerator` 中返回 `List<MarkdownRenderItem>` 而非 `List<Widget>`：

```dart
class MarkdownRenderItem {
  final Widget widget;
  final SpanNode spanNode;      // 对应的 AST 节点
  final MarkdownTag tag;        // 元素类型
  final String plainText;       // 纯文本内容
  final String? sourceText;     // 原始 markdown 源码（可选）
  final int index;              // 在列表中的索引
}
```

### 4.3 核心技术难点三：程序化选中"整个元素"

`Text.rich`/`RichText` 不是 `EditableText`，无法通过 controller 直接设置 `TextSelection`。要程序化选中一段文本，有两种可行路径：

1. **使用 `SelectionContainer` + `SelectableRegion`（Flutter 3.3+）**
   - 给每个 `ListView` item 包裹一个 `SelectionContainer`
   - 在"选取文字"时，通过 `SelectableRegion` 的 API 设置选择范围
   - 这种方式需要深入了解 `SelectableRegion` 的内部机制

2. **使用 `RenderParagraph` 层 API**
   - 获取 `RenderParagraph` 的 `selectable` 属性
   - 调用 `selectable.select(...)` 设置选择范围
   - 这种方式更底层，可控性更高，但代码复杂度也更高

**建议**：先调研 `SelectableRegion` 的能力是否满足"选中整个元素"的需求。如果 Flutter 3.27.4 中已有足够 API，优先使用；否则考虑方案 A 的简化版本。

### 4.4 浮窗定位与边界处理

"在用户手按住的位置上方弹出自定义功能菜单浮窗"属于常规 UI 开发，技术风险较低，但需要处理以下边界：

- **屏幕顶部**：长按位置靠近屏幕顶部时，菜单应显示在下方而非上方
- **屏幕左右边缘**：菜单宽度超出屏幕时应水平偏移
- **滚动时**：`ListView` 滚动时菜单应跟随目标位置还是直接关闭？
- **键盘弹出**：键盘弹出导致屏幕可用高度变化时，菜单位置如何调整？

**建议**：使用 `Overlay` + `CompositedTransformFollower` 实现跟随定位，而不是简单的 `Positioned` 定位。这样可以更优雅地处理滚动和键盘弹出的场景。

---

## 五、边界情况分析

以下场景在需求文档中均未提及，但实现中必然遇到：

| 场景 | 风险等级 | 说明与建议 |
|------|---------|-----------|
| Markdown 内容为空 | 低 | 长按行为应优雅降级，不弹出任何菜单 |
| 长按位置在图片上 | 中 | 图片由 `ImageNode` 渲染为 `WidgetSpan`，无文字可选。需定义是否弹出图片专属菜单（如"保存图片"），还是忽略 |
| 长按位置在链接上 | 高 | 链接已有 `TapGestureRecognizer` 处理点击，长按可能与链接手势冲突。需定义优先级：长按链接区域是触发选择菜单还是链接行为？ |
| 长按位置在复选框上 | 高 | 复选框是可交互元素（勾选/取消），长按应触发勾选还是选择菜单？ |
| 长按位置在代码块内 | 中 | 代码块可能有独立的复制按钮，与自定义选择模式如何共存？ |
| 长按位置在两个 block 之间 | 低 | 应归入最近的块级元素，或忽略 |
| 已选中状态下页面滚动 | 中 | TOC 跳转或用户滚动时，选中状态和菜单如何处理？ |
| 跨元素拖动选择 | 高 | 用户拖动光标跨越多个块级元素时，是否允许？复制内容如何拼接？ |
| 自定义模式下 `selectable: false` | 中 | 是仅禁用系统选择但仍弹出自定义菜单，还是完全禁用选择能力？ |
| 桌面端右键 | 中 | 桌面端用户习惯右键弹出上下文菜单，是否也需要支持自定义？ |

---

## 六、API 设计建议

基于以上分析，建议在需求文档中补充如下 API 草案：

```dart
/// 自定义选择模式的配置
class CustomSelectionConfig {
  /// 是否启用自定义选择模式
  final bool enabled;

  /// 长按后弹出的初始菜单构建器
  final SelectionMenuBuilder? initialMenuBuilder;

  /// "选取文字"后弹出的选择菜单构建器
  final SelectionMenuBuilder? selectionMenuBuilder;

  /// 自定义菜单项
  final List<SelectionMenuItem> Function(MarkdownElementInfo element)? menuItems;

  /// 点击"复制"后的回调，返回要复制的文本
  final String Function(String selectedText)? copyFormatter;

  const CustomSelectionConfig({
    this.enabled = false,
    this.initialMenuBuilder,
    this.selectionMenuBuilder,
    this.menuItems,
    this.copyFormatter,
  });
}

/// Markdown 元素信息
class MarkdownElementInfo {
  final MarkdownTag tag;
  final String plainText;
  final String? sourceText;
  final int widgetIndex;
  final Rect? globalRect;
}

/// 菜单构建器
typedef SelectionMenuBuilder = Widget Function(
  BuildContext context,
  MarkdownElementInfo elementInfo,
  Offset globalPosition,
);
```

---

## 七、验收标准建议

| 编号 | 验收标准 | 优先级 |
|------|---------|--------|
| AC-1 | 未开启自定义模式时，`MarkdownWidget(selectable: true)` 的行为与当前版本完全一致 | P0 |
| AC-2 | `selectable: false` 时，不触发系统选择，也不触发自定义选择菜单 | P0 |
| AC-3 | 开启自定义模式后，长按 markdown 内容区域先弹出初始自定义菜单，不立即出现系统选择手柄 | P0 |
| AC-4 | 点击"选取文字"后，默认选中当前块级元素的全部内容 | P0 |
| AC-5 | 选中后弹出包含"复制"的菜单，点击"复制"将纯文本复制到剪贴板 | P0 |
| AC-6 | 用户拖动光标可以调整选择范围 | P1 |
| AC-7 | 长按列表项只选中当前列表项，不选中整组列表 | P1 |
| AC-8 | 长按代码块选中全部代码内容，复制时保留换行和缩进 | P1 |
| AC-9 | 轻点链接仍触发跳转，长按链接触发选择菜单 | P1 |
| AC-10 | 选中状态下滚动页面，菜单位置正确或自动关闭，不崩溃 | P1 |
| AC-11 | `example` 目录提供完整的使用范例，展示默认和自定义两种模式 | P0 |

---

## 八、推荐实现路径

建议将需求拆分为两个阶段：

### 第一阶段：MVP（最小可用版本）

1. **仅支持 `MarkdownWidget`**，`MarkdownBlock` 暂不纳入范围
2. **仅支持移动端长按**，桌面端和 Web 端保持现有 `SelectionArea` 行为
3. **默认选中单位限定为顶层块级 item**（即 `ListView` 的一个 item）
4. **菜单支持 builder 自定义**，但复制内容先使用纯文本
5. **先覆盖以下元素类型**：标题、段落、列表项、引用、代码块
6. **表格、图片给出降级策略**（如长按表格选中整表，长按图片不弹出文字选择菜单）

### 第二阶段：增强版

1. 支持更细粒度的元素选中（如表格单元格、行、整表）
2. 支持桌面端右键、Web 鼠标拖选等平台行为
3. 支持更丰富的复制格式（Markdown 源码、带 URL 的链接文本等）
4. 支持跨多个 Markdown 元素的拖动选择

---

## 九、总结

| 维度 | 评估 |
|------|------|
| 需求合理性 | ✅ 合理，解决了真实痛点 |
| 需求完整性 | ⚠️ 不足，缺少 API 定义、交互状态机、边界处理、验收标准 |
| 技术可行性 | ✅ 可落地，但复杂度中高 |
| 核心风险 | `SelectionArea` 手势拦截、程序化选择控制、元素元数据保留 |
| 对现有代码的侵入性 | 中高，需要改造 `MarkdownGenerator` 和 `MarkdownWidget` 的选择逻辑 |
| 预估工作量 | 8-12 人天（含方案设计、实现、测试、调试） |

**结论**：该需求值得做，且方向正确。但当前需求文档更像"业务诉求描述"，距离可直接进入编码阶段的"工程规格说明"还有距离。建议在进入方案设计前，优先补齐以下前置条件：

1. **精确定义"Markdown 元素选中粒度"**：明确每种 tag 对应的选中单位和复制内容格式
2. **补充完整的交互状态机**：涵盖所有分支场景（菜单关闭、选中状态持久性、光标拖动、滚动等）
3. **确定 API 草案**：包括参数命名、类型、回调签名
4. **明确平台范围和非目标**：第一阶段仅支持移动端长按，桌面/Web 保持现有行为
5. **定义验收标准**：可测试的验收点列表

**整体复杂度评估**：**中高**。如果按 MVP 路径（仅移动端、仅块级元素、纯文本复制），工作量可控；如果要求完整替代 Flutter 原生选择体系并覆盖所有边界场景，则需要更系统的架构设计。
