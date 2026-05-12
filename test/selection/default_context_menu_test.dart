import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/widget/selection/default_context_menu.dart';
import 'package:markdown_widget/widget/selection/selection_models.dart';

void main() {
  group('DefaultContextMenu', () {
    testWidgets('renders all menu items with text', (tester) async {
      final items = [
        SelectionMenuItem(
          title: '选取文字',
          icon: Icons.text_fields,
          onPressed: (_, __) {},
        ),
        SelectionMenuItem(
          title: '复制',
          icon: Icons.copy,
          onPressed: (_, __) {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('选取文字'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('renders icons when provided', (tester) async {
      final items = [
        SelectionMenuItem(
          title: 'With Icon',
          icon: Icons.copy,
          onPressed: (_, __) {},
        ),
        SelectionMenuItem(
          title: 'No Icon',
          onPressed: (_, __) {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              onClose: () {},
            ),
          ),
        ),
      );

      // One icon widget for the item with icon
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
      expect(find.text('No Icon'), findsOneWidget);
    });

    testWidgets('calls onPressed with selectedText and onClose on tap',
        (tester) async {
      String? receivedText;
      VoidCallback? receivedCloseMenu;
      bool closeCalled = false;

      final items = [
        SelectionMenuItem(
          title: 'Test Item',
          onPressed: (text, closeMenu) {
            receivedText = text;
            receivedCloseMenu = closeMenu;
            closeMenu(); // Menu items are responsible for calling closeMenu
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              selectedText: 'Hello World',
              onClose: () {
                closeCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Item'));
      await tester.pump();

      expect(receivedText, equals('Hello World'));
      expect(receivedCloseMenu, isNotNull);
      expect(closeCalled, isTrue);
    });

    testWidgets('onPressed receives closeMenu callback (Requirement 3.8)',
        (tester) async {
      final callOrder = <String>[];

      final items = [
        SelectionMenuItem(
          title: 'Action',
          onPressed: (_, closeMenu) {
            callOrder.add('onPressed');
            closeMenu(); // Each menu item is responsible for closing the menu
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              onClose: () {
                callOrder.add('onClose');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Action'));
      await tester.pump();

      // onPressed is called, and it calls closeMenu which triggers onClose
      expect(callOrder, equals(['onPressed', 'onClose']));
    });

    testWidgets('passes null selectedText when not provided', (tester) async {
      String? receivedText = 'initial';

      final items = [
        SelectionMenuItem(
          title: 'Item',
          onPressed: (text, _) {
            receivedText = text;
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Item'));
      await tester.pump();

      expect(receivedText, isNull);
    });

    testWidgets('uses horizontal layout (Row) for items', (tester) async {
      final items = [
        SelectionMenuItem(title: 'A', onPressed: (_, __) {}),
        SelectionMenuItem(title: 'B', onPressed: (_, __) {}),
        SelectionMenuItem(title: 'C', onPressed: (_, __) {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              onClose: () {},
            ),
          ),
        ),
      );

      // Verify items are laid out horizontally by checking Row exists
      expect(find.byType(Row), findsWidgets);

      // Verify all items are rendered
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('has rounded rectangle decoration', (tester) async {
      final items = [
        SelectionMenuItem(title: 'Item', onPressed: (_, __) {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultContextMenu(
              items: items,
              onClose: () {},
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(8.0)));
      expect(decoration.color, equals(Colors.white));
    });
  });
}
