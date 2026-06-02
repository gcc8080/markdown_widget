## Why

`MarkdownWidget` currently relies on Flutter's `SelectionArea`, which immediately starts native text selection on long press and exposes limited control over menu appearance and initial selection scope. Business integrations need a two-stage interaction that first presents a customizable action menu and then selects the smallest meaningful Markdown block when the user explicitly chooses to select text.

## What Changes

- Add an opt-in custom selection mode for `MarkdownWidget`; existing `selectable` behavior remains unchanged when the mode is not enabled.
- Add a customizable first-stage long-press menu. Text-bearing Markdown elements expose a built-in "Select text" action alongside application-defined actions.
- Programmatically initialize selection to the smallest semantic block associated with the pressed content:
  - headings select the complete heading;
  - paragraphs select the complete paragraph;
  - list items select only the current item's direct content, excluding nested child lists;
  - block quotes select the complete quote, including all paragraphs inside it;
  - code blocks select the complete code block;
  - inline formatting and links resolve to their containing block;
  - non-text elements such as images and horizontal rules do not expose "Select text".
- Reuse native-style selection highlight and draggable handles after text selection starts, while using a customizable selected-text action menu that includes copy and application-defined actions.
- Preserve selection while scrolling. Hide the selected-text menu during scrolling and handle dragging; restore it after handle dragging ends, but not automatically after scrolling ends.
- Clear the selection, handles, and menu when the user taps outside the selected region or invokes a menu action. Tapping inside the selected region preserves the selection and reopens the selected-text menu.
- Add an example under `example/` demonstrating custom selection mode and at least one additional custom action.
- Validate the implementation against Flutter `3.27.4`.

## Capabilities

### New Capabilities

- `markdown-custom-selection`: Opt-in two-stage custom text selection for `MarkdownWidget`, including semantic block initialization, custom menus, native-style handle adjustment, and selection lifecycle rules.

### Modified Capabilities

None.

## Impact

- Public API: `MarkdownWidget` gains an optional custom selection configuration while retaining the existing `selectable` parameter and default behavior.
- Rendering pipeline: Markdown render output must retain semantic metadata and hit-testable boundaries for selectable block units.
- Selection layer: a controlled selection integration is required to initialize semantic block ranges while preserving cross-block handle dragging and scroll persistence.
- Example application and widget tests gain coverage for custom mode, default compatibility, semantic block selection, menu lifecycle, and scrolling.
- First release scope targets touch long-press interaction on Android and iOS. `MarkdownBlock`, desktop mouse-specific behavior, and Web browser-native context-menu integration are not part of this change.
