## ADDED Requirements

### Requirement: CustomSelectableRegion replaces default long-press behavior
The `CustomSelectableRegion` widget SHALL intercept the default `SelectableRegion` long-press gesture and delegate it to an external `onLongPress` callback instead of immediately selecting a word.

#### Scenario: Long-press delegates to callback
- **WHEN** user long-presses inside a `CustomSelectableRegion`
- **THEN** the system SHALL NOT select a word; instead it SHALL invoke the `onLongPress(Offset globalPosition)` callback

#### Scenario: Default context menu suppressed
- **WHEN** `CustomSelectableRegion` is active
- **THEN** the system SHALL NOT show the default Flutter text selection context menu (cut/copy/paste/select all)

---

### Requirement: Programmatic selection API
The `CustomSelectableRegion` SHALL expose a programmatic API via `CustomSelectableRegionState` to select text by coordinate range, show/hide handles, get selected content, and clear selection.

#### Scenario: selectRange selects text between coordinates
- **WHEN** `selectRange(Offset start, Offset end)` is called
- **THEN** the system SHALL select all text between the start and end coordinates and render the selection highlight

#### Scenario: showHandles displays drag handles
- **WHEN** `showHandles()` is called after a selection is made
- **THEN** the system SHALL display start and end drag handles at the selection boundaries

#### Scenario: hideHandles removes drag handles
- **WHEN** `hideHandles()` is called while handles are visible
- **THEN** the system SHALL remove the drag handles without clearing the selection

#### Scenario: getSelectedContent returns selected text
- **WHEN** `getSelectedContent()` is called while text is selected
- **THEN** the system SHALL return the currently selected plain text string

#### Scenario: clearSelection removes all selection state
- **WHEN** `clearSelection()` is called
- **THEN** the system SHALL remove the selection highlight, hide handles, and reset to idle state

---

### Requirement: Handle drag callbacks
The `CustomSelectableRegion` SHALL invoke `onHandleDragStart` and `onHandleDragEnd` callbacks when the user begins and finishes dragging a selection handle.

#### Scenario: Drag start callback
- **WHEN** user begins dragging a selection handle
- **THEN** the system SHALL invoke `onHandleDragStart()`

#### Scenario: Drag end callback
- **WHEN** user finishes dragging a selection handle
- **THEN** the system SHALL invoke `onHandleDragEnd()`

---

### Requirement: Selection highlight color customizable
The `CustomSelectableRegion` SHALL accept an optional `selectionColor` parameter. When provided, the selection highlight SHALL use this color instead of the system default.

#### Scenario: Custom selection color applied
- **WHEN** `selectionColor` is set to `Colors.blue.withOpacity(0.3)`
- **THEN** the selection highlight SHALL render with the specified blue translucent color

#### Scenario: Default selection color when not specified
- **WHEN** `selectionColor` is null
- **THEN** the selection highlight SHALL use the default Flutter selection color from the theme

---

### Requirement: Scroll-stable selection
The `CustomSelectableRegion` SHALL maintain the selection state, highlight, and handles when the user scrolls the content. The selection SHALL remain valid when the selected content scrolls out of and back into the viewport.

#### Scenario: Selection preserved after scroll away and back
- **WHEN** user scrolls selected content out of viewport and then scrolls back
- **THEN** the selection highlight and handles SHALL be visible and intact at the original positions

---

### Requirement: Hit-test for element identification
The `CustomSelectableRegion` SHALL, upon long-press, perform a hit-test to identify which Markdown block element was pressed, by walking the render tree to find the nearest ancestor carrying `MarkdownElementInfo` metadata.

#### Scenario: Hit-test identifies correct element
- **WHEN** user long-presses on a paragraph that is nested inside a blockquote
- **THEN** the hit-test SHALL identify the innermost block element (the paragraph, not the blockquote wrapper)

#### Scenario: Hit-test on gap falls to nearest element
- **WHEN** user long-presses on the padding/margin gap between two elements
- **THEN** the hit-test SHALL attribute the press to the nearest block element
