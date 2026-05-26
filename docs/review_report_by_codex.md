# markdown_widget 自定义选择模式需求评审报告

## 评审对象

[自定义选择模式需求文档.md](./自定义选择模式需求文档.md)

## 评审日期

2026-05-27

---

## 一、结论摘要

这个需求方向成立，痛点也真实：当前 `markdown_widget` 主要依赖 Flutter 的 `SelectionArea` 提供整块内容的选择与复制能力，能用但可控性不足，尤其无法在“真正进入文字选择前”展示业务自定义菜单，也无法默认把选择范围收敛到用户长按位置对应的 Markdown 元素。

但从当前文档看，它还不是一个可以直接进入编码的完整需求。最大缺口有三个：

1. **“当前 Markdown 元素”没有精确定义**：Markdown AST、渲染 widget、用户点击命中的文本区域三者不是一一对应关系。
2. **交互状态机不完整**：长按、弹出菜单、选中文字、拖动光标、复制、取消、滚动之间的状态流转需要明确。
3. **API 与验收标准缺失**：文档没有定义对外参数、回调、菜单构建方式、复制内容格式和平台范围，后续实现会被大量临场决策拖住。

建议先补充一版“可实现级需求说明”，再进入方案设计和编码阶段。若按当前描述直接开发，风险集中在手势冲突、程序化选中、元素元数据缺失和平台差异上。

---

## 二、与当前代码结构的关系

当前项目的选择能力主要是顶层包裹：

- `MarkdownWidget` 在 [../lib/widget/markdown.dart](../lib/widget/markdown.dart) 中构造 `ListView.builder`，最后用 `SelectionArea(child: markdownWidget)` 包裹。
- `MarkdownBlock` 在 [../lib/widget/markdown_block.dart](../lib/widget/markdown_block.dart) 中构造 `Column`，最后同样用 `SelectionArea(child: column)` 包裹。
- `MarkdownGenerator.buildWidgets` 在 [../lib/config/markdown_generator.dart](../lib/config/markdown_generator.dart) 中把 Markdown 解析为 `List<SpanNode>`，最终只返回 `List<Widget>`，每个顶层 item 大致是 `Padding -> Text.rich(TextSpan)`。

这意味着当前架构只保留了“渲染后的 widget 列表”，没有稳定暴露每个 widget 对应的 Markdown 原始节点、节点类型、纯文本范围、源码范围、块级边界等信息。自定义选择模式恰好需要这些信息，因此它不是只加一个 `GestureDetector` 或菜单 builder 就能完整解决的需求。

---

## 三、需求明确性问题

### 3.1 “Markdown 元素”的选择粒度需要严格定义

文档说点击“选取文字”后，默认选中“当前点击处的 markdown 元素的全部内容”。这句话在概念上清楚，但实现上有歧义。

需要明确以下规则：

| 用户长按位置 | 建议明确的默认选中单位 | 需要补充的问题 |
| --- | --- | --- |
| 标题文本 | 当前 heading 块 | 是否包含标题前后的空行？ |
| 普通段落 | 当前 paragraph 块 | 是否包含段落内链接、加粗、内联代码的纯文本？ |
| 列表项 | 当前 `li` | 嵌套列表是只选子项，还是连同子列表一起选？ |
| 引用块 | 当前 blockquote 或内部 paragraph | 应该选整个引用块，还是引用块内被命中的最小段落？ |
| 代码块 | 当前 pre/code block | 是否保留缩进、换行和语言标记？ |
| 表格单元格 | 单元格、行或整表 | 文档目前没有定义，必须补充 |
| 图片 | 无文本、alt 文本或图片节点 | 需要定义长按图片时的行为 |
| 任务列表复选框 | 当前列表项或忽略 checkbox | 需要定义与复选框交互的优先级 |

建议在需求中写成明确规则：**第一阶段以“可独立阅读的块级单元”为默认选择单位**，并列出每种 Markdown tag 对应的选择单位和复制文本。

### 3.2 “选中区域”与“复制内容”不是同一件事

需求提到“选中整个标题渲染的区域”“复制内容”，但没有说明复制的是：

- 渲染后的纯文本；
- Markdown 源码；
- 带列表编号或 bullet 的文本；
- 表格的 TSV/Markdown 表格文本；
- 代码块是否保留原始换行和缩进；
- 链接是只复制标题文本，还是复制 URL。

这是必须前置确定的验收点。否则即使 UI 看起来选中了，用户点“复制”得到什么仍然可能不符合预期。

### 3.3 自定义菜单的行为边界不清楚

文档只说明菜单“样式支持自定义”“支持自定义其他功能菜单扩展”，但没有定义扩展项的输入和生命周期。

建议明确：

- 菜单 builder 能拿到哪些信息：元素类型、元素纯文本、Markdown 源码片段、全局坐标、当前主题、关闭菜单回调等。
- 自定义菜单项点击后是否自动关闭菜单。
- 自定义菜单项是否可以触发选择、复制、翻译、分享等异步操作。
- 菜单显示时是否允许页面滚动；滚动后菜单是否跟随、关闭或重新定位。
- 菜单超出屏幕边界时如何避让。

### 3.4 平台范围需要收窄

需求只写“长按”，但 Flutter 的选择交互在 Android、iOS、Web、Windows、macOS、Linux 上表现不同。桌面端常见行为是鼠标拖选、双击、右键菜单；Web 端还要考虑浏览器文本选择习惯。

建议明确第一阶段平台范围，例如：

- 第一阶段仅保证 Android/iOS 触摸长按；
- 桌面和 Web 保持现有 `SelectionArea` 行为，或只提供右键自定义菜单；
- 后续再扩展桌面鼠标交互。

---

## 四、技术风险评估

| 风险 | 等级 | 原因 | 建议 |
| --- | --- | --- | --- |
| `SelectionArea` 与自定义长按手势冲突 | 高 | 当前选择能力由 `SelectionArea` 内部手势驱动，自定义模式要求先拦截长按且暂不选中文字 | 自定义模式下需要单独的选择控制路径，不能只在外层叠加手势 |
| 程序化选中指定 Markdown 元素 | 高 | `Text.rich`/`RichText` 不是 `EditableText`，不能通过 controller 直接设置 selection | 需要研究 `SelectableRegion`、`SelectionContainer`、`Selectable`/render 层能力，或设计受控选择模型 |
| Markdown 节点元数据缺失 | 高 | `buildWidgets` 最终只返回 widget，缺少节点类型、文本、范围、索引信息 | 增加内部模型，如 `MarkdownElementInfo`/`MarkdownRenderItem`，让渲染和选择共享同一份元数据 |
| 嵌套结构命中判断困难 | 中高 | 列表、引用、表格、WidgetSpan 会打破简单的“一个 item 一个块”假设 | 先定义 MVP 粒度，避免一开始支持所有嵌套细分 |
| 与现有交互节点冲突 | 中 | 链接使用 `TapGestureRecognizer`，图片使用 `InkWell`/`Hero`，代码块示例有独立复制按钮 | 定义手势优先级：tap 保持原行为，long press 进入选择菜单 |
| 与 TOC/ListView 滚动联动 | 中 | `MarkdownWidget` 依赖 `AutoScrollTag`、`VisibilityDetector`、`ListView.builder` | 选中状态下滚动、TOC jump、item 回收都要有策略 |
| Flutter 版本约束 | 中 | `.fvmrc` 是 `3.27.4`，但 `pubspec.yaml` SDK 约束仍是 `>=3.0.0 <4.0.0` | 若使用 3.27 专属 API，需要同步调整约束或做兼容说明 |

---

## 五、建议补充的 API 草案

需求文档至少应给出 API 方向，避免实现阶段反复改公共接口。可以考虑类似：

```dart
MarkdownWidget(
  data: data,
  selectable: true,
  selectionMode: MarkdownSelectionMode.custom,
  selectionConfig: MarkdownSelectionConfig(
    initialMenuBuilder: initialMenuBuilder,
    selectionMenuBuilder: selectionMenuBuilder,
    onElementLongPress: onElementLongPress,
    copyFormatter: copyFormatter,
  ),
)
```

建议同时明确：

- `selectable = false` 时，自定义选择模式是否完全失效。
- 默认值必须保持现有行为：未开启自定义模式时，现有 `SelectionArea` 逻辑不变。
- `MarkdownBlock` 是否复用同一套 API。
- `MarkdownElementInfo` 至少包含：`tag`、`plainText`、`sourceText`、`widgetIndex`、`globalRect`、`parentTags`。
- 菜单 builder 需要拿到关闭菜单、触发默认选择、复制等标准 action。

---

## 六、建议补充的交互状态机

文档需要把状态流转写清楚，推荐至少覆盖：

1. 初始状态：无菜单、无自定义选区。
2. 长按命中可选元素：阻止默认立即选中，显示初始自定义菜单。
3. 点击“选取文字”：选中命中元素对应文本，显示选择后菜单。
4. 点击“复制”：复制当前选区文本，菜单关闭；是否保留选区需明确。
5. 拖动选择手柄：更新选区；菜单隐藏、跟随或延迟出现需明确。
6. 点击空白区域：关闭菜单并取消选区，或仅关闭菜单。
7. 页面滚动或 TOC 跳转：关闭菜单，是否保留选区需明确。
8. 再次长按其他元素：切换目标，或先取消再进入新流程。

---

## 七、验收标准建议

建议在需求文档中补充可测试的验收标准：

- 默认模式：不传新配置时，`MarkdownWidget(selectable: true)` 的选择和复制行为与当前版本一致。
- 关闭选择：`selectable: false` 时不触发系统选择，也不触发自定义选择菜单，除非文档明确另有设计。
- 自定义模式：长按普通段落先显示自定义菜单，不立即出现系统选择手柄。
- 点击“选取文字”：默认选中被命中的块级元素，复制得到预期纯文本。
- 列表项：长按某个列表项只默认选中该列表项，不误选整组列表，除非需求另有定义。
- 代码块：复制内容保留换行和缩进。
- 链接：轻点仍触发链接行为，长按进入自定义菜单。
- 图片：长按图片时按文档定义处理，例如显示图片菜单但不进入文字选择。
- 滚动：选中状态下滚动不崩溃、不出现悬浮菜单位置错乱。
- 示例：`example` 中提供一个完整页面展示默认“选取文字/复制”和至少一个自定义菜单项。

---

## 八、推荐落地路径

建议把需求拆成两个阶段。

第一阶段做 MVP：

- 只支持 `MarkdownWidget`，或明确同步支持 `MarkdownBlock`。
- 只保证移动端长按。
- 默认选择单位限定为顶层块级 item 或最小可独立块级元素。
- 菜单支持 builder 自定义，但复制内容先使用纯文本。
- 先覆盖标题、段落、列表项、引用、代码块，表格和图片给出降级策略。

第二阶段再增强：

- 支持表格单元格/行/整表的精细规则。
- 支持桌面右键、Web 鼠标拖选等平台行为。
- 支持更丰富的复制格式，如 Markdown 源码、纯文本、带 URL 的链接文本。
- 支持跨多个 Markdown 元素拖动选择后的自定义菜单。

---

## 九、最终评审意见

该需求值得做，但目前文档更像“业务诉求描述”，还缺少“工程可执行规格”。建议在进入实现前，优先补齐：

1. Markdown 元素选择粒度表。
2. 复制内容格式定义。
3. 自定义菜单 API 草案。
4. 完整交互状态机。
5. 平台范围和非目标。
6. `MarkdownWidget` 与 `MarkdownBlock` 的支持边界。
7. 可测试验收标准。

整体复杂度评估为**中高**。如果只做移动端 MVP，工作量可控；如果要求完整替代 Flutter 原生选择体系，并覆盖桌面/Web/嵌套表格/跨块拖选，则需要更系统的选择架构设计，不能按普通 UI 功能改造来估算。
