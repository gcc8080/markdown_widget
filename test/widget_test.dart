import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'test_markdowns/network_image_mock.dart';
import 'widget_visitor_test.dart';
import 'package:path/path.dart' as p;

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  const testMarkdown = '''
| align left | centered | align right |
| :-- | :-: | --: |
| a | b | c | 
# a
## askdljakl
### akslfjkl
### akslfjkl
### akslfjkl
## askdljakl
### akslfjkl
### akslfjkl
### akslfjkl
## askdljakl
### akslfjkl
### akslfjkl
### akslfjkl
## askdljakl
### akslfjkl
### akslfjkl
### akslfjkl
## askdljakl
### akslfjkl
### akslfjkl
### akslfjkl
### akslfjklasjf22
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf
### akslfjklasjf33
- asdasd
- asdasda
- asdasdas
1. asdasdasd
2. asdasdasd
3. asdasdasd''';

  Widget testApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: child,
        ),
      ),
    );
  }

  testWidgets('test toc widget', (tester) async {
    final tocController = TocController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
            textDirection: TextDirection.ltr,
            child: TocWidget(
              controller: tocController,
              itemBuilder: (data) {
                if (data.index == 0) return Container();
                return null;
              },
            )),
      ),
    ));
    final list = List.generate(10, (index) {
      final heading = HeadingNode(H1Config(), WidgetVisitor());
      heading.accept(TextNode(text: "$index"));
      return Toc(
        node: heading,
        widgetIndex: index,
        selfIndex: index,
      );
    });
    tocController.setTocList(list);
    print(tocController.tocList);
    tocController.jumpToIndexCallback = (i) {
      print('jumpToIndexCallback:$i');
    };
    tocController.onIndexChanged(5);
    tocController.jumpToIndex(2);
    await tester.scrollUntilVisible(
        find.text('8'), // what you want to find // widget you want to scroll
        200);
    final gesture = await tester.startGesture(Offset(0, 300));
    gesture.up();
    tocController.setTocList([list.removeLast()]);
    tocController.dispose();
  });

  testWidgets('test markdown widget', (tester) async {
    final tocController = TocController();
    tocController.jumpToIndexCallback = (i) {
      print('jumpToIndexCallback  :$i');
    };
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    String text = '';
    late StateSetter setter;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(builder: (context, callback) {
              ctx = context;
              setter = callback;
              return MarkdownWidget(
                data: text,
                tocController: tocController,
                config: MarkdownConfig(configs: [
                  TableConfig(wrapper: (child) => Container(child: child))
                ]),
              );
            })),
      ),
    ));
    tocController.jumpToIndex(0);
    setter(() {
      text = testMarkdown;
    });
    await tester.scrollUntilVisible(find.text('akslfjklasjf22'), 50);
    tocController.jumpToIndex(0);
    await tester.scrollUntilVisible(find.text('akslfjklasjf33'), 50);
    final widget = tester.firstWidget(find.byWidgetPredicate(
            (widget) => widget is NotificationListener<UserScrollNotification>))
        as NotificationListener<UserScrollNotification>;
    widget.onNotification?.call(UserScrollNotification(
        metrics: FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1,
            pixels: 1,
            viewportDimension: 1,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1),
        context: ctx,
        direction: ScrollDirection.forward));
  });

  testWidgets('test markdown block', (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, callback) {
          return SingleChildScrollView(
            child: MarkdownBlock(data: testMarkdown),
          );
        }),
      ),
    ));
  });

  testWidgets('test other widgets', (tester) async {
    final jsonList = getTestJsonList();
    for (var json in jsonList) {
      final content = json['markdown'];
      final widgets = testMarkdownGenerator(content);
      for (var widget in widgets) {
        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Directionality(
                    textDirection: TextDirection.ltr, child: widget)),
          ));
        });
      }
    }
  });

  testWidgets('test for asset file', (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final current = Directory.current;
    final jsonPath = p.join(current.path, 'example', 'assets', 'editor.md');
    File jsonFile = File(jsonPath);
    final content = jsonFile.readAsStringSync();
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Directionality(
                textDirection: TextDirection.ltr,
                child: MarkdownWidget(
                  data: content,
                  config: MarkdownConfig.defaultConfig.copy(configs: [
                    BlockquoteConfig(),
                    ListConfig(),
                    TableConfig(),
                    LinkConfig(),
                    ImgConfig(),
                    CheckBoxConfig(),
                  ]),
                  markdownGenerator: MarkdownGenerator(generators: [
                    SpanNodeGeneratorWithTag(
                        tag: 'test',
                        generator: (e, config, visitor) {
                          return TextNode(text: e.textContent);
                        })
                  ]),
                ))),
      ));
    });
  });

  testWidgets('MCheckBox test', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Directionality(
              textDirection: TextDirection.ltr,
              child: ListView(
                children: [
                  MCheckBox(checked: false),
                  MCheckBox(checked: true),
                ],
              ))),
    ));
  });

  testWidgets('test ImageViewer iconButton pressed', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(MaterialApp(
          home: ImageViewer(child: Container(width: 100, height: 100))));
    });
    final buttons = tester
        .widgetList(find.byWidgetPredicate((widget) => widget is IconButton));
    for (var button in buttons) {
      (button as IconButton).onPressed?.call();
    }
  });

  testWidgets('test ImageViewer gesture taped', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(MaterialApp(
          home: ImageViewer(child: Container(width: 100, height: 100))));
    });
    await (await tester.startGesture(Offset(50, 50))).up();
  });

  testWidgets('default selectable path still uses SelectionArea',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(data: 'paragraph'),
    ));

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byType(MarkdownCustomSelectionArea), findsNothing);
  });

  testWidgets('selectable false disables native and custom selection paths',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: 'paragraph',
        selectable: false,
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byType(MarkdownCustomSelectionArea), findsNothing);
    expect(find.byType(MarkdownSelectionTargetWidget), findsNothing);
  });

  testWidgets('custom selection long press opens initial menu before selection',
      (tester) async {
    MarkdownSelectionMenuContext? capturedContext;
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: 'paragraph',
        selectionConfig: MarkdownSelectionConfig(
          initialMenuBuilder: (context, menuContext) {
            capturedContext = menuContext;
            return Material(
              child: Column(
                children: menuContext.allActions
                    .map(
                      (action) => TextButton(
                        onPressed: () => action.onPressed(menuContext),
                        child: Text(action.label),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    ));

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byType(MarkdownCustomSelectionArea), findsOneWidget);

    await tester.longPress(find.text('paragraph'));
    await tester.pump();

    expect(capturedContext, isNotNull);
    expect(capturedContext!.hasSelection, isFalse);
    expect(capturedContext!.selectedText, isEmpty);
    expect(capturedContext!.builtInActions.single.label, '选取文字');
    expect(find.text('选取文字'), findsOneWidget);
    expect(find.text('复制'), findsNothing);
  });

  testWidgets('initial menu builder can reorder select text', (tester) async {
    final renderedLabels = <String>[];
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: 'paragraph',
        selectionConfig: MarkdownSelectionConfig(
          initialMenuActions: [
            MarkdownSelectionMenuAction(
              id: 'custom',
              label: '自定义',
              onPressed: (context) {},
            )
          ],
          initialMenuBuilder: (context, menuContext) {
            final orderedActions = [
              ...menuContext.applicationActions,
              ...menuContext.builtInActions,
            ];
            renderedLabels
              ..clear()
              ..addAll(orderedActions.map((action) => action.label));
            return Material(
              child: Row(
                children: orderedActions
                    .map(
                      (action) => TextButton(
                        onPressed: () => action.onPressed(menuContext),
                        child: Text(action.label),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    ));

    await tester.longPress(find.text('paragraph'));
    await tester.pump();

    expect(renderedLabels, ['自定义', '选取文字']);
  });

  testWidgets('initial menu builder can hide select text', (tester) async {
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: 'paragraph',
        selectionConfig: MarkdownSelectionConfig(
          initialMenuBuilder: (context, menuContext) {
            return const Material(child: Text('隐藏内置'));
          },
        ),
      ),
    ));
    await tester.longPress(find.text('paragraph'));
    await tester.pump();

    expect(find.text('隐藏内置'), findsOneWidget);
    expect(find.text('选取文字'), findsNothing);
  });

  testWidgets('link tap is preserved and link long press opens custom menu',
      (tester) async {
    var tappedUrl = '';
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: '[link](https://example.com)',
        config: MarkdownConfig.defaultConfig.copy(
          configs: [
            LinkConfig(onTap: (url) => tappedUrl = url),
          ],
        ),
        selectionConfig: const MarkdownSelectionConfig(),
      ),
    ));

    final linkFinder = find.textContaining('link', findRichText: true);
    await tester.tapAt(tester.getTopLeft(linkFinder) + const Offset(4, 8));
    await tester.pump();
    expect(tappedUrl, 'https://example.com');

    await tester.longPress(linkFinder);
    await tester.pump();
    expect(find.text('选取文字'), findsOneWidget);
  });

  testWidgets('select text shows selected menu and handles', (tester) async {
    MarkdownSelectionMenuContext? selectedContext;
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: 'selectable paragraph',
        selectionConfig: MarkdownSelectionConfig(
          initialMenuBuilder: (context, menuContext) {
            return Material(
              child: TextButton(
                key: const ValueKey('select-text-action'),
                onPressed: () =>
                    menuContext.builtInActions.single.onPressed(menuContext),
                child: const Text('选取文字'),
              ),
            );
          },
          selectedTextMenuBuilder: (context, menuContext) {
            selectedContext = menuContext;
            return Material(
              child: TextButton(
                onPressed: () =>
                    menuContext.builtInActions.single.onPressed(menuContext),
                child: Text(menuContext.builtInActions.single.label),
              ),
            );
          },
        ),
      ),
    ));

    await tester.longPress(find.text('selectable paragraph'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-text-action')));
    await tester.pump();

    expect(selectedContext, isNotNull);
    expect(selectedContext!.hasSelection, isTrue);
    expect(selectedContext!.selectedText, contains('selectable paragraph'));
    expect(find.text('复制'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('markdown-selection-start-handle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('markdown-selection-end-handle')),
      findsOneWidget,
    );
  });

  testWidgets('select text only selects the pressed semantic unit',
      (tester) async {
    const complexMarkdown = '''
# Custom selection mode

Long press text to open the first menu appears before text is selected.
Tap **Select text** to select the complete paragraph and show draggable handles.

> A block quote can contain multiple paragraphs.
> Long pressing either paragraph selects the nearest quote block.

- The first list item is independent.
- The second list item has direct text.
  - Nested child text is not part of the initial list-item selection.

| Element | Initial selection |
| --- | --- |
| Table cell | Current cell |
| Code block | Entire code block |

```dart
void main() {
  print('hello');
}
```
''';

    MarkdownSelectionMenuContext? selectedContext;
    Future<String> selectedTextFor(
      Finder finder, {
      String data = complexMarkdown,
    }) async {
      selectedContext = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(testApp(
        MarkdownWidget(
          data: data,
          selectionConfig: MarkdownSelectionConfig(
            selectedTextMenuBuilder: (context, menuContext) {
              selectedContext = menuContext;
              return const Material(child: Text('selected menu'));
            },
          ),
        ),
      ));
      final richTextFinder = find.descendant(
        of: finder.first,
        matching: find.byType(RichText),
      );
      final targetRect = richTextFinder.evaluate().isNotEmpty
          ? tester.getRect(richTextFinder.first)
          : tester.getRect(finder.first);
      await tester.longPressAt(targetRect.topLeft + const Offset(8, 8));
      await tester.pump();
      await tester.tap(find.text('选取文字'));
      await tester.pump();
      expect(selectedContext, isNotNull);
      return selectedContext!.selectedText;
    }

    Finder targetFinder(
      MarkdownSelectionTargetType type,
      String text,
    ) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is MarkdownSelectionTargetWidget &&
            widget.target.type == type &&
            widget.target.plainText.contains(text),
      );
    }

    final headingText = await selectedTextFor(
      targetFinder(
        MarkdownSelectionTargetType.heading,
        'Custom selection mode',
      ),
    );
    expect(headingText.trim(), 'Custom selection mode');
    expect(headingText, isNot(contains('Long press text')));
    expect(headingText, isNot(contains('A block quote')));

    final paragraphText = await selectedTextFor(
      targetFinder(
        MarkdownSelectionTargetType.paragraph,
        'the first menu',
      ),
    );
    expect(paragraphText, contains('the first menu'));
    expect(paragraphText, contains('Select text'));
    expect(paragraphText, isNot(contains('Custom selection mode')));
    expect(paragraphText, isNot(contains('A block quote')));

    final quoteText = await selectedTextFor(
      targetFinder(
        MarkdownSelectionTargetType.blockquote,
        'nearest quote block',
      ),
    );
    expect(quoteText, contains('A block quote'));
    expect(quoteText, contains('nearest quote block'));
    expect(quoteText, isNot(contains('The first list item')));

    final listText = await selectedTextFor(
      targetFinder(
        MarkdownSelectionTargetType.listItem,
        'The second list item has direct text',
      ),
    );
    expect(listText, contains('The second list item has direct text'));
    expect(listText, isNot(contains('Nested child text')));
    expect(listText, isNot(contains('The first list item')));

    final tableCellText = await selectedTextFor(
      targetFinder(
        MarkdownSelectionTargetType.tableCell,
        'Current cell',
      ),
      data: '''
| Element | Initial selection |
| --- | --- |
| Table cell | Current cell |
| Code block | Entire code block |
''',
    );
    expect(tableCellText.trim(), 'Current cell');
    expect(tableCellText, isNot(contains('Table cell')));
    expect(tableCellText, isNot(contains('Code block')));

    final codeText = await selectedTextFor(
      targetFinder(
        MarkdownSelectionTargetType.codeBlock,
        'void main',
      ),
      data: '''
```dart
void main() {
  print('hello');
}
```
''',
    );
    expect(codeText, contains('void main() {\n'));
    expect(codeText, contains("print('hello');"));
    expect(codeText, isNot(contains('Current cell')));
  });

  testWidgets('copy clears custom selection and writes clipboard',
      (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>;
        clipboardText = args['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: 'copy paragraph',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    await tester.longPress(find.text('copy paragraph'));
    await tester.pump();
    await tester.tap(find.text('选取文字'));
    await tester.pump();
    await tester.tap(find.text('复制'));
    await tester.pump();

    expect(clipboardText, contains('copy paragraph'));
    expect(find.text('复制'), findsNothing);
    expect(
      find.byKey(const ValueKey('markdown-selection-start-handle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('markdown-selection-end-handle')),
      findsNothing,
    );
  });

  testWidgets('selected text action clears selection before callback',
      (tester) async {
    var actionCalled = false;
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: 'action paragraph',
        selectionConfig: MarkdownSelectionConfig(
          selectedTextMenuActions: [
            MarkdownSelectionMenuAction(
              id: 'favorite',
              label: '收藏',
              onPressed: (context) {
                actionCalled = true;
              },
            )
          ],
        ),
      ),
    ));

    await tester.longPress(find.text('action paragraph'));
    await tester.pump();
    await tester.tap(find.text('选取文字'));
    await tester.pump();
    await tester.tap(find.text('收藏'));
    await tester.pump();

    expect(actionCalled, isTrue);
    expect(find.text('复制'), findsNothing);
    expect(find.text('收藏'), findsNothing);
    expect(
      find.byKey(const ValueKey('markdown-selection-start-handle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('markdown-selection-end-handle')),
      findsNothing,
    );
  });

  testWidgets('code block copy preserves line breaks', (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>;
        clipboardText = args['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: '```dart\nline one\nline two\n```',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final codeTargetFinder = find.byWidgetPredicate(
      (widget) =>
          widget is MarkdownSelectionTargetWidget &&
          widget.target.type == MarkdownSelectionTargetType.codeBlock,
    );
    await tester.longPress(codeTargetFinder.first);
    await tester.pump();
    await tester.tap(find.text('选取文字'));
    await tester.pump();
    await tester.tap(find.text('复制'));
    await tester.pump();

    expect(clipboardText, contains('line one\nline two'));
  });

  testWidgets('code block wrapper copy button does not start custom selection',
      (tester) async {
    var copied = false;
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: '```dart\nprint(1);\n```',
        config: MarkdownConfig.defaultConfig.copy(
          configs: [
            PreConfig(
              wrapper: (child, code, language) {
                return Column(
                  children: [
                    TextButton(
                      key: const ValueKey('code-copy-button'),
                      onPressed: () {
                        copied = true;
                      },
                      child: const Text('代码复制'),
                    ),
                    child,
                  ],
                );
              },
            ),
          ],
        ),
        selectionConfig: const MarkdownSelectionConfig(),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('code-copy-button')));
    await tester.pump();

    expect(copied, isTrue);
    expect(find.text('选取文字'), findsNothing);
    expect(find.text('复制'), findsNothing);
    expect(
      find.byKey(const ValueKey('markdown-selection-start-handle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('markdown-selection-end-handle')),
      findsNothing,
    );
  });

  testWidgets('handle drag hides and restores selected menu', (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: 'drag paragraph',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    await tester.longPress(find.text('drag paragraph'));
    await tester.pump();
    await tester.tap(find.text('选取文字'));
    await tester.pump();
    expect(find.text('复制'), findsOneWidget);

    final endHandle =
        find.byKey(const ValueKey('markdown-selection-end-handle'));
    final gesture = await tester.startGesture(tester.getCenter(endHandle));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(find.text('复制'), findsNothing);

    await gesture.up();
    await tester.pump();
    expect(find.text('复制'), findsOneWidget);
  });

  testWidgets('scroll hides selected menu without clearing handles',
      (tester) async {
    final lines = List.generate(40, (index) => 'paragraph $index').join('\n\n');
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: lines,
        selectionConfig: const MarkdownSelectionConfig(),
      ),
    ));

    await tester.longPress(find.text('paragraph 0'));
    await tester.pump();
    await tester.tap(find.text('选取文字'));
    await tester.pump();
    expect(find.text('复制'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -30));
    await tester.pump();

    expect(find.text('复制'), findsNothing);
    expect(
      find.byKey(const ValueKey('markdown-selection-start-handle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('markdown-selection-end-handle')),
      findsOneWidget,
    );

    await tester.tapAt(
      tester.getTopLeft(find.text('paragraph 0')) + const Offset(8, 8),
    );
    await tester.pump();
    expect(find.text('复制'), findsOneWidget);
  });

  testWidgets('tap outside active selection clears menu and handles',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: 'tap paragraph',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    await tester.longPress(find.text('tap paragraph'));
    await tester.pump();
    await tester.tap(find.text('选取文字'));
    await tester.pump();
    expect(find.text('复制'), findsOneWidget);

    await tester.tapAt(const Offset(380, 580));
    await tester.pump();

    expect(find.text('复制'), findsNothing);
    expect(
      find.byKey(const ValueKey('markdown-selection-start-handle')),
      findsNothing,
    );
  });

  testWidgets('semantic targets expose direct list item text only',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: '- parent\n  - child',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final listTargets = tester
        .widgetList<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget),
        )
        .map((widget) => widget.target)
        .where((target) => target.type == MarkdownSelectionTargetType.listItem)
        .toList();

    expect(listTargets, hasLength(2));
    expect(listTargets.first.plainText.trim(), 'parent');
    expect(listTargets.first.plainText, isNot(contains('child')));
    expect(listTargets.last.plainText.trim(), 'child');
  });

  testWidgets('text-free targets do not expose select text', (tester) async {
    MarkdownSelectionMenuContext? capturedContext;
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: '---',
        selectionConfig: MarkdownSelectionConfig(
          initialMenuActions: [
            MarkdownSelectionMenuAction(
              id: 'custom',
              label: '自定义',
              onPressed: (context) {},
            )
          ],
          initialMenuBuilder: (context, menuContext) {
            capturedContext = menuContext;
            return Material(
              child: Text(menuContext.allActions.first.label),
            );
          },
        ),
      ),
    ));

    final target = tester
        .widget<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget).first,
        )
        .target;
    expect(target.type, MarkdownSelectionTargetType.horizontalRule);
    expect(target.canSelectText, isFalse);

    await tester.longPress(find.byType(MarkdownSelectionTargetWidget).first);
    await tester.pump();

    expect(capturedContext, isNotNull);
    expect(capturedContext!.builtInActions, isEmpty);
    expect(capturedContext!.applicationActions.single.label, '自定义');
    expect(find.text('选取文字'), findsNothing);
    expect(find.text('自定义'), findsOneWidget);
  });

  testWidgets('text-free targets without actions do not show menu',
      (tester) async {
    var menuBuilt = false;
    await tester.pumpWidget(testApp(
      MarkdownWidget(
        data: '---',
        selectionConfig: MarkdownSelectionConfig(
          initialMenuBuilder: (context, menuContext) {
            menuBuilt = true;
            return const Material(child: Text('menu'));
          },
        ),
      ),
    ));

    await tester.longPress(find.byType(MarkdownSelectionTargetWidget).first);
    await tester.pump();

    expect(menuBuilt, isFalse);
    expect(find.text('menu'), findsNothing);
    expect(find.text('选取文字'), findsNothing);
  });

  testWidgets('task checkbox is not a text selection target', (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: '- [ ] task item',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final targets = tester
        .widgetList<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget),
        )
        .map((widget) => widget.target)
        .toList();
    final checkboxTarget = targets.singleWhere(
      (target) => target.type == MarkdownSelectionTargetType.checkbox,
    );
    final listItemTarget = targets.singleWhere(
      (target) => target.type == MarkdownSelectionTargetType.listItem,
    );

    expect(checkboxTarget.canSelectText, isFalse);
    expect(listItemTarget.plainText.trim(), 'task item');
  });

  testWidgets('blockquote target contains all quote paragraphs',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: '> first paragraph\n>\n> second paragraph',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final blockquoteTargets = tester
        .widgetList<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget),
        )
        .map((widget) => widget.target)
        .where(
            (target) => target.type == MarkdownSelectionTargetType.blockquote)
        .toList();

    expect(blockquoteTargets, isNotEmpty);
    expect(blockquoteTargets.first.plainText, contains('first paragraph'));
    expect(blockquoteTargets.first.plainText, contains('second paragraph'));
  });

  testWidgets('inline markdown resolves to containing paragraph target',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: 'before **strong** [link](https://example.com) `code`',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final paragraphTargets = tester
        .widgetList<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget),
        )
        .map((widget) => widget.target)
        .where((target) => target.type == MarkdownSelectionTargetType.paragraph)
        .toList();

    expect(paragraphTargets, hasLength(1));
    expect(paragraphTargets.single.plainText, contains('before'));
    expect(paragraphTargets.single.plainText, contains('strong'));
    expect(paragraphTargets.single.plainText, contains('link'));
    expect(paragraphTargets.single.plainText, contains('code'));
  });

  testWidgets('table text exposes current cell targets', (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: '| A | B |\n| --- | --- |\n| C | D |',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final cellTexts = tester
        .widgetList<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget),
        )
        .map((widget) => widget.target)
        .where((target) => target.type == MarkdownSelectionTargetType.tableCell)
        .map((target) => target.plainText.trim())
        .toList();

    expect(cellTexts, containsAll(['A', 'B', 'C', 'D']));
  });

  testWidgets('heading code and nested quote expose semantic targets',
      (tester) async {
    await tester.pumpWidget(testApp(
      const MarkdownWidget(
        data: '# Heading\n\n```dart\nprint(1);\n```\n\n> outer\n> > inner',
        selectionConfig: MarkdownSelectionConfig(),
      ),
    ));

    final targets = tester
        .widgetList<MarkdownSelectionTargetWidget>(
          find.byType(MarkdownSelectionTargetWidget),
        )
        .map((widget) => widget.target)
        .toList();

    expect(
      targets
          .where((target) => target.type == MarkdownSelectionTargetType.heading)
          .map((target) => target.plainText.trim()),
      contains('Heading'),
    );
    expect(
      targets
          .where(
              (target) => target.type == MarkdownSelectionTargetType.codeBlock)
          .map((target) => target.plainText),
      contains(contains('print(1);')),
    );

    final blockquotes = targets
        .where(
            (target) => target.type == MarkdownSelectionTargetType.blockquote)
        .toList();
    expect(blockquotes.length, greaterThanOrEqualTo(2));
    expect(
      blockquotes.any((target) =>
          target.plainText.contains('inner') &&
          target.parentTags.contains(MarkdownTag.blockquote.name)),
      isTrue,
    );
  });
}
