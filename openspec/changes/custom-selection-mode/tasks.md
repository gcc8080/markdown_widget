## 1. Public API and Internal Models

- [x] 1.1 Add and export `MarkdownSelectionConfig`, menu builder contracts, menu action models, semantic target metadata, and selected-text context models; expose built-in actions as builder-controlled content so applications can hide or reorder "Select text".
- [x] 1.2 Add the optional `selectionConfig` parameter to `MarkdownWidget` and preserve the existing `SelectionArea` path when the configuration is absent.
- [x] 1.3 Ensure `MarkdownWidget(selectable: false)` bypasses both existing selection and the custom selection path even when `selectionConfig` is provided.

## 2. Semantic Selection Units

- [x] 2.1 Extend the Markdown generation pipeline to retain stable semantic selection-unit identities, plain text, ancestor metadata, and viewport geometry adapters only when custom mode is enabled.
- [x] 2.2 Add semantic-unit wrappers for headings, paragraphs, code blocks, table cells, and list-item direct content without breaking existing rendering customization hooks.
- [x] 2.3 Implement list-item resolution so initial selection includes only the current item's direct textual content and excludes checkbox controls and nested child lists.
- [x] 2.4 Implement block-quote resolution so pressing any nested content initializes selection to the nearest containing block quote, including multiple paragraphs in that quote.
- [x] 2.5 Mark images, horizontal rules, task-list checkbox controls, and other text-free nodes as targets that do not expose the built-in "Select text" action.
- [x] 2.6 Resolve inline links, emphasis, strong text, and inline code to their containing semantic block; preserve existing link tap behavior while making link long press open the custom menu first.

## 3. Controlled Selection Engine

- [x] 3.1 Implement an internal controlled root selection wrapper using Flutter `3.27.4` public `SelectionContainer`, `SelectionContainerDelegate`, `Selectable`, and `SelectionEvent` primitives without importing private Flutter members.
- [x] 3.2 Register semantic-unit selection delegates beneath the stable root and implement programmatic complete-unit selection for the resolved initial target.
- [x] 3.3 Render native-style selection highlight and draggable handles after initial selection and allow handle updates to cross Markdown block boundaries.
- [ ] 3.4 Keep logical selection state stable while `ListView.builder` children recycle and ensure handles disappear and reappear correctly when selected endpoints leave and return to the viewport.
- [x] 3.5 Expose internal controller operations for clear selection, selected plain-text retrieval, selected-region hit testing, and handle visibility updates.

## 4. Custom Menu and Gesture Lifecycle

- [x] 4.1 Intercept supported touch long presses in custom mode so a text-bearing target opens the initial overlay menu without immediately creating native selection.
- [x] 4.2 Omit "Select text" for text-free targets, show configured application actions when present, and suppress the initial menu when no action remains.
- [x] 4.3 Implement the "Select text" transition: close the initial menu, select the semantic unit, show handles, and open the selected-text overlay menu.
- [x] 4.4 Hide the selected-text menu when handle dragging starts and reopen it at the adjusted range when handle dragging ends without clearing selection.
- [x] 4.5 Hide the selected-text menu when page scrolling starts, preserve selection during scrolling, and do not automatically reopen the menu when scrolling ends.
- [x] 4.6 Preserve selection and reopen the selected-text menu when the user taps inside the active range; clear selection, handles, and menu when the user taps outside it.
- [x] 4.7 Implement copy and configured selected-text actions so selection, handles, and menu clear before the action executes; copy rendered plain text and preserve code-block line breaks.
- [x] 4.8 Clamp menu anchors to overlay bounds so custom menus remain visible near viewport edges.
- [x] 4.9 Preserve existing code-block copy button behavior and ensure pressing that button does not enter the custom selection flow.

## 5. Example and Documentation

- [x] 5.1 Add a runnable custom selection mode example under `example/` with customized initial and selected-text menus plus at least one additional application action.
- [x] 5.2 Document the opt-in API, semantic-block rules, menu lifecycle, builder control over built-in actions, plain-text copy semantics, Android/iOS touch scope, and first-release non-goals in package documentation.

## 6. Tests and Flutter 3.27.4 Verification

- [x] 6.1 Add regression tests proving the existing default selection path remains unchanged without `selectionConfig` and all selection paths remain disabled when `selectable` is `false`.
- [x] 6.2 Add widget tests for initial-menu behavior, including no immediate selection, builder hide/reorder of "Select text", link long press, and text-free targets with and without application actions.
- [x] 6.3 Add semantic initialization tests for headings, paragraphs, list-item direct content, task-list item text, nested lists, multi-paragraph block quotes, nested block quotes, code blocks, inline formatting, and table cells.
- [ ] 6.4 Add interaction tests for table-cell handle adjustment, cross-block handle dragging, drag-time menu hiding and restoration, tap-inside restoration, tap-outside clearing, and action-time clearing.
- [ ] 6.5 Add scroll tests proving selection survives endpoint scrolling out of and back into the viewport while menus remain hidden after scrolling ends.
- [x] 6.6 Repair or replace the local Flutter `3.27.4` FVM SDK if its Dart VM crash persists, then run formatter, analyzer, package widget tests, and example verification with Flutter `3.27.4`.
- [ ] 6.7 Manually verify Android and iOS touch long-press flows against the custom selection example under Flutter `3.27.4`.
