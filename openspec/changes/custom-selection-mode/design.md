## Context

`MarkdownWidget` currently builds a `ListView` and conditionally wraps the entire list in Flutter's `SelectionArea`. `MarkdownGenerator.buildWidgets()` parses Markdown into a `SpanNode` tree but then returns only rendered widgets. Nested structures such as lists, block quotes, tables, and code blocks introduce additional `WidgetSpan -> ProxyRichText` layers, so a top-level list item key is not sufficient to identify the semantic block pressed by the user.

Flutter `3.27.4` exposes the rendering selection protocol through `SelectionContainer`, `SelectionContainerDelegate`, `Selectable`, and `SelectionEvent`. It does not expose all of the `SelectableRegionState` methods needed to programmatically set an arbitrary range and control handle and toolbar visibility. The custom mode therefore needs a controlled root selection wrapper that uses public Flutter selection primitives and keeps menu state separate from the native handle overlay.

The required interaction is touch-oriented:

```text
idle
  -> long press selectable content
initial menu, no selection
  -> choose "Select text"
semantic block selected, handles visible, selected-text menu visible
  -> drag a handle
selection remains active, menu hidden
  -> finish dragging
selection remains active, selected-text menu visible
  -> scroll
selection remains active, menu hidden until a tap inside the selection
  -> tap outside selection or invoke a menu action
idle
```

## Goals / Non-Goals

**Goals:**

- Preserve the current `MarkdownWidget(selectable: true)` behavior unless custom mode is explicitly enabled.
- Resolve a touch position to a text-bearing Markdown semantic unit and initialize selection to the unit's complete text.
- Keep one stable selection system so users can drag native-style handles across Markdown units after initialization.
- Preserve selection while selected endpoints scroll off-screen and restore visible handles when the endpoints return.
- Allow applications to style and extend both the initial long-press menu and the selected-text menu.
- Provide a runnable example and widget-level regression tests under Flutter `3.27.4`.

**Non-Goals:**

- Adding custom mode to `MarkdownBlock` in the first release.
- Replacing existing default `SelectionArea` behavior when custom mode is disabled.
- Guaranteeing desktop mouse-specific or Web browser-native context-menu behavior in the first release.
- Copying Markdown source syntax or rich clipboard formats. The initial implementation copies rendered plain text.
- Treating images, horizontal rules, or other text-free nodes as text-selection targets.

## Decisions

### 1. Enable custom mode through an optional configuration object

Add an optional `MarkdownSelectionConfig? selectionConfig` parameter to `MarkdownWidget`. `null` means the existing selection path remains unchanged. Custom mode is active only when `selectable == true` and `selectionConfig != null`; `selectable == false` disables both native and custom selection behavior.

The configuration exposes builders for:

- the initial long-press action menu;
- the selected-text action menu;
- additional application actions for each menu.

Builders receive menu anchors, semantic target metadata, selected plain text where applicable, and controlled actions such as select text, copy, dismiss, and invoke application action.

**Alternative considered:** add a separate boolean flag and multiple callback parameters directly on `MarkdownWidget`. This is rejected because the feature has several extension points and lifecycle policies that should evolve as one cohesive configuration.

### 2. Retain semantic selection units during rendering

Introduce an internal semantic model for selection targets. Each selectable unit records at least:

- Markdown tag and semantic kind;
- rendered plain text;
- ancestor semantic kinds;
- stable identity within the generated document;
- a render key or equivalent hit-test boundary;
- whether the unit can expose "Select text";
- enough boundary information to initialize its complete range.

`MarkdownGenerator` and relevant `SpanNode` builders retain selection metadata only when custom mode is enabled. The model must support nested units rather than assuming one top-level AST node equals one selection unit.

Target resolution follows these rules:

| Pressed content | Initial semantic unit |
| --- | --- |
| `h1` through `h6` | complete heading |
| `p` | complete paragraph |
| `li` | direct textual content of the current list item, excluding nested child lists |
| content inside `blockquote` | complete outer block quote, including all paragraphs inside it |
| `pre` code block | complete code block |
| inline link, emphasis, strong text, inline code | containing semantic block |
| table text | current cell |
| image, horizontal rule, other text-free node | no text-selection target |

Block-quote resolution intentionally overrides nested paragraph and list-item granularity. Nested lists remain independent targets when they are not inside a block quote.

**Alternative considered:** attach a key only to widgets returned by `MarkdownGenerator.buildWidgets()`. This is rejected because list items, block-quote contents, table cells, and code lines can render inside nested `WidgetSpan` trees.

### 3. Use one controlled root selection system

Custom mode uses one root selection wrapper around the Markdown list. Semantic units register controlled `SelectionContainer` delegates beneath the root. Choosing "Select text" dispatches selection events to the resolved unit so it selects its complete range. After initialization, normal edge-update events continue through the root tree, allowing handle dragging to expand across units.

The controlled wrapper owns the handle overlay and exposes explicit operations:

- select a semantic unit;
- clear selection;
- test whether a global position is inside the selected region;
- show or hide handles;
- show or hide the selected-text menu;
- retrieve selected plain text.

The implementation uses Flutter `3.27.4` public rendering selection primitives. It must not import Flutter private library members.

**Alternative considered:** rebuild a nested `SelectionArea` only after the user taps "Select text". This is rejected because nested selection regions isolate ranges, make cross-block dragging unreliable, and risk losing state when `ListView.builder` recycles children.

### 4. Manage menus independently from the native handle overlay

Use application-owned overlay entries for both menus. This permits exact lifecycle behavior without depending on the private toolbar methods of `SelectableRegionState`.

- Long press on a text-bearing target opens the initial menu without creating a selection.
- Long press on a text-free target omits "Select text"; the initial menu appears only if application actions remain.
- Choosing "Select text" closes the initial menu, initializes the semantic-unit selection, shows handles, and opens the selected-text menu.
- Starting a handle drag hides the selected-text menu without clearing selection.
- Finishing a handle drag reopens the selected-text menu at the updated range.
- Starting page scrolling hides the menu without clearing selection. Stopping scrolling does not reopen it.
- Tapping inside the active selection preserves the range and handles and reopens the selected-text menu.
- Tapping outside the active selection clears the range, handles, and menu.
- Invoking copy or any selected-text application action clears the range, handles, and menu before executing the action.

Menus clamp their anchor to the available overlay bounds so they remain usable near screen edges.

### 5. Preserve native scroll-selection behavior

Selection state lives in the stable root controller rather than in visible menu widgets. During scrolling, the controller keeps the active range while overlay menus are removed. Flutter's scrollable selection integration and selection geometry notifications are used so off-screen endpoint handles disappear naturally and become visible again when their endpoints return to the viewport.

Tests must include scrolling a selected endpoint out of view and back into view without clearing selection.

### 6. Keep copy semantics plain-text first

Copy uses the current adjusted selection and writes rendered plain text to the clipboard. Code-block text retains line breaks. List-item initial selection excludes nested child-list text, but users can include additional content by dragging the handles after initialization.

**Alternative considered:** expose Markdown source slices. This is deferred because the current parser pipeline does not retain source offsets and reconstructed Markdown would not reliably match the original input.

## Risks / Trade-offs

- **Flutter selection APIs are complex and version-sensitive** -> Pin verification to Flutter `3.27.4`, isolate the controlled wrapper behind internal classes, and add focused widget tests for event transitions.
- **Nested `WidgetSpan` layouts can produce unexpected selection geometry** -> Add semantic-unit tests for list items, multi-paragraph block quotes, code blocks, and table cells before broadening element support.
- **`ListView.builder` recycling may invalidate visible render keys** -> Keep logical selection state in the root controller and treat render keys as viewport geometry adapters, not as the source of truth.
- **Custom builders can return oversized menus** -> Provide bounded anchors and document that builders must render within overlay constraints.
- **Desktop and Web behavior differs from touch platforms** -> Leave those platform-specific custom interactions outside the first release while retaining the existing default path when custom mode is not enabled.

## Migration Plan

1. Add the optional configuration and internal selection model without changing the default path.
2. Implement the controlled custom path behind `selectionConfig != null && selectable`.
3. Add regression tests for the existing default path and focused tests for custom mode.
4. Add an example page demonstrating both built-in and additional actions.
5. Verify formatting, analysis, and widget tests with Flutter `3.27.4`.

Rollback is straightforward: callers can remove `selectionConfig` to return to the existing `SelectionArea` behavior.

## Open Questions

- Whether a later release should add the same configuration to `MarkdownBlock`.
- Whether desktop right-click and Web browser context-menu integration should use the same builders or platform-specific builders.
- Whether a later release should support rich clipboard formats or original Markdown source slices.
