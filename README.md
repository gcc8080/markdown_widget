Language：[简体中文](https://github.com/asjqkkkk/markdown_widget/blob/master/README_ZH.md) | [English](https://github.com/asjqkkkk/markdown_widget/blob/master/README.md)

![screen](https://github.com/asjqkkkk/asjqkkkk.github.io/assets/30992818/4185bf1a-0be3-460d-ba12-9e4764f5c035)

# 📖markdown_widget

[![Coverage Status](https://coveralls.io/repos/github/asjqkkkk/markdown_widget/badge.svg?branch=dev)](https://coveralls.io/github/asjqkkkk/markdown_widget?branch=dev) [![pub package](https://img.shields.io/pub/v/markdown_widget.svg)](https://pub.dartlang.org/packages/markdown_widget) [![demo](https://img.shields.io/badge/demo-online-brightgreen)](https://asjqkkkk.github.io/markdown_widget/)

A simple and easy-to-use markdown rendering component.

- Supports TOC (Table of Contents) function for quick location through Headings
- Supports code highlighting
- Supports all platforms

## 🚀Usage

Before starting, you can try out the online demo by clicking [demo](https://asjqkkkk.github.io/markdown_widget/)

```
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MarkdownPage extends StatelessWidget {
  final String data;

  MarkdownPage(this.data);

  @override
  Widget build(BuildContext context) => Scaffold(body: buildMarkdown());

  Widget buildMarkdown() => MarkdownWidget(data: data);
}
```
If you want to use your own Column or other list widget, you can use `MarkdownGenerator`

```
  Widget buildMarkdown() =>
      Column(children: MarkdownGenerator().buildWidgets(data));
```

Or use `MarkdownBlock`

```
  Widget buildMarkdown() =>
      SingleChildScrollView(child: MarkdownBlock(data: data));
```

## 🌠Night mode

`markdown_widget` supports night mode by default. Simply use a different `MarkdownConfig` to enable it.

```
  Widget buildMarkdown(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    final codeWrapper = (child, text, language) =>
        CodeWrapperWidget(child, text, language);
    return MarkdownWidget(
        data: data,
        config: config.copy(configs: [
        isDark
        ? PreConfig.darkConfig.copy(wrapper: codeWrapper)
        : PreConfig().copy(wrapper: codeWrapper)
    ]));
  }
```

Default mode | Night mode
---|---
<img src="https://user-images.githubusercontent.com/30992818/211159089-ec4acd11-ee02-46f2-af4f-f8c47eb28410.png" width=400> | <img src="https://user-images.githubusercontent.com/30992818/211159108-4c20de2d-fb1d-4bcb-b23f-3ceb91291661.png" width=400>


## 🔗Link

You can customize the style and click events of links, like this

```
  Widget buildMarkdown() => MarkdownWidget(
      data: data,
      config: MarkdownConfig(configs: [
        LinkConfig(
          style: TextStyle(
            color: Colors.red,
            decoration: TextDecoration.underline,
          ),
          onTap: (url) {
            ///TODO:on tap
          },
        )
      ]));
```

## 📜TOC (Table of Contents) feature

Using the TOC is very simple

```
  final tocController = TocController();

  Widget buildTocWidget() => TocWidget(controller: tocController);

  Widget buildMarkdown() => MarkdownWidget(data: data, tocController: tocController);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Row(
          children: <Widget>[
            Expanded(child: buildTocWidget()),
            Expanded(child: buildMarkdown(), flex: 3)
          ],
        ));
  }
```

## 🎈Highlighting  code

Highlighting code supports multiple themes.

```
import 'package:flutter_highlight/themes/a11y-light.dart';

  Widget buildMarkdown() => MarkdownWidget(
      data: data,
      config: MarkdownConfig(configs: [
        PreConfig(theme: a11yLightTheme),
      ]));
```

## 🧬Select All and Copy

Cross-platform support for Select All and Copy function.

![image](https://user-images.githubusercontent.com/30992818/226107076-f32a919e-9a0c-4138-8a0b-266c6337e0af.png)

## ✋Custom selection mode

`MarkdownWidget` also supports an opt-in two-stage selection flow. When
`selectionConfig` is not provided, the existing `SelectionArea` behavior is
preserved. When `selectable` is `false`, both native selection and custom
selection are disabled.

```dart
MarkdownWidget(
  data: data,
  selectionConfig: MarkdownSelectionConfig(
    initialMenuActions: [
      MarkdownSelectionMenuAction(
        id: 'favorite',
        label: 'Favorite',
        onPressed: (context) {
          context.dismiss();
        },
      ),
    ],
    selectedTextMenuActions: [
      MarkdownSelectionMenuAction(
        id: 'explain',
        label: 'Explain',
        onPressed: (context) {
          final selectedText = context.selectedText;
          context.clearSelection();
          // Use selectedText.
        },
      ),
    ],
    initialMenuBuilder: (context, menuContext) {
      return Row(
        children: menuContext.allActions
            .map((action) => TextButton(
                  onPressed: () => action.onPressed(menuContext),
                  child: Text(action.label),
                ))
            .toList(),
      );
    },
  ),
);
```

Interaction rules:

- Long press opens the initial custom menu first and does not immediately select
  text.
- Text-bearing targets receive the built-in `Select text` / `选取文字` action.
  Menu builders may hide or reorder that action.
- Text-free targets such as images, horizontal rules, and task-list checkbox
  controls do not expose `Select text`. If no application action remains, no
  menu is shown.
- After `Select text`, the initial range is the nearest semantic Markdown unit:
  heading, paragraph, current table cell, current list item direct text, nearest
  block quote, or full code block.
- Link taps keep the existing link behavior. Link long press opens the custom
  menu first.
- Scrolling hides the selected-text menu but keeps the selection. Tapping inside
  the active range reopens the selected-text menu; tapping outside clears the
  selection.
- Copy and selected-text actions clear the menu, handles, and selection before
  the action callback continues.

The first release targets Android and iOS touch long-press flows for
`MarkdownWidget`. `MarkdownBlock`, desktop right-click/Web browser context menu
integration, and rich Markdown-source clipboard formats are deferred.

## 🌐Html tag

As the current package only implements the conversion of Markdown tags, it does not support the conversion of HTML tags by default. However, this functionality can be supported through extension. You can refer to the usage in [html_support.dart](https://github.com/asjqkkkk/markdown_widget/blob/dev/example/lib/markdown_custom/html_support.dart) for more details.

Here is the [online HTML demo showcase](https://asjqkkkk.github.io/markdown_widget/#/sample_html)

## 🧮Latex support

The example also includes simple support for LaTeX, which can be implemented by referring to the implementation in [latex.dart](https://github.com/asjqkkkk/markdown_widget/blob/dev/example/lib/markdown_custom/latex.dart)

Here is the [online latex demo showcase](https://asjqkkkk.github.io/markdown_widget/#/sample_latex)

## 🍑Custom tag implementation

By passing a `SpanNodeGeneratorWithTag` to `MarkdownGeneratorConfig`, you can add new tags and the corresponding `SpanNode`s for those tags. You can also use existing tags to override the corresponding `SpanNode`s.

You can also customize the parsing rules for Markdown strings using `InlineSyntax` and `BlockSyntax`, and generate new tags.

You can refer to [this issue](https://github.com/asjqkkkk/markdown_widget/issues/79) to learn how to implement a custom tag.

If you have any good ideas or suggestions, or have any issues using this package, please feel free to [open a pull request or issue](https://github.com/asjqkkkk/markdown_widget).

# 🧾Appendix

Here are the other libraries used in `markdown_widget`

Packages | Descriptions
---|---
[markdown](https://pub.dev/packages/markdown) | Parsing markdown data
[flutter_highlight](https://pub.dev/packages/flutter_highlight) | Code highlighting
[highlight](https://pub.dev/packages/highlight) | Code highlighting
[url_launcher](https://pub.dev/packages/url_launcher) | Opening links
[visibility_detector](https://pub.dev/packages/visibility_detector) | Listening for visibility of a widget;
[scroll_to_index](https://pub.dev/packages/scroll_to_index) | Enabling ListView to jump to an index.
