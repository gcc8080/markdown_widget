## Why

`markdown_widget` 当前依赖 Flutter 原生 `SelectionArea` 实现文本选择，存在两个核心局限：1）长按菜单样式完全不可定制，无法满足业务侧的品牌和功能扩展需求；2）选择粒度为逐字选择，无法按 Markdown 语义结构（标题、段落、列表项等块级元素）进行智能初始选中。这在 AI 问答平台、笔记软件等需要精细内容交互的场景中是关键体验瓶颈。

## What Changes

- 新增 `CustomSelectionConfig` 配置类，支持两阶段自定义菜单交互（阶段1：长按弹出功能菜单；阶段2：选中元素后弹出操作菜单）
- 新增 `MarkdownElementInfo` 数据模型，携带被操作元素的类型、纯文本、原始 markdown 源码、坐标等元数据
- 新增 `CustomSelectableRegion` 组件，基于 Flutter `SelectableRegion` 源码，暴露编程式选择 API（`selectRange`、`showHandles`），替换长按手势为外部回调
- 改造 `MarkdownGenerator`，新增 `buildWidgetsWithInfo()` 方法，在生成 Widget 的同时保留元素元数据映射
- 改造 `MarkdownWidget` 和 `MarkdownBlock`，当 `customSelectionConfig` 配置非 null 时，使用自定义选择逻辑替代原生 `SelectionArea`
- 扩展 `MarkdownConfig` 构造函数，新增 `customSelectionConfig` 命名参数
- 在 example app 中新增 "Custom Selection" 页面，集成到现有导航

## Capabilities

### New Capabilities
- `custom-selection-interaction`: 两阶段自定义选择交互——阶段1（长按→自定义菜单，暴露元素信息和坐标）和阶段2（选取文字→按块级元素智能选中→自定义菜单，支持拖动滑块调整选区）
- `element-metadata`: Markdown 元素元数据提取——触摸位置到 Markdown AST 节点的反向映射，提供元素类型、纯文本、原始 markdown 源码、坐标信息
- `custom-selectable-region`: 自定义可选择区域组件——基于 Flutter SelectableRegion 的定制版本，暴露编程式选择 API，替换默认长按行为

### Modified Capabilities
_(无已有 spec 需要修改)_

## Impact

- **核心库文件**：`lib/config/configs.dart`、`lib/config/markdown_generator.dart`、`lib/widget/markdown.dart`、`lib/widget/markdown_block.dart` 需要修改
- **新增文件**：`lib/config/custom_selection_config.dart`、`lib/widget/custom_selectable_region.dart`、`lib/widget/selectable_element_wrapper.dart`
- **API 变更**：`MarkdownConfig` 构造函数新增可选参数（向后兼容）；`MarkdownBlock` 从 StatelessWidget 改为 StatefulWidget（对使用者无感知）
- **依赖**：无新增外部依赖；`CustomSelectableRegion` 基于 Flutter 3.27.4 SDK 源码改造，与 Flutter 版本耦合
- **向后兼容**：未配置 `customSelectionConfig` 时，所有行为与当前版本完全一致
- **预估新增代码量**：~1200 行
