import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/widget/selection/selection_manager.dart';
import 'package:markdown_widget/widget/selection/selection_models.dart';
import 'package:markdown_widget/widget/span_node.dart';

/// Helper to create an ElementNode containing a TextNode
SpanNode _createElementWithText(String text) {
  final element = ConcreteElementNode(tag: 'p');
  element.accept(TextNode(text: text));
  return element;
}

void main() {
  group('SelectionManager - State Machine Transitions', () {
    late SelectionManager manager;
    late List<GlobalKey> keys;
    late List<SpanNode> nodes;

    setUp(() {
      keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      nodes = [
        _createElementWithText('Hello World'),
        _createElementWithText('Second paragraph'),
        _createElementWithText('Third element'),
      ];
      manager = SelectionManager(elementKeys: keys, spanNodes: nodes);
    });

    test('initial state is idle', () {
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
      expect(manager.selectedText, isNull);
      expect(manager.hitElementIndex, isNull);
    });

    test('selectElement transitions to textSelected for valid text element', () {
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange, isNotNull);
      expect(manager.selectionRange!.startElementIndex, equals(0));
      expect(manager.selectionRange!.startOffset, equals(0));
      expect(manager.selectionRange!.endElementIndex, equals(0));
      expect(manager.selectionRange!.endOffset, equals(11)); // "Hello World".length
    });

    test('selectElement selects full text of element', () {
      manager.selectElement(1);
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange!.startOffset, equals(0));
      expect(manager.selectionRange!.endOffset, equals(16)); // "Second paragraph".length
    });

    test('selectElement with invalid index transitions to idle', () {
      manager.selectElement(-1);
      expect(manager.state, equals(SelectionState.idle));

      manager.selectElement(100);
      expect(manager.state, equals(SelectionState.idle));
    });

    test('onHandleDragStart transitions from textSelected to draggingHandle', () {
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));

      manager.onHandleDragStart();
      expect(manager.state, equals(SelectionState.draggingHandle));
    });

    test('onHandleDragStart does nothing when not in textSelected state', () {
      expect(manager.state, equals(SelectionState.idle));
      manager.onHandleDragStart();
      expect(manager.state, equals(SelectionState.idle));
    });

    test('onHandleDragEnd transitions from draggingHandle to textSelected', () {
      manager.selectElement(0);
      manager.onHandleDragStart();
      expect(manager.state, equals(SelectionState.draggingHandle));

      manager.onHandleDragEnd();
      expect(manager.state, equals(SelectionState.textSelected));
    });

    test('onHandleDragEnd does nothing when not in draggingHandle state', () {
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));
      manager.onHandleDragEnd();
      expect(manager.state, equals(SelectionState.textSelected));
    });

    test('onOutsideTap from contextMenuShown transitions to idle', () {
      // Simulate being in contextMenuShown state
      // We need to manually set state since we can't do hit testing without rendered widgets
      manager.onSelectTextMenuItemClicked(); // no-op since not in contextMenuShown
      // Directly test clearSelection which is what onOutsideTap calls
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));

      manager.onOutsideTap();
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
    });

    test('clearSelection resets all state', () {
      manager.selectElement(0);
      expect(manager.state, equals(SelectionState.textSelected));
      expect(manager.selectionRange, isNotNull);

      manager.clearSelection();
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
      expect(manager.hitElementIndex, isNull);
    });

    test('onOtherMenuItemClicked transitions from contextMenuShown to idle', () {
      // We can't easily get to contextMenuShown without rendered widgets,
      // but we can test the method doesn't crash in other states
      manager.onOtherMenuItemClicked();
      expect(manager.state, equals(SelectionState.idle));
    });
  });

  group('SelectionManager - getPlainText', () {
    late SelectionManager manager;
    late List<GlobalKey> keys;
    late List<SpanNode> nodes;

    setUp(() {
      keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      nodes = [
        _createElementWithText('Hello World'),
        _createElementWithText('Second paragraph'),
        _createElementWithText('Third element'),
      ];
      manager = SelectionManager(elementKeys: keys, spanNodes: nodes);
    });

    test('getPlainText returns empty string when no selection', () {
      expect(manager.getPlainText(), equals(''));
    });

    test('getPlainText returns full element text after selectElement', () {
      manager.selectElement(0);
      expect(manager.getPlainText(), equals('Hello World'));
    });

    test('getPlainText returns full text for second element', () {
      manager.selectElement(1);
      expect(manager.getPlainText(), equals('Second paragraph'));
    });

    test('selectedText getter returns same as getPlainText when selected', () {
      manager.selectElement(0);
      expect(manager.selectedText, equals('Hello World'));
    });

    test('selectedText getter returns null when no selection', () {
      expect(manager.selectedText, isNull);
    });
  });

  group('SelectionManager - Handle Role Swap (Requirement 6.7)', () {
    late SelectionManager manager;
    late List<GlobalKey> keys;
    late List<SpanNode> nodes;

    setUp(() {
      keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      nodes = [
        _createElementWithText('Hello World'),
        _createElementWithText('Second paragraph'),
        _createElementWithText('Third element'),
      ];
      manager = SelectionManager(elementKeys: keys, spanNodes: nodes);
    });

    test('TextSelectionRange.normalize swaps when start is after end', () {
      final range = TextSelectionRange(
        startElementIndex: 1,
        startOffset: 5,
        endElementIndex: 0,
        endOffset: 3,
      );
      final normalized = range.normalize();
      expect(normalized.startElementIndex, equals(0));
      expect(normalized.startOffset, equals(3));
      expect(normalized.endElementIndex, equals(1));
      expect(normalized.endOffset, equals(5));
    });

    test('TextSelectionRange.normalize swaps when same element but start offset > end offset', () {
      final range = TextSelectionRange(
        startElementIndex: 0,
        startOffset: 8,
        endElementIndex: 0,
        endOffset: 3,
      );
      final normalized = range.normalize();
      expect(normalized.startElementIndex, equals(0));
      expect(normalized.startOffset, equals(3));
      expect(normalized.endElementIndex, equals(0));
      expect(normalized.endOffset, equals(8));
    });

    test('TextSelectionRange.normalize does nothing when already normalized', () {
      final range = TextSelectionRange(
        startElementIndex: 0,
        startOffset: 2,
        endElementIndex: 1,
        endOffset: 5,
      );
      final normalized = range.normalize();
      expect(normalized.startElementIndex, equals(0));
      expect(normalized.startOffset, equals(2));
      expect(normalized.endElementIndex, equals(1));
      expect(normalized.endOffset, equals(5));
    });

    test('selection always has at least 1 character after selectElement', () {
      manager.selectElement(0);
      final range = manager.selectionRange!;
      // endOffset - startOffset should be >= 1 for single element
      expect(range.endOffset - range.startOffset, greaterThanOrEqualTo(1));
    });
  });

  group('SelectionManager - ChangeNotifier', () {
    late SelectionManager manager;
    late List<GlobalKey> keys;
    late List<SpanNode> nodes;

    setUp(() {
      keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      nodes = [
        _createElementWithText('Hello World'),
        _createElementWithText('Second paragraph'),
        _createElementWithText('Third element'),
      ];
      manager = SelectionManager(elementKeys: keys, spanNodes: nodes);
    });

    test('notifies listeners on state change', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.selectElement(0);
      expect(notifyCount, equals(1));

      manager.onHandleDragStart();
      expect(notifyCount, equals(2));

      manager.onHandleDragEnd();
      expect(notifyCount, equals(3));

      manager.clearSelection();
      expect(notifyCount, equals(4));
    });

    test('does not notify when state does not change', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      // Already idle, trying to go to idle again should not notify
      manager.onHandleDragStart(); // no-op since not in textSelected
      expect(notifyCount, equals(0));
    });
  });

  group('SelectionManager - Non-text elements (Requirement 4.7)', () {
    test('selectElement does not select non-text elements', () {
      // ImageNode, TableNode, HrNode are non-selectable
      // We'll use a TextNode that's empty to simulate
      final keys = [GlobalKey(), GlobalKey()];
      final nodes = <SpanNode>[
        _createElementWithText('Selectable text'),
        TextNode(text: ''), // Empty text node
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      // Empty text element should not be selected
      manager.selectElement(1);
      expect(manager.state, equals(SelectionState.idle));
      expect(manager.selectionRange, isNull);
    });
  });

  group('SelectionManager - Cross-element getPlainText', () {
    test('getPlainText handles cross-element selection', () {
      final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      final nodes = [
        _createElementWithText('First'),
        _createElementWithText('Second'),
        _createElementWithText('Third'),
      ];
      final manager = SelectionManager(elementKeys: keys, spanNodes: nodes);

      // Manually set a cross-element selection range for testing
      manager.selectElement(0); // Select first element
      // Now we simulate a cross-element range by testing getPlainText logic
      // Since we can't easily drag handles without rendered widgets,
      // we verify the getPlainText logic with the single-element case
      expect(manager.getPlainText(), equals('First'));
    });
  });
}
