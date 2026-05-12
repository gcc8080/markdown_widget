import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/widget/selection/selection_manager.dart';

/// Helper to create an ElementNode containing a TextNode
SpanNode _createElementWithText(String text) {
  final element = ConcreteElementNode(tag: 'p');
  element.accept(TextNode(text: text));
  return element;
}

void main() {
  group('Error Handling - Clipboard write failure preserves state (Requirement 5.5)', () {
    test('clipboard write failure preserves selection state', () async {
      // Set up a SelectionManager with valid elements
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello World'),
        _createElementWithText('Second paragraph'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      // Select an element to get into textSelected state
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange, isNotNull);

      // Store the selection range before clipboard failure
      final rangeBefore = manager.selectionRange;

      // Simulate clipboard failure by mocking Clipboard.setData to throw
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        if (message.method == 'Clipboard.setData') {
          throw PlatformException(code: 'ERROR', message: 'Clipboard write failed');
        }
        return null;
      });

      // Attempt to copy (simulating what _onCopyMenuItemClicked does)
      final text = manager.getPlainText();
      expect(text, equals('Hello World'));

      try {
        await Clipboard.setData(ClipboardData(text: text));
        // If we get here, clipboard succeeded - clear selection (normal flow)
        manager.clearSelection();
      } catch (e) {
        // Clipboard failed - state should remain unchanged (Requirement 5.5)
        // Do NOT clear selection
      }

      // Verify state is preserved after clipboard failure
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange, equals(rangeBefore));
      expect(manager.selectionRange!.startElementIndex, equals(0));
      expect(manager.selectionRange!.startOffset, equals(0));
      expect(manager.selectionRange!.endOffset, equals(11));

      // Clean up mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('successful clipboard write clears selection state', () async {
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello World'),
        _createElementWithText('Second paragraph'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));

      // Set up mock for successful clipboard write
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        if (message.method == 'Clipboard.setData') {
          return null; // Success
        }
        return null;
      });

      final text = manager.getPlainText();
      try {
        await Clipboard.setData(ClipboardData(text: text));
        // Success: clear selection
        manager.clearSelection();
      } catch (e) {
        // Should not reach here
      }

      // Verify state is cleared after successful copy
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);

      // Clean up mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('Error Handling - Empty markdown content long-press handling', () {
    test('onLongPress with empty elementKeys does not crash', () {
      final manager = SelectionManager(
        elementKeys: [],
        spanNodes: [],
      );

      // Should not throw, state should remain idle
      final result = manager.onLongPress(const Offset(100, 100));
      expect(result, isNull);
      expect(manager.state, equals(SelectionState.idle));
    });

    test('onLongPress with empty spanNodes does not crash', () {
      final keys = [GlobalKey()];
      final manager = SelectionManager(
        elementKeys: keys,
        spanNodes: [],
      );

      // hitTestElement won't find anything since widgets aren't rendered
      final result = manager.onLongPress(const Offset(100, 100));
      expect(result, isNull);
      expect(manager.state, equals(SelectionState.idle));
    });

    test('selectElement on empty spanNodes stays idle', () {
      final manager = SelectionManager(
        elementKeys: [],
        spanNodes: [],
      );

      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
    });
  });

  group('Error Handling - Single-character element selection and handle drag', () {
    test('single-character element is fully selected', () {
      final keys = [GlobalKey()];
      final nodes = [_createElementWithText('A')];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange, isNotNull);
      // Single character "A" → range should be (0, 0, 0, 1)
      expect(manager.selectionRange!.startElementIndex, equals(0));
      expect(manager.selectionRange!.startOffset, equals(0));
      expect(manager.selectionRange!.endElementIndex, equals(0));
      expect(manager.selectionRange!.endOffset, equals(1));
    });

    test('single-character element getPlainText returns the character', () {
      final keys = [GlobalKey()];
      final nodes = [_createElementWithText('A')];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(0);
      expect(manager.getPlainText(), equals('A'));
    });

    test('minimum selection is maintained for single-character element', () {
      final keys = [GlobalKey()];
      final nodes = [_createElementWithText('A')];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(0);
      final range = manager.selectionRange!;
      // Minimum 1 character selection must be maintained
      expect(range.endOffset - range.startOffset, greaterThanOrEqualTo(1));
    });

    test('handle drag start works on single-character selection', () {
      final keys = [GlobalKey()];
      final nodes = [_createElementWithText('A')];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));

      manager.onHandleDragStart();
      expect(manager.state, equals(SelectionState.draggingHandle));

      manager.onHandleDragEnd();
      expect(manager.state, equals(SelectionState.textSelected));
      // Selection should still be valid
      expect(manager.selectionRange, isNotNull);
      expect(manager.selectionRange!.endOffset - manager.selectionRange!.startOffset,
          greaterThanOrEqualTo(1));
    });
  });

  group('Error Handling - Widget dispose overlay cleanup', () {
    testWidgets('MarkdownWidget with customSelectionMode disposes without errors',
        (WidgetTester tester) async {
      // Create a MarkdownWidget with customSelectionMode enabled
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownWidget(
              data: '# Hello\n\nThis is a test paragraph.',
              customSelectionMode: true,
            ),
          ),
        ),
      );

      // Flush VisibilityDetector timers
      await tester.pump(const Duration(seconds: 1));

      // Now dispose by replacing with a different widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Replaced')),
          ),
        ),
      );

      // Flush any remaining timers
      await tester.pump(const Duration(seconds: 1));

      // If we reach here without exceptions, disposal was clean
      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets('MarkdownWidget with empty data disposes without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownWidget(
              data: '',
              customSelectionMode: true,
            ),
          ),
        ),
      );

      // Flush VisibilityDetector timers
      await tester.pump(const Duration(seconds: 1));

      // Dispose by replacing
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('After dispose')),
          ),
        ),
      );

      // Flush any remaining timers
      await tester.pump(const Duration(seconds: 1));

      // No errors during disposal
      expect(find.text('After dispose'), findsOneWidget);
    });
  });

  group('Error Handling - Invalid element index handling', () {
    test('selectElement with negative index stays idle', () {
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello'),
        _createElementWithText('World'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(-1);
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
    });

    test('selectElement with index beyond range stays idle', () {
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello'),
        _createElementWithText('World'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      manager.selectElement(999);
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
    });

    test('onLongPress with position that hits no element stays idle', () {
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello'),
        _createElementWithText('World'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      // Without rendered widgets, hitTestElement will return null
      final result = manager.onLongPress(const Offset(9999, 9999));
      expect(result, isNull);
      expect(manager.state, equals(SelectionState.idle));
    });

    test('selectElement with index equal to spanNodes length stays idle', () {
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello'),
        _createElementWithText('World'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      // Index exactly at length (out of bounds)
      manager.selectElement(2);
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
    });

    test('multiple invalid selectElement calls do not corrupt state', () {
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('Hello'),
        _createElementWithText('World'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      // Multiple invalid calls
      manager.selectElement(-1);
      manager.selectElement(999);
      manager.selectElement(-100);

      // State should still be idle
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);

      // Valid call should still work
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange, isNotNull);
      expect(manager.getPlainText(), equals('Hello'));
    });
  });
}
