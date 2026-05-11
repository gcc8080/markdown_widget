# 需求文档

## 简介

为 `markdown_widget` 包实现自定义选择模式功能。当前的 `MarkdownWidget` 仅通过 Flutter 的 `SelectionArea` 提供基础的文本选择和复制能力，用户无法自定义长按弹出菜单的样式，也无法控制选择范围的粒度。本功能将引入一种新的自定义选择模式，支持长按时先弹出自定义功能菜单，再由用户决定是否进入文字选取状态，并以 Markdown 元素为粒度进行初始选中。

## 术语表

- **MarkdownWidget**: 用于渲染 Markdown 内容的 Flutter StatefulWidget 组件
- **Custom_Selection_Mode（自定义选择模式）**: 一种新的选择交互模式，长按时先弹出自定义菜单而非直接选中文字
- **Selection_Area**: Flutter SDK 中提供文本选择能力的组件（SelectionArea）
- **Context_Menu（功能菜单浮窗）**: 长按后在手指位置上方弹出的自定义操作菜单
- **Markdown_Element（Markdown 元素）**: Markdown 文档中的结构化内容单元，如标题、段落、列表项、引用块、代码块等
- **SpanNode**: markdown_widget 中所有渲染节点的基类
- **ElementNode**: 可包含子节点的 SpanNode 子类
- **MarkdownGenerator**: 将 Markdown 文本转换为 Widget 列表的生成器
- **Selection_Handle（选择光标）**: 选中区域两端的可拖动手柄，用于调整选择范围

## 需求

### 需求 1：默认选择行为的向后兼容

**用户故事：** 作为开发者，我希望在未开启自定义选择模式时，MarkdownWidget 的选择行为保持不变，以确保现有功能不受影响。

#### 验收标准

1. THE MarkdownWidget SHALL 将参数 `customSelectionMode` 的默认值设置为 `false`，确保未显式开启时不影响现有行为
2. WHILE `customSelectionMode` 为 `false`, WHEN 参数 `selectable` 设置为 `true`, THE MarkdownWidget SHALL 使用 Flutter 的 SelectionArea 包裹内容列表（ListView 或 Column），提供 Flutter 原生的长按选择文本和复制能力
3. WHILE `customSelectionMode` 为 `false`, WHEN 参数 `selectable` 设置为 `false`, THE MarkdownWidget SHALL 不使用 SelectionArea 包裹内容，禁用所有文本选择功能
4. WHILE `customSelectionMode` 为 `false`, WHEN 用户长按内容区域, THE MarkdownWidget SHALL 展示与 Flutter SelectionArea 一致的原生选择交互行为，包括选中文本高亮、拖动光标调整范围、以及系统默认的复制菜单弹出
5. WHILE `customSelectionMode` 为 `false`, THE MarkdownWidget SHALL 不注册任何与自定义选择模式相关的手势监听器或浮窗逻辑

### 需求 2：自定义选择模式的启用配置

**用户故事：** 作为开发者，我希望通过配置参数开启自定义选择模式，以便在需要时使用更灵活的选择交互。

#### 验收标准

1. THE MarkdownWidget SHALL 提供 `bool` 类型的 `customSelectionMode` 参数用于开启自定义选择模式
2. IF `customSelectionMode` 设置为 `true`, THEN THE MarkdownWidget SHALL 不使用 `SelectionArea` 包裹内容区域（无论 `selectable` 参数为何值），并启用自定义选择模式的手势监听逻辑
3. THE MarkdownWidget SHALL 将 `customSelectionMode` 参数的默认值设置为 `false`
4. IF `customSelectionMode` 设置为 `false`, THEN THE MarkdownWidget SHALL 保持现有行为不变，即根据 `selectable` 参数的值决定是否使用 `SelectionArea` 包裹内容区域

### 需求 3：长按触发自定义功能菜单

**用户故事：** 作为用户，我希望长按 Markdown 内容区域时弹出自定义功能菜单，以便我可以选择不同的操作。

#### 验收标准

1. WHILE Custom_Selection_Mode 已开启, WHEN 用户长按 MarkdownWidget 的内容区域超过 500 毫秒, THE MarkdownWidget SHALL 使用 Flutter Overlay 在用户手指按住位置的正上方 8 逻辑像素处弹出 Context_Menu，若上方空间不足则显示在下方 8 逻辑像素处
2. WHILE Custom_Selection_Mode 已开启, WHEN 用户长按 MarkdownWidget 的内容区域, THE MarkdownWidget SHALL 不选中任何文字
3. THE Context_Menu SHALL 默认包含「选取文字」功能项
4. THE MarkdownWidget SHALL 提供 `contextMenuBuilder` 回调参数，接收长按位置坐标和菜单项列表作为入参，返回一个 Widget 用于完全替代默认 Context_Menu 的样式和布局
5. IF 开发者同时提供了 `contextMenuBuilder` 和 `contextMenuItems` 参数, THEN THE MarkdownWidget SHALL 优先使用 `contextMenuBuilder` 的返回值作为 Context_Menu，并将 `contextMenuItems` 中的菜单项通过入参传递给 `contextMenuBuilder`
6. THE MarkdownWidget SHALL 提供 `contextMenuItems` 参数，允许开发者追加自定义功能菜单项至默认菜单项列表的末尾
7. WHEN 用户点击 Context_Menu 以外的区域, THE MarkdownWidget SHALL 关闭 Context_Menu 且不改变当前文字选中状态
8. WHEN 用户点击 Context_Menu 中的任意菜单项, THE MarkdownWidget SHALL 执行该菜单项对应的回调后关闭 Context_Menu

### 需求 4：选取文字功能的元素级选中

**用户故事：** 作为用户，我希望点击「选取文字」后能自动选中当前 Markdown 元素的全部内容，以便快速选择有意义的内容块。

#### 验收标准

1. WHEN 用户点击 Context_Menu 中的「选取文字」菜单项, THE MarkdownWidget SHALL 关闭当前 Context_Menu 并在 200ms 内完成关闭动画
2. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为标题（h1-h6）, THE MarkdownWidget SHALL 高亮选中该标题渲染区域的全部纯文本内容（不含 Markdown 语法符号），并在选中区域两端显示可拖动的选择手柄
3. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为段落, THE MarkdownWidget SHALL 高亮选中该段落渲染的全部纯文本内容，并在选中区域两端显示可拖动的选择手柄
4. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为列表项, THE MarkdownWidget SHALL 高亮选中当前列表项（单个 li 节点）渲染的全部纯文本内容，并在选中区域两端显示可拖动的选择手柄
5. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为引用块, THE MarkdownWidget SHALL 高亮选中该引用块内渲染的全部纯文本内容，并在选中区域两端显示可拖动的选择手柄
6. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为代码块, THE MarkdownWidget SHALL 高亮选中该代码块内的全部代码文本内容，并在选中区域两端显示可拖动的选择手柄
7. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为表格、图片或水平分割线等非文本块级元素, THE MarkdownWidget SHALL 不执行选中操作，并保持当前状态不变
8. WHEN 用户点击「选取文字」且长按位置对应的 Markdown_Element 为其他包含文本的块级元素, THE MarkdownWidget SHALL 高亮选中该元素渲染区域的全部纯文本内容，并在选中区域两端显示可拖动的选择手柄
9. WHEN 文本被选中且选择手柄可见时, THE MarkdownWidget SHALL 允许用户拖动起始或结束选择手柄来调整选中范围，拖动过程中实时更新高亮区域
10. WHEN 文本被选中后, THE MarkdownWidget SHALL 在选中区域上方弹出包含「复制」功能项的 Context_Menu

### 需求 5：选中后的复制功能菜单

**用户故事：** 作为用户，我希望文字选中后能看到复制菜单，以便我可以复制选中的内容。

#### 验收标准

1. WHEN Markdown_Element 的文字内容被选中, THE MarkdownWidget SHALL 以 Overlay 方式在选中区域上方居中位置弹出包含「复制」功能项的 Context_Menu，若上方空间不足则显示在选中区域下方
2. WHEN 用户点击「复制」菜单项, THE MarkdownWidget SHALL 将选中的纯文本内容（不含 Markdown 标记符号）通过 Flutter Clipboard API 复制到系统剪贴板
3. WHEN 用户点击「复制」菜单项, THE MarkdownWidget SHALL 关闭 Context_Menu、移除 Overlay、并清除文字选中高亮状态
4. WHEN 用户点击 Context_Menu 外部区域, THE MarkdownWidget SHALL 关闭 Context_Menu 并清除文字选中高亮状态
5. IF 剪贴板写入操作失败, THEN THE MarkdownWidget SHALL 保留文字选中状态与 Context_Menu 显示，不做任何状态变更
6. WHERE 开发者通过 `contextMenuBuilder` 参数提供了自定义构建器, THE MarkdownWidget SHALL 使用该构建器替代默认 Context_Menu 渲染复制菜单，构建器接收当前选中的文本内容和一个关闭菜单的回调函数作为参数

### 需求 6：选中范围的手动调整

**用户故事：** 作为用户，我希望在文字被选中后可以通过拖动光标调整选择范围，以便精确选择我需要的内容。

#### 验收标准

1. WHEN Markdown_Element 的文字内容被选中, THE MarkdownWidget SHALL 在选中区域的起始和结束位置各显示一个可拖动的 Selection_Handle
2. WHEN 用户拖动起始位置的 Selection_Handle, THE MarkdownWidget SHALL 在每一帧渲染中更新选中区域的起始边界至手指当前所在的字符位置，选中区域的高亮显示应跟随手指移动同步刷新
3. WHEN 用户拖动结束位置的 Selection_Handle, THE MarkdownWidget SHALL 在每一帧渲染中更新选中区域的结束边界至手指当前所在的字符位置，选中区域的高亮显示应跟随手指移动同步刷新
4. WHILE 用户拖动 Selection_Handle 调整选择范围, THE Context_Menu SHALL 保持隐藏状态
5. WHEN 用户停止拖动 Selection_Handle, THE MarkdownWidget SHALL 在更新后的选中区域上方重新显示 Context_Menu
6. WHEN 用户将 Selection_Handle 拖动跨越相邻的 Markdown_Element 边界时, THE MarkdownWidget SHALL 将选中区域扩展至相邻 Markdown_Element 中手指所在的字符位置，支持跨多个 Markdown_Element 的连续选择
7. IF 用户将起始位置的 Selection_Handle 拖动到结束位置的 Selection_Handle 之后（或将结束位置的拖动到起始位置之前）, THEN THE MarkdownWidget SHALL 交换两个 Selection_Handle 的角色，使起始 Handle 始终位于选中区域的前端、结束 Handle 始终位于选中区域的末端，且选中区域至少包含 1 个字符

### 需求 7：示例代码

**用户故事：** 作为开发者，我希望在项目的 example 目录下有自定义选择模式的使用范例，以便快速了解如何集成该功能。

#### 验收标准

1. THE 项目 SHALL 在 `example` 目录下提供自定义选择模式的示例代码，该示例可通过 `flutter run` 独立编译运行且无编译错误
2. THE 示例代码 SHALL 通过调用 `MarkdownWidget` 的自定义选择模式相关参数，演示如何开启自定义选择模式，并包含不少于 3 行的内联注释说明关键集成步骤
3. THE 示例代码 SHALL 演示如何自定义 Context Menu 的样式，包含至少对菜单背景色和文字样式的自定义示例
4. THE 示例代码 SHALL 演示如何扩展自定义功能菜单项，包含至少 1 个除默认「选取文字」和「复制」之外的自定义菜单项
5. THE 示例代码 SHALL 在其 `pubspec.yaml` 中将 Flutter SDK 约束设置为兼容 3.10.6 版本
