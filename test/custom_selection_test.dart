import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/widget/custom_selection/element_context.dart';
import 'package:markdown_widget/widget/custom_selection/element_type_detector.dart';
import 'package:markdown_widget/widget/custom_selection/custom_selectable_wrapper.dart';
import 'package:markdown_widget/widget/custom_selection/vendor/selectable_region_fork.dart';
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

  group('CustomSelectableWrapper widget (via MarkdownWidget)', () {
    setUp(() {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });

    testWidgets('renders content and wraps elements with GestureDetector',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownWidget(
            data: 'Long press me',
            enableCustomSelection: true,
            customSelectionConfig: const CustomSelectionConfig(enabled: true),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Long press me'), findsOneWidget);
      expect(find.byType(CustomSelectableWrapper), findsWidgets);
      // Custom mode uses the forked MdSelectableRegion (not Flutter SelectionArea).
      expect(find.byType(MdSelectableRegion), findsOneWidget);
      expect(find.byType(SelectionArea), findsNothing);
    });

    testWidgets('long press shows initial menu with 选取文字', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownWidget(
            data: 'Press here',
            enableCustomSelection: true,
            customSelectionConfig: const CustomSelectionConfig(enabled: true),
          ),
        ),
      ));
      await tester.pump();

      await tester.longPress(find.text('Press here'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

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

    testWidgets('tapping 选取文字 dismisses initial menu and enters selection phase',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownWidget(
            data: 'First paragraph here.\n\nSecond paragraph here.',
            enableCustomSelection: true,
            customSelectionConfig: const CustomSelectionConfig(enabled: true),
          ),
        ),
      ));
      await tester.pump();

      await tester.longPress(find.text('Second paragraph here.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('选取文字'), findsOneWidget);
      expect(find.byType(MdSelectableRegion), findsOneWidget);

      // Tap "选取文字" → initial menu should be gone; no clearSelection race.
      await tester.tap(find.text('选取文字'));
      await tester.pump();

      expect(find.text('选取文字'), findsNothing);
    });

    testWidgets('copy menu appears when selectedTextNotifier fires after 选取文字',
        (tester) async {
      final notifier = ValueNotifier<String>('');
      final regionKey = GlobalKey<MdSelectableRegionState>();
      const ctx = ElementContext(
        index: 0,
        elementType: 'paragraph',
        plainText: 'Hello world',
        fullMarkdown: 'Hello world',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MdSelectableRegion(
            key: regionKey,
            focusNode: FocusNode(),
            selectionControls: materialTextSelectionHandleControls,
            contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            child: CustomSelectableWrapper(
              elementContext: ctx,
              config: const CustomSelectionConfig(enabled: true),
              regionKey: regionKey,
              selectedTextNotifier: notifier,
              child: const Text('Hello world'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Long press → initial menu
      await tester.longPress(find.text('Hello world'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('选取文字'), findsOneWidget);

      // Tap "选取文字" — enters selection phase
      await tester.tap(find.text('选取文字'));
      await tester.pump();

      // Simulate selectRange producing a selection by updating the notifier directly
      notifier.value = 'Hello world';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('复制'), findsOneWidget);

      notifier.dispose();
    });

    testWidgets('long-press second list item selects only that item',
        (tester) async {
      String? copied;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownWidget(
            data: '- First item\n- Second item\n- Third item',
            enableCustomSelection: true,
            customSelectionConfig: CustomSelectionConfig(
              enabled: true,
              extension: MenuExtension(
                items: [
                  CustomMenuItem.withContext(
                    label: 'Grab',
                    onContextTap: (ctx) => copied = ctx.selectedText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Long press the second item, then 选取文字.
      await tester.longPress(find.text('Second item', findRichText: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('选取文字'), findsOneWidget);

      await tester.tap(find.text('选取文字'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Copy menu visible → tap our custom item to capture selection.
      expect(find.text('Grab'), findsOneWidget);
      await tester.tap(find.text('Grab'));
      await tester.pump();

      // Only the second item's text should be selected, not the whole list.
      expect(copied, isNotNull);
      expect(copied!.contains('Second item'), isTrue);
      expect(copied!.contains('First item'), isFalse);
      expect(copied!.contains('Third item'), isFalse);
    });
  });
}
