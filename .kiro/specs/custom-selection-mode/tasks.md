# Implementation Plan: Custom Selection Mode

## Overview

Implement a custom selection mode for `markdown_widget` that provides long-press context menus, element-level text selection, draggable selection handles for precise range adjustment, and cross-element continuous selection. The implementation follows an incremental approach: data models and interfaces first, then core logic, then UI components, and finally integration and wiring.

## Tasks

- [x] 1. Set up project structure and core data models
  - [x] 1.1 Create selection data models file
    - Create `lib/widget/selection/selection_models.dart`
    - Implement `SelectionState` enum (idle, contextMenuShown, textSelected, draggingHandle)
    - Implement `SelectionMenuItem` class with title, icon, and onPressed callback
    - Implement `TextSelectionRange` class with startElementIndex, startOffset, endElementIndex, endOffset
    - Implement `TextSelectionRange.normalize()` method to ensure start is before end
    - Implement `TextSelectionRange.isMultiElement` getter
    - Define `ContextMenuWidgetBuilder` typedef
    - _Requirements: 3.6, 6.7_

  - [x] 1.2 Write property test for menu item ordering (Property 2)
    - **Property 2: Custom menu items are appended after default items**
    - **Validates: Requirements 3.6**

  - [x] 1.3 Add new parameters to MarkdownWidget
    - Modify `lib/widget/markdown.dart` to add `customSelectionMode` (bool, default false), `contextMenuBuilder`, and `contextMenuItems` parameters
    - Update the constructor and pass parameters through
    - _Requirements: 1.1, 2.1, 2.3, 3.4, 3.5, 3.6_

  - [x] 1.4 Write property test for customSelectionMode disabling SelectionArea (Property 1)
    - **Property 1: customSelectionMode disables SelectionArea**
    - **Validates: Requirements 2.2**

- [x] 2. Implement HitTestHelper and SelectionManager
  - [x] 2.1 Implement HitTestHelper
    - Create `lib/widget/selection/hit_test_helper.dart`
    - Implement `findElementIndex()` to map global position to widget index using GlobalKeys and RenderBox
    - Implement `findTextOffset()` to find character offset within a RenderParagraph
    - Implement `isSelectableElement()` to check if element contains selectable text
    - Implement `getElementPlainText()` to extract plain text from a SpanNode
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [x] 2.2 Implement SelectionManager
    - Create `lib/widget/selection/selection_manager.dart`
    - Extend `ChangeNotifier` for reactive state management
    - Implement state machine transitions (idle → contextMenuShown → textSelected → draggingHandle)
    - Implement `hitTestElement()` using HitTestHelper
    - Implement `selectElement()` to select entire element text
    - Implement `updateSelectionStart()` and `updateSelectionEnd()` for handle dragging
    - Implement handle role swap logic when start crosses end
    - Implement `clearSelection()` and `getPlainText()`
    - _Requirements: 4.2, 4.7, 6.2, 6.3, 6.6, 6.7_

  - [x] 2.3 Write property test for text element full selection (Property 4)
    - **Property 4: Text elements are fully selected**
    - **Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6, 4.8**

  - [x] 2.4 Write property test for non-text elements not selectable (Property 5)
    - **Property 5: Non-text elements cannot be selected**
    - **Validates: Requirements 4.7**

  - [x] 2.5 Write property test for handle role swap (Property 9)
    - **Property 9: Handle role swap when crossing**
    - **Validates: Requirements 6.7**

- [x] 3. Checkpoint - Core logic verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement Context Menu components
  - [x] 4.1 Implement DefaultContextMenu widget
    - Create `lib/widget/selection/default_context_menu.dart`
    - Build default menu UI with rounded rectangle background, horizontal item layout
    - Support icon + text for each menu item
    - Handle item tap callbacks and menu close
    - _Requirements: 3.3, 3.8_

  - [x] 4.2 Implement ContextMenuOverlay manager
    - Create `lib/widget/selection/context_menu_overlay.dart`
    - Implement `show()` method using Flutter Overlay API
    - Position menu 8 logical pixels above touch point; fall back to below if insufficient space
    - Support `contextMenuBuilder` for custom menu rendering
    - Implement `hide()` method to remove overlay entry
    - Handle menu dismiss on outside tap
    - _Requirements: 3.1, 3.4, 3.5, 3.7, 3.8, 5.1, 5.6_

  - [x] 4.3 Write property test for menu item click behavior (Property 3)
    - **Property 3: Menu item click triggers callback and closes menu**
    - **Validates: Requirements 3.8**

- [x] 5. Implement selection visual components
  - [x] 5.1 Implement SelectionHighlightPainter
    - Create `lib/widget/selection/selection_highlight_painter.dart`
    - Use `CustomPainter` to draw semi-transparent highlight rectangles
    - Use `RenderParagraph.getBoxesForSelection()` to get text bounds
    - Support multi-element highlight painting (iterate over each element in range)
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.8_

  - [x] 5.2 Implement SelectionHandleWidget
    - Create `lib/widget/selection/selection_handle_widget.dart`
    - Render draggable handle widgets using Overlay + Positioned
    - Use `GestureDetector` for drag gesture handling
    - Calculate handle position via `RenderParagraph.getOffsetForCaret()`
    - Notify SelectionManager on drag updates
    - Hide context menu during drag, show on drag end
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 5.3 Write property test for handle drag updating selection boundary (Property 7)
    - **Property 7: Dragging handle updates selection boundary**
    - **Validates: Requirements 6.2, 6.3**

  - [x] 5.4 Write property test for cross-element continuous selection (Property 8)
    - **Property 8: Cross-element continuous selection**
    - **Validates: Requirements 6.6**

- [x] 6. Implement CustomSelectionOverlay and integrate
  - [x] 6.1 Implement CustomSelectionOverlay widget
    - Create `lib/widget/selection/custom_selection_overlay.dart`
    - Wrap child ListView with GestureDetector for long-press (500ms threshold)
    - Coordinate SelectionManager, ContextMenuOverlay, SelectionHighlightPainter, and SelectionHandleWidget
    - Assign GlobalKeys to each markdown widget for hit testing
    - Handle state transitions: long press → menu → select text → drag handles → copy
    - Implement outside-tap detection to dismiss menu and clear selection
    - _Requirements: 3.1, 3.2, 3.7, 4.1, 4.9, 4.10, 5.4, 6.4, 6.5_

  - [x] 6.2 Implement copy-to-clipboard functionality
    - Implement clipboard write using Flutter Clipboard API
    - Copy plain text only (strip Markdown syntax markers)
    - On success: close menu, clear selection
    - On failure: preserve selection state and menu (no state change)
    - _Requirements: 5.2, 5.3, 5.5_

  - [x] 6.3 Write property test for copy operation writing plain text (Property 6)
    - **Property 6: Copy operation writes plain text to clipboard**
    - **Validates: Requirements 5.2**

  - [x] 6.4 Wire CustomSelectionOverlay into MarkdownWidget build logic
    - Modify `_MarkdownWidgetState.buildMarkdownWidget()` in `lib/widget/markdown.dart`
    - When `customSelectionMode == true`: wrap ListView with CustomSelectionOverlay (skip SelectionArea)
    - When `customSelectionMode == false && selectable == true`: use SelectionArea (existing behavior)
    - When `customSelectionMode == false && selectable == false`: plain ListView (existing behavior)
    - Pass `contextMenuBuilder` and `contextMenuItems` to CustomSelectionOverlay
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.2, 2.4_

- [x] 7. Checkpoint - Full feature verification
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Error handling and edge cases
  - [x] 8.1 Implement error handling and boundary conditions
    - Handle long-press on empty area (no element hit): do not show menu
    - Handle long-press on non-text element + "select text" click: no selection, close menu
    - Limit selection boundary when handle dragged outside visible area
    - Clamp selection to first/last character at widget list boundaries
    - Safely close all Overlay entries when widget is disposed
    - Handle null RenderObject for GlobalKey (skip element)
    - Ensure minimum 1 character selection (prevent empty selection)
    - _Requirements: 5.5, 6.7_

  - [x] 8.2 Write unit tests for error handling scenarios
    - Test clipboard write failure preserves state
    - Test empty markdown content long-press handling
    - Test single-character element selection and handle drag
    - Test widget dispose overlay cleanup
    - _Requirements: 5.5_

- [x] 9. Create example code
  - [x] 9.1 Create custom selection mode example
    - Create `example/lib/custom_selection_example.dart`
    - Demonstrate enabling custom selection mode with `customSelectionMode: true`
    - Demonstrate custom Context Menu styling (background color, text style)
    - Demonstrate adding at least 1 custom menu item beyond default "select text" and "copy"
    - Include at least 3 inline comments explaining key integration steps
    - Ensure example compiles with Flutter SDK >=3.10.6
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 10. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The implementation uses Dart/Flutter as specified in the design document
- All selection UI components use Flutter's Overlay API for rendering above content
- The `glados` package is used for property-based testing as specified in the design

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "2.1"] },
    { "id": 3, "tasks": ["2.2"] },
    { "id": 4, "tasks": ["2.3", "2.4", "2.5", "4.1"] },
    { "id": 5, "tasks": ["4.2", "5.1", "5.2"] },
    { "id": 6, "tasks": ["4.3", "5.3", "5.4", "6.1"] },
    { "id": 7, "tasks": ["6.2", "6.4"] },
    { "id": 8, "tasks": ["6.3", "8.1"] },
    { "id": 9, "tasks": ["8.2", "9.1"] }
  ]
}
```
