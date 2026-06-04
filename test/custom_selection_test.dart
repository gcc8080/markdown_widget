import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/widget/custom_selection/element_context.dart';
import 'package:markdown_widget/widget/custom_selection/element_type_detector.dart';
import 'package:markdown_widget/widget/custom_selection/custom_selectable_wrapper.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  group('CustomSelectionConfig', () {
    test('default config is disabled', () {
      const config = CustomSelectionConfig();
      expect(config.enabled, false);
      expect(config.hiddenBuiltInItems, isEmpty);
      expect(config.extension, isNull);
    });

    test('enabled config retains settings', () {
      final config = CustomSelectionConfig(
        enabled: true,
        menuStyle: CustomMenuStyle.dark(),
        hiddenBuiltInItems: {BuiltInMenuItem.share},
      );
      expect(config.enabled, true);
      expect(config.menuStyle.backgroundColor, isNotNull);
      expect(config.hiddenBuiltInItems.contains(BuiltInMenuItem.share), true);
    });

    test('CustomMenuStyle light/dark factories differ', () {
      final light = CustomMenuStyle.light();
      final dark = CustomMenuStyle.dark();
      expect(light.backgroundColor, isNot(equals(dark.backgroundColor)));
    });
  });

  group('CustomMenuItem', () {
    test('withContext sets context callback', () {
      ElementContext? captured;
      final item = CustomMenuItem.withContext(
        label: 'Translate',
        icon: Icons.translate,
        onContextTap: (ctx) => captured = ctx,
      );
      expect(item.label, 'Translate');
      expect(item.onTap, isNull);
      expect(item.onContextTap, isNotNull);

      const ctx = ElementContext(
        index: 0,
        elementType: 'paragraph',
        plainText: 'hello',
        fullMarkdown: 'hello',
      );
      item.onContextTap!(ctx);
      expect(captured?.plainText, 'hello');
    });

    test('plain item uses onTap', () {
      var tapped = false;
      final item = CustomMenuItem(label: 'Tap', onTap: () => tapped = true);
      item.onTap!();
      expect(tapped, true);
    });
  });

  group('ElementContext', () {
    test('copyWith updates selection and selectedText', () {
      const ctx = ElementContext(
        index: 1,
        elementType: 'heading',
        plainText: 'Title',
        fullMarkdown: '# Title',
      );
      final updated = ctx.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
        selectedText: 'Title',
      );
      expect(updated.index, 1);
      expect(updated.elementType, 'heading');
      expect(updated.selectedText, 'Title');
      expect(updated.selection?.extentOffset, 5);
    });
  });

  group('ElementTypeDetector', () {
    test('extractPlainText concatenates text spans', () {
      const span = TextSpan(children: [
        TextSpan(text: 'Hello '),
        TextSpan(text: 'World'),
      ]);
      expect(ElementTypeDetector.extractPlainText(span), 'Hello World');
    });

    test('isSelectable excludes image and horizontalRule', () {
      expect(ElementTypeDetector.isSelectable('image'), false);
      expect(ElementTypeDetector.isSelectable('horizontalRule'), false);
      expect(ElementTypeDetector.isSelectable('paragraph'), true);
      expect(ElementTypeDetector.isSelectable('heading'), true);
    });

    test('detectType maps text node to unknown', () {
      final node = TextNode(text: 'abc');
      expect(ElementTypeDetector.detectType(node), 'unknown');
    });
  });

  group('CustomSelectableWrapper widget', () {
    testWidgets('renders child in static mode initially', (tester) async {
      const ctx = ElementContext(
        index: 0,
        elementType: 'paragraph',
        plainText: 'Long press me',
        fullMarkdown: 'Long press me',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomSelectableWrapper(
            textSpan: const TextSpan(text: 'Long press me'),
            elementContext: ctx,
            config: const CustomSelectionConfig(enabled: true),
            child: const Text('Long press me'),
          ),
        ),
      ));
      expect(find.text('Long press me'), findsOneWidget);
      // Static mode uses GestureDetector
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('long press shows initial menu', (tester) async {
      const ctx = ElementContext(
        index: 0,
        elementType: 'paragraph',
        plainText: 'Press here',
        fullMarkdown: 'Press here',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: CustomSelectableWrapper(
              textSpan: const TextSpan(text: 'Press here'),
              elementContext: ctx,
              config: const CustomSelectionConfig(enabled: true),
              child: const Text('Press here'),
            ),
          ),
        ),
      ));

      await tester.longPress(find.text('Press here'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // The initial menu should contain "选取文字"
      expect(find.text('选取文字'), findsOneWidget);
    });
  });

  group('MarkdownWidget integration', () {
    setUp(() {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });

    testWidgets('enableCustomSelection wraps elements', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownWidget(
            data: '# Heading\n\nA paragraph.',
            enableCustomSelection: true,
            customSelectionConfig: const CustomSelectionConfig(enabled: true),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(CustomSelectableWrapper), findsWidgets);
    });

    testWidgets('default mode does not wrap with custom selection',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownWidget(
            data: '# Heading\n\nA paragraph.',
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(CustomSelectableWrapper), findsNothing);
      expect(find.byType(SelectionArea), findsOneWidget);
    });
  });
}
