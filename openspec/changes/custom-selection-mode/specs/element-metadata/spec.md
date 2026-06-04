## ADDED Requirements

### Requirement: MarkdownElementInfo provides element type
The system SHALL expose a `MarkdownElementInfo` class containing a `tag` field of type `MarkdownTag` that identifies the Markdown element type (h1-h6, p, li, pre, blockquote, table, a, img, hr, code, input, etc.).

#### Scenario: Heading element info
- **WHEN** user long-presses on a h2 heading
- **THEN** the `MarkdownElementInfo.tag` SHALL be `MarkdownTag.h2`

#### Scenario: List item element info
- **WHEN** user long-presses on a list item
- **THEN** the `MarkdownElementInfo.tag` SHALL be `MarkdownTag.li`

---

### Requirement: MarkdownElementInfo provides plain text
The system SHALL expose a `plainText` field on `MarkdownElementInfo` containing the rendered plain text of the element, with inline formatting stripped (no markdown syntax characters).

#### Scenario: Plain text for bold paragraph
- **WHEN** the pressed element is a paragraph containing `**bold** text`
- **THEN** `MarkdownElementInfo.plainText` SHALL be `bold text`

#### Scenario: Plain text for code block preserves whitespace
- **WHEN** the pressed element is a code block with indentation and newlines
- **THEN** `MarkdownElementInfo.plainText` SHALL preserve the original whitespace

---

### Requirement: MarkdownElementInfo provides source text
The system SHALL expose a `sourceText` field on `MarkdownElementInfo` containing the original Markdown source text of the element, including all syntax markers (e.g., `#`, `**`, `` ``` ``, `-`).

#### Scenario: Source text for heading
- **WHEN** the pressed element is a h1 heading with text "Title"
- **THEN** `MarkdownElementInfo.sourceText` SHALL contain `# Title`

#### Scenario: Source text for bold paragraph
- **WHEN** the pressed element is a paragraph containing `**bold** and *italic*`
- **THEN** `MarkdownElementInfo.sourceText` SHALL contain `**bold** and *italic*`

#### Scenario: Source text for code block includes fences
- **WHEN** the pressed element is a fenced code block with language `dart`
- **THEN** `MarkdownElementInfo.sourceText` SHALL include the opening fence (`` ```dart ``), the code content, and the closing fence (`` ``` ``)

---

### Requirement: MarkdownElementInfo provides widget index
The system SHALL expose a `widgetIndex` field on `MarkdownElementInfo` containing the integer index of the element in the generated widget list, corresponding to its position in the `ListView`/`Column`.

#### Scenario: Widget index reflects position
- **WHEN** the pressed element is the third block element in the markdown document
- **THEN** `MarkdownElementInfo.widgetIndex` SHALL be `2` (zero-indexed)

---

### Requirement: MarkdownElementInfo provides global rect
The system SHALL expose a `globalRect` field on `MarkdownElementInfo` containing the `Rect` representing the element's bounding box in global coordinates. This field MAY be null if the element's render object is not available.

#### Scenario: Global rect for visible element
- **WHEN** user long-presses on a visible paragraph element
- **THEN** `MarkdownElementInfo.globalRect` SHALL be a non-null `Rect` encompassing the element's visible bounds

---

### Requirement: buildWidgetsWithInfo returns element metadata
The system SHALL provide a `buildWidgetsWithInfo()` method on `MarkdownGenerator` that returns a `MarkdownBuildResult` containing both the widget list and a parallel `List<MarkdownElementInfo>` with metadata for each widget.

#### Scenario: Widget list and info list have matching length
- **WHEN** `buildWidgetsWithInfo()` is called with a markdown string
- **THEN** the returned `MarkdownBuildResult.widgets.length` SHALL equal `MarkdownBuildResult.elementInfos.length`

#### Scenario: Backward compatible buildWidgets unchanged
- **WHEN** `buildWidgets()` is called (existing API)
- **THEN** the return type and behavior SHALL remain identical to the current implementation
