## ADDED Requirements

### Requirement: Custom selection mode is opt-in
`MarkdownWidget` SHALL provide an optional custom selection configuration. When the configuration is absent, `MarkdownWidget` SHALL preserve its existing selectable behavior. When `selectable` is `false`, `MarkdownWidget` SHALL disable both existing and custom text-selection behavior.

#### Scenario: Existing default behavior remains active
- **WHEN** an application creates `MarkdownWidget(selectable: true)` without a custom selection configuration
- **THEN** the widget uses the existing selection behavior without the two-stage custom menu flow

#### Scenario: Custom mode is enabled explicitly
- **WHEN** an application creates `MarkdownWidget(selectable: true)` with a custom selection configuration
- **THEN** the widget uses the two-stage custom selection flow for supported touch interactions

#### Scenario: Selection is disabled globally
- **WHEN** an application creates `MarkdownWidget(selectable: false)` with or without a custom selection configuration
- **THEN** the widget does not start native selection and does not display custom selection menus

### Requirement: Long press displays an initial custom menu before text selection
In custom mode, `MarkdownWidget` SHALL display a customizable initial action menu when the user long-presses a supported Markdown element. The widget SHALL NOT create a text selection, selection highlight, or draggable handles until the user invokes the built-in "Select text" action. For text-bearing targets, the initial-menu builder SHALL receive the built-in "Select text" action as configurable menu content so the application can render, hide, or reorder it.

#### Scenario: Long press on paragraph text
- **WHEN** the user long-presses text inside a paragraph in custom mode
- **THEN** the initial custom menu context includes "Select text" and configured application actions
- **AND** no text is highlighted and no selection handles are displayed

#### Scenario: Hide the built-in select text action
- **WHEN** the initial-menu builder chooses not to render the built-in "Select text" action for a text-bearing target
- **THEN** the initial custom menu appears without the "Select text" item
- **AND** no text selection starts from that hidden action

#### Scenario: Reorder the built-in select text action
- **WHEN** the initial-menu builder renders the built-in "Select text" action after configured application actions
- **THEN** the menu order follows the builder output

#### Scenario: Long press on link text
- **WHEN** the user long-presses link text in custom mode
- **THEN** the initial custom menu appears before any link-specific long-press behavior
- **AND** no text is highlighted and no selection handles are displayed

#### Scenario: Long press on a text-free element with application actions
- **WHEN** the user long-presses an image, horizontal rule, or other text-free element and configured application actions are available for that element
- **THEN** the initial custom menu appears without "Select text"

#### Scenario: Long press on a text-free element without application actions
- **WHEN** the user long-presses an image, horizontal rule, or other text-free element and no configured application action is available
- **THEN** no custom menu appears

#### Scenario: Long press on a task-list checkbox control
- **WHEN** the user long-presses the checkbox control of a task-list item
- **THEN** the initial custom menu does not expose "Select text"

### Requirement: Select text initializes the smallest semantic block range
When the user invokes "Select text", `MarkdownWidget` SHALL initialize selection to the complete text of the resolved semantic block and SHALL display selection highlight, draggable handles, and the customizable selected-text menu.

#### Scenario: Select a heading
- **WHEN** the user invokes "Select text" after long-pressing a heading
- **THEN** the complete heading text is initially selected

#### Scenario: Select a paragraph
- **WHEN** the user invokes "Select text" after long-pressing paragraph text
- **THEN** the complete containing paragraph text is initially selected

#### Scenario: Select a list item
- **WHEN** the user invokes "Select text" after long-pressing the third item in a list
- **THEN** only the third item's direct textual content is initially selected
- **AND** preceding items, following items, and nested child lists are not initially selected

#### Scenario: Select a task-list item by text
- **WHEN** the user invokes "Select text" after long-pressing task-list item text
- **THEN** only the current item's direct textual content is initially selected
- **AND** the checkbox control and nested child lists are not initially selected

#### Scenario: Select a nested list item
- **WHEN** the user invokes "Select text" after long-pressing a nested list item outside a block quote
- **THEN** only that nested item's direct textual content is initially selected

#### Scenario: Select content inside a multi-paragraph block quote
- **WHEN** the user invokes "Select text" after long-pressing any text inside a block quote that contains multiple paragraphs
- **THEN** the complete block quote text is initially selected

#### Scenario: Select content inside nested block quotes
- **WHEN** the user invokes "Select text" after long-pressing text inside a block quote nested inside another block quote
- **THEN** the nearest containing block quote text is initially selected
- **AND** ancestor block quote text outside that nearest quote is not initially selected

#### Scenario: Select a code block
- **WHEN** the user invokes "Select text" after long-pressing text inside a code block
- **THEN** the complete code block text is initially selected

#### Scenario: Select inline formatted text
- **WHEN** the user invokes "Select text" after long-pressing a link, emphasized text, strong text, or inline code
- **THEN** the complete containing semantic block is initially selected

#### Scenario: Select a table cell
- **WHEN** the user invokes "Select text" after long-pressing text inside a table cell
- **THEN** the complete current cell text is initially selected
- **AND** the user can drag selection handles afterward to adjust the selected range

### Requirement: Existing interactive element behavior is preserved
Custom selection mode SHALL preserve existing tap or button behaviors for interactive Markdown content when those controls are not invoking the custom "Select text" action.

#### Scenario: Tap link text
- **WHEN** the user taps link text in custom mode
- **THEN** the existing link tap behavior runs
- **AND** the custom selection flow does not start

#### Scenario: Press an existing code-block copy button
- **WHEN** the user presses an existing code-block copy button
- **THEN** the button keeps its existing copy behavior
- **AND** the custom selection flow does not start

### Requirement: Users can adjust selection across Markdown blocks
After initial semantic-block selection, `MarkdownWidget` SHALL allow the user to drag selection handles to refine or expand the selection across Markdown block boundaries while preserving native-style selection highlight and handles.

#### Scenario: Drag a handle into an adjacent block
- **WHEN** the user drags a selection handle from the initially selected paragraph into an adjacent Markdown block
- **THEN** the selected range updates continuously across the block boundary

#### Scenario: Menu lifecycle during handle adjustment
- **WHEN** the user starts dragging a selection handle
- **THEN** the selected-text menu disappears without clearing highlight or handles
- **AND WHEN** the user finishes dragging the handle
- **THEN** the selected-text menu reappears for the adjusted range

### Requirement: Selected-text menu supports copy and custom actions
After text selection starts, `MarkdownWidget` SHALL display a customizable selected-text menu containing copy and configured application actions. Invoking any selected-text menu action SHALL clear the menu, selection highlight, and handles before the action executes.

#### Scenario: Copy the current adjusted selection
- **WHEN** the user invokes copy from the selected-text menu
- **THEN** the widget writes the current selected rendered plain text to the clipboard
- **AND** clears the selected-text menu, selection highlight, and handles

#### Scenario: Copy a code block
- **WHEN** the current selection contains a code block and the user invokes copy
- **THEN** the copied plain text preserves code-block line breaks

#### Scenario: Invoke a configured selected-text action
- **WHEN** the user invokes a configured selected-text application action
- **THEN** the widget clears the selected-text menu, selection highlight, and handles before invoking the action callback

### Requirement: Selection persists while the page scrolls
`MarkdownWidget` SHALL preserve the active selected range while the Markdown page scrolls, including when selection endpoints move outside the visible viewport.

#### Scenario: Start scrolling with an active selection
- **WHEN** the user scrolls the page while a selection is active
- **THEN** the selected-text menu disappears
- **AND** the selected range remains active

#### Scenario: Stop scrolling
- **WHEN** scrolling ends while a selection remains active
- **THEN** the selected-text menu does not automatically reappear

#### Scenario: Scroll selection endpoints out of view and back
- **WHEN** an active selection endpoint scrolls outside the viewport and later returns into the viewport
- **THEN** the selection remains active
- **AND** its handle is visible again when its endpoint returns

### Requirement: Taps update active selection visibility predictably
When a text selection is active, `MarkdownWidget` SHALL distinguish taps inside and outside the selected region.

#### Scenario: Tap inside an active selection
- **WHEN** the user taps inside the active selected region
- **THEN** the selected range and handles remain active
- **AND** the selected-text menu appears

#### Scenario: Tap outside an active selection
- **WHEN** the user taps outside the active selected region
- **THEN** the widget clears the selected range, handles, and selected-text menu

### Requirement: Custom menus remain usable near viewport edges
`MarkdownWidget` SHALL provide menu anchors constrained to the available overlay bounds so initial and selected-text custom menus can remain visible near viewport edges.

#### Scenario: Open a menu near the top edge
- **WHEN** the user opens a custom menu from content near the top edge of the viewport
- **THEN** the menu anchor is adjusted so the custom menu can remain within the visible overlay bounds

### Requirement: Example demonstrates custom selection mode
The package example SHALL include runnable usage of custom selection mode with built-in selection and copy behavior plus at least one configured application action.

#### Scenario: Review example implementation
- **WHEN** a package consumer opens the custom selection example
- **THEN** the example shows how to enable custom mode and provide customized menu content and an additional action

### Requirement: Touch custom flow is validated on the target Flutter version
The custom selection implementation SHALL be validated with Flutter `3.27.4` for Android and iOS touch long-press interaction.

#### Scenario: Verify target SDK behavior
- **WHEN** the package test suite and example verification run with Flutter `3.27.4`
- **THEN** the supported custom selection scenarios complete without breaking the existing default selection path
