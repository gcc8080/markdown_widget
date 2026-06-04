## ADDED Requirements

### Requirement: Stage 1 interaction — long-press triggers custom menu
The system SHALL detect a long-press gesture on any selectable Markdown block element and invoke the user-provided `firstStageMenuBuilder` callback, passing the `MarkdownElementInfo` of the pressed element, the global tap coordinate, and a `onSelectText` callback to transition to Stage 2.

#### Scenario: Long-press on heading element
- **WHEN** user long-presses on a heading (h1-h6) element in custom selection mode
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with `elementInfo.tag` equal to the heading tag (h1/h2/h3/h4/h5/h6), `elementInfo.plainText` containing the full heading text, and `globalPosition` reflecting the press coordinate

#### Scenario: Long-press on paragraph element
- **WHEN** user long-presses on a paragraph (p) element
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with `elementInfo.tag == MarkdownTag.p` and `elementInfo.plainText` containing the full paragraph text

#### Scenario: Long-press on list item
- **WHEN** user long-presses on a list item (li) element
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with `elementInfo.tag == MarkdownTag.li` and `elementInfo.plainText` containing only the current item's text (excluding nested sub-list text)

#### Scenario: Long-press on code block
- **WHEN** user long-presses on a code block (pre) element
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with `elementInfo.tag == MarkdownTag.pre` and `elementInfo.plainText` containing the full code block text with preserved indentation and newlines

#### Scenario: Long-press on blockquote
- **WHEN** user long-presses on a blockquote element containing multiple paragraphs
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with the innermost paragraph hit as the selected element

#### Scenario: Long-press on table
- **WHEN** user long-presses on a table element
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with `elementInfo.tag == MarkdownTag.table` and `elementInfo.plainText` containing the full table text

#### Scenario: Long-press on image is ignored
- **WHEN** user long-presses on an image (img) element
- **THEN** the system SHALL NOT invoke any menu callback

#### Scenario: Long-press on horizontal rule is ignored
- **WHEN** user long-presses on a horizontal rule (hr) element
- **THEN** the system SHALL NOT invoke any menu callback

#### Scenario: Long-press on checkbox
- **WHEN** user long-presses on a checkbox (input) element within a list item
- **THEN** the system SHALL invoke `firstStageMenuBuilder` treating it as the parent list item

#### Scenario: Long-press on link
- **WHEN** user long-presses on a link (a) element within a paragraph
- **THEN** the system SHALL invoke `firstStageMenuBuilder` with the parent element (e.g., paragraph) as the selected element

---

### Requirement: Stage 2 interaction — text selection with custom menu
The system SHALL, upon receiving the `onSelectText` callback from Stage 1, programmatically select the full text of the target block element, display selection handles, and invoke the user-provided `secondStageMenuBuilder` callback with the selected text, global position, and a dismiss callback.

#### Scenario: Transition from Stage 1 to Stage 2
- **WHEN** user triggers `onSelectText` from the Stage 1 menu
- **THEN** the system SHALL dismiss the Stage 1 menu, select the full text of the target element, show drag handles, and invoke `secondStageMenuBuilder`

#### Scenario: Handle drag hides menu
- **WHEN** user starts dragging a selection handle in Stage 2
- **THEN** the system SHALL dismiss the Stage 2 menu while dragging

#### Scenario: Handle drag end shows menu
- **WHEN** user finishes dragging a selection handle in Stage 2
- **THEN** the system SHALL re-invoke `secondStageMenuBuilder` with the updated selected text

#### Scenario: Tap inside selected area shows menu
- **WHEN** user taps inside the selected area in Stage 2 (menu is dismissed)
- **THEN** the system SHALL re-invoke `secondStageMenuBuilder` without changing the selection

#### Scenario: Tap outside selected area dismisses everything
- **WHEN** user taps outside the selected area in Stage 2
- **THEN** the system SHALL clear the selection, hide handles, and dismiss the menu, returning to idle state

#### Scenario: Stage 2 menu button clears selection
- **WHEN** user triggers `onDismiss` from the Stage 2 menu
- **THEN** the system SHALL clear the selection, hide handles, and dismiss the menu

#### Scenario: Scroll preserves selection
- **WHEN** user scrolls the page while text is selected in Stage 2
- **THEN** the system SHALL preserve the selection and handles; scrolling back SHALL show the selection intact

#### Scenario: Cross-element selection via handle drag
- **WHEN** user drags a selection handle beyond the boundary of the initially selected element
- **THEN** the system SHALL extend the selection to include text from adjacent elements

---

### Requirement: Re-long-press clears previous selection
The system SHALL clear any existing selection and dismiss any visible menu when a new long-press is detected, then trigger a fresh Stage 1 interaction at the new position.

#### Scenario: Long-press while selection active
- **WHEN** user long-presses on a different element while Stage 2 selection is active
- **THEN** the system SHALL clear the previous selection, dismiss the Stage 2 menu, and invoke `firstStageMenuBuilder` for the newly pressed element

---

### Requirement: Tap outside Stage 1 menu dismisses
The system SHALL dismiss the Stage 1 menu when user taps outside the menu area, returning to idle state without creating a selection.

#### Scenario: Dismiss Stage 1 by tapping outside
- **WHEN** user taps outside the Stage 1 menu overlay
- **THEN** the system SHALL dismiss the menu and return to idle state

---

### Requirement: Custom selection mode requires selectable=true
The system SHALL ignore `CustomSelectionConfig` when the parent widget's `selectable` property is `false`. Custom selection mode SHALL only activate when `selectable=true` AND `customSelectionConfig` is non-null.

#### Scenario: selectable=false ignores config
- **WHEN** `MarkdownWidget` has `selectable=false` and `customSelectionConfig` is provided
- **THEN** the system SHALL NOT activate custom selection mode; the widget SHALL render without `SelectionArea` or `CustomSelectableRegion`

#### Scenario: selectable=true with no config uses default
- **WHEN** `MarkdownWidget` has `selectable=true` and `customSelectionConfig` is null
- **THEN** the system SHALL use the standard `SelectionArea` behavior (backward compatible)

---

### Requirement: Haptic feedback on long-press
The system SHALL provide haptic feedback when a long-press triggers Stage 1, if `CustomSelectionConfig.hapticFeedback` is `true` (default).

#### Scenario: Haptic feedback enabled
- **WHEN** user long-presses with `hapticFeedback == true`
- **THEN** the system SHALL trigger device haptic feedback

#### Scenario: Haptic feedback disabled
- **WHEN** user long-presses with `hapticFeedback == false`
- **THEN** the system SHALL NOT trigger haptic feedback

---

### Requirement: Selected text callback
The system SHALL invoke `CustomSelectionConfig.onTextSelected` whenever the selected text changes during Stage 2 (initial selection and handle drag adjustments).

#### Scenario: Text selection callback on initial selection
- **WHEN** the system transitions to Stage 2 and selects text
- **THEN** the system SHALL invoke `onTextSelected` with the selected plain text

#### Scenario: Text selection callback on handle adjustment
- **WHEN** user adjusts selection via handle drag in Stage 2
- **THEN** the system SHALL invoke `onTextSelected` with the updated selected text after drag ends
