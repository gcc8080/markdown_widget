# Custom Selection Capability Specification

## ADDED Requirements

### Requirement: Enable custom selection mode

The system SHALL allow users to enable custom selection mode via configuration on MarkdownWidget.

#### Scenario: Enable custom selection mode
- **WHEN** user sets `enableCustomSelection: true` on MarkdownWidget
- **THEN** system disables default SelectionArea behavior
- **AND** system enables custom selection on each markdown element

#### Scenario: Disable custom selection mode
- **WHEN** user sets `enableCustomSelection: false` on MarkdownWidget (or omits parameter)
- **THEN** system uses default SelectionArea behavior
- **AND** custom selection features are not active

### Requirement: Long press shows custom menu

The system SHALL display a custom menu when user long presses on a markdown element.

#### Scenario: Long press on element
- **WHEN** user long presses on any markdown element
- **THEN** system displays custom menu above finger position
- **AND** menu contains built-in items: "选取文字", "复制", "收藏", "分享"
- **AND** menu contains any extended items defined by user
- **AND** no text selection occurs at this point

#### Scenario: Menu positioning
- **WHEN** menu is displayed
- **THEN** menu position is above the long press location
- **AND** menu is adjusted if near screen edges to stay within bounds

### Requirement: Select entire element on menu action

The system SHALL select the entire content of the clicked element when user taps "选取文字".

#### Scenario: Select heading element
- **WHEN** user long presses on a heading element and taps "选取文字"
- **THEN** entire heading text is selected
- **AND** selection handles appear
- **AND** copy menu appears above selected area

#### Scenario: Select paragraph element
- **WHEN** user long presses on a paragraph element and taps "选取文字"
- **THEN** entire paragraph text is selected
- **AND** selection handles appear
- **AND** copy menu appears above selected area

#### Scenario: Select list item
- **WHEN** user long presses on a list item and taps "选取文字"
- **THEN** only that list item is selected (not entire list)
- **AND** selection handles appear
- **AND** copy menu appears above selected area

#### Scenario: Select code block
- **WHEN** user long presses on a code block and taps "选取文字"
- **THEN** entire code block content is selected
- **AND** selection handles appear
- **AND** copy menu appears above selected area

#### Scenario: Select blockquote
- **WHEN** user long presses on a blockquote and taps "选取文字"
- **THEN** entire blockquote content is selected
- **AND** selection handles appear
- **AND** copy menu appears above selected area

### Requirement: Allow selection handle dragging

The system SHALL allow users to drag selection handles to adjust selection range.

#### Scenario: Drag selection handles
- **WHEN** user drags selection handles
- **THEN** selection range updates in real-time
- **AND** menu hides during drag
- **AND** selection handles remain visible

#### Scenario: End drag operation
- **WHEN** user releases selection handle
- **THEN** menu reappears above new selection position
- **AND** selection handles remain visible

### Requirement: Clear selection on outside tap

The system SHALL clear selection when user taps outside selected area.

#### Scenario: Tap outside selection
- **WHEN** user taps outside the selected text area
- **THEN** selection is cleared
- **AND** selection handles disappear
- **AND** menu disappears

#### Scenario: Tap inside selection
- **WHEN** user taps inside the selected text area
- **THEN** selection is maintained
- **AND** selection handles remain visible
- **AND** menu appears (if hidden)

### Requirement: Persist selection during scroll

The system SHALL maintain selection state when content scrolls in and out of view, but hide menu during scroll.

#### Scenario: Scroll with active selection
- **WHEN** user scrolls the page while selection is active
- **THEN** selected area remains selected
- **AND** selection handles remain visible
- **AND** menu disappears during scroll

#### Scenario: Stop scrolling with active selection
- **WHEN** user stops scrolling and selection is still active
- **THEN** menu reappears above selected area
- **AND** selection and handles remain visible

#### Scenario: Scroll selected area off-screen
- **WHEN** selected area scrolls out of viewport
- **THEN** selection state is maintained
- **AND** when scrolled back into view, selection and handles are visible
- **AND** menu reappears when scrolling stops

### Requirement: Execute menu actions

The system SHALL execute appropriate actions when user taps menu items.

#### Scenario: Copy action
- **WHEN** user taps "复制" in initial menu
- **THEN** entire element content is copied to clipboard
- **AND** menu disappears

#### Scenario: Copy selected text
- **WHEN** user taps "复制" in copy menu (after selection)
- **THEN** selected text is copied to clipboard
- **AND** selection is cleared
- **AND** menu disappears
- **AND** selection handles disappear

#### Scenario: Bookmark action
- **WHEN** user taps "收藏" in menu
- **THEN** full markdown document content is bookmarked
- **AND** menu disappears

#### Scenario: Share action
- **WHEN** user taps "分享" in menu
- **THEN** full markdown document content is shared
- **AND** menu disappears

#### Scenario: Extended menu item
- **WHEN** user taps a custom extended menu item
- **THEN** custom callback is executed with ElementContext
- **AND** menu disappears

### Requirement: Smooth mode transition

The system SHALL transition smoothly between static and selectable modes.

#### Scenario: Transition to selection mode
- **WHEN** user taps "选取文字"
- **THEN** transition from static to selectable mode is animated
- **AND** no visual flicker occurs

#### Scenario: Transition from selection mode
- **WHEN** user clears selection (tap outside or menu action)
- **THEN** transition from selectable to static mode is animated
- **AND** no visual flicker occurs

### Requirement: No interference with scrolling

The system SHALL not interfere with ListView scrolling gestures.

#### Scenario: Vertical scrolling
- **WHEN** user performs vertical scrolling gesture
- **THEN** ListView scrolls normally
- **AND** long press detection still works
- **AND** no gesture conflicts occur

### Requirement: Handle table element selection

The system SHALL handle table elements with cell-level selection granularity.

#### Scenario: Select table cell
- **WHEN** user long presses on a table cell and taps "选取文字"
- **THEN** only that cell's content is selected
- **AND** selection handles appear
- **AND** copy menu appears above selected cell

#### Scenario: Copy table cell
- **WHEN** user copies a selected table cell
- **THEN** only the cell's text content is copied (no table formatting)

#### Scenario: Drag selection within table
- **WHEN** user drags selection handle within table
- **THEN** selection can extend to adjacent cells
- **AND** selected cells' content is highlighted

### Requirement: Handle image element behavior

The system SHALL not trigger custom selection menu for image elements.

#### Scenario: Long press on image
- **WHEN** user long presses on an image element
- **THEN** no custom selection menu appears
- **AND** default image behavior is preserved

#### Scenario: Image in paragraph
- **WHEN** user long presses on text in a paragraph containing an image
- **THEN** custom menu appears for the text portion
- **AND** image is not included in selectable content

### Requirement: Handle link element selection

The system SHALL select link display text when user selects a link element.

#### Scenario: Select link text
- **WHEN** user long presses on a link and taps "选取文字"
- **THEN** link's display text is selected (not URL)
- **AND** selection handles appear
- **AND** copy menu appears

#### Scenario: Copy link text
- **WHEN** user copies selected link text
- **THEN** only the display text is copied to clipboard (not the URL)

#### Scenario: Tap link for navigation
- **WHEN** user taps (not long press) on a link
- **THEN** link navigation occurs normally
- **AND** no selection menu appears

### Requirement: Handle nested element selection

The system SHALL select the innermost block-level element when user long presses on nested structures.

#### Scenario: Select nested list item in blockquote
- **WHEN** user long presses on a list item inside a blockquote
- **THEN** only that list item is selected (not the entire blockquote)
- **AND** selection handles appear

#### Scenario: Select code block in list item
- **WHEN** user long presses on a code block inside a list item
- **THEN** only the code block is selected (not the entire list item)
- **AND** selection handles appear

#### Scenario: Select paragraph in blockquote
- **WHEN** user long presses on a paragraph inside a blockquote
- **THEN** only that paragraph is selected (not the entire blockquote)
- **AND** selection handles appear

#### Scenario: Drag selection across nested boundaries
- **WHEN** user drags selection handle across nested element boundaries
- **THEN** selection extends across boundaries
- **AND** content from both elements is included in selection

### Requirement: Handle inline element selection

The system SHALL select the containing paragraph when user long presses on inline elements.

#### Scenario: Long press on inline code
- **WHEN** user long presses on inline code within a paragraph
- **THEN** entire paragraph is selected (not just the inline code)
- **AND** selection handles appear

#### Scenario: Long press on bold text
- **WHEN** user long presses on bold text within a paragraph
- **THEN** entire paragraph is selected
- **AND** selection handles appear

#### Scenario: Long press on italic text
- **WHEN** user long presses on italic text within a paragraph
- **THEN** entire paragraph is selected
- **AND** selection handles appear

#### Scenario: Adjust selection to exclude inline formatting
- **WHEN** user drags selection handles within a paragraph containing inline elements
- **THEN** selection can be adjusted to include or exclude inline formatted text
- **AND** formatting markers are not visible in selection

### Requirement: Handle non-selectable elements

The system SHALL not trigger custom selection menu for non-content elements.

#### Scenario: Long press on horizontal rule
- **WHEN** user long presses on a horizontal rule element
- **THEN** no custom selection menu appears
- **AND** no selection occurs

#### Scenario: Long press on empty space
- **WHEN** user long presses on empty space between elements
- **THEN** no custom selection menu appears
- **AND** no selection occurs

#### Scenario: Long press on checkbox
- **WHEN** user long presses on a checkbox in a task list
- **THEN** checkbox toggle behavior is preserved
- **AND** no custom selection menu appears for the checkbox itself
- **AND** long press on text portion of task item triggers selection menu
