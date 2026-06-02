# Menu Extension Capability Specification

## ADDED Requirements

### Requirement: Add custom menu items

The system SHALL allow users to add custom menu items to the selection menu.

#### Scenario: Add simple custom item
- **WHEN** user adds CustomMenuItem to MenuExtension.items
- **THEN** item appears in menu at specified position
- **AND** item uses specified label and icon
- **AND** tapping item executes specified callback

#### Scenario: Add context-aware item
- **WHEN** user adds CustomMenuItem.withContext with onContextTap callback
- **THEN** item appears in menu
- **AND** tapping item executes callback with ElementContext

### Requirement: Provide element context to custom items

The system SHALL provide ElementContext with relevant information about the selected element.

#### Scenario: Access element content
- **WHEN** custom item callback receives ElementContext
- **THEN** callback can access `plainText` property containing element's text content

#### Scenario: Access full markdown
- **WHEN** custom item callback receives ElementContext
- **THEN** callback can access `fullMarkdown` property containing entire document

#### Scenario: Access element index
- **WHEN** custom item callback receives ElementContext
- **THEN** callback can access `index` property containing element's position in list

#### Scenario: Access element type
- **WHEN** custom item callback receives ElementContext
- **THEN** callback can access `elementType` property (e.g., "heading", "paragraph", "codeBlock")

#### Scenario: Access selected text
- **WHEN** custom item callback receives ElementContext
- **AND** user has selected text
- **THEN** callback can access `selectedText` property containing selected portion

#### Scenario: No selection active
- **WHEN** custom item callback receives ElementContext
- **AND** no text is selected
- **THEN** `selectedText` property is null
- **AND** `selection` property is invalid or collapsed

### Requirement: Control menu item position

The system SHALL allow users to specify where custom items appear in the menu.

#### Scenario: After built-in items
- **WHEN** user sets `position: MenuInsertPosition.afterBuiltIn`
- **THEN** custom items appear after all built-in items
- **RESULT**: [选取文字] [复制] [收藏] [分享] [custom1] [custom2]

#### Scenario: After select text
- **WHEN** user sets `position: MenuInsertPosition.afterSelectText`
- **THEN** custom items appear immediately after "选取文字"
- **RESULT**: [选取文字] [custom1] [custom2] [复制] [收藏] [分享]

#### Scenario: After copy
- **WHEN** user sets `position: MenuInsertPosition.afterCopy`
- **THEN** custom items appear immediately after "复制"
- **RESULT**: [选取文字] [复制] [custom1] [custom2] [收藏] [分享]

#### Scenario: Replace all items
- **WHEN** user sets `position: MenuInsertPosition.replaceAll`
- **THEN** menu contains only custom items
- **AND** no built-in items appear
- **RESULT**: [custom1] [custom2] [custom3]

### Requirement: Hide built-in menu items

The system SHALL allow users to hide specific built-in menu items.

#### Scenario: Hide bookmark
- **WHEN** user adds `BuiltInMenuItem.bookmark` to hiddenBuiltInItems
- **THEN** "收藏" item does not appear in menu

#### Scenario: Hide share
- **WHEN** user adds `BuiltInMenuItem.share` to hiddenBuiltInItems
- **THEN** "分享" item does not appear in menu

#### Scenario: Hide multiple items
- **WHEN** user adds multiple BuiltInMenuItem values to hiddenBuiltInItems
- **THEN** none of the specified items appear in menu

#### Scenario: Hide select text
- **WHEN** user adds `BuiltInMenuItem.selectText` to hiddenBuiltInItems
- **THEN** "选取文字" item does not appear in menu
- **AND** users cannot enter selection mode

### Requirement: Enable/disable menu items dynamically

The system SHALL support enabling/disabling menu items.

#### Scenario: Disabled custom item
- **WHEN** custom item has `enabled: false`
- **THEN** item appears disabled in menu
- **AND** tapping item has no effect

#### Scenario: Conditionally enabled item
- **WHEN** item's enabled state is determined dynamically
- **THEN** item reflects current enabled state in menu
- **AND** menu rebuilds when state changes

### Requirement: Support custom item styling

The system SHALL allow custom styling for individual menu items.

#### Scenario: Custom item color
- **WHEN** custom item specifies `textColor` or `iconColor`
- **THEN** item uses specified colors instead of defaults

#### Scenario: Custom item background
- **WHEN** custom item specifies `backgroundColor`
- **THEN** item uses specified background color

#### Scenario: Custom item hover effect
- **WHEN** custom item specifies `hoverDecoration`
- **THEN** item displays specified decoration on hover

### Requirement: Provide custom item builder

The system SHALL allow users to provide custom item builder for complete UI control.

#### Scenario: Custom item builder
- **WHEN** user provides `itemBuilder` in MenuStyle
- **THEN** each menu item is built using specified builder
- **AND** builder receives item, style, and context

### Requirement: Support extended items in copy menu

The system SHALL include custom items in the copy menu shown after selection.

#### Scenario: Extended items in copy menu
- **WHEN** user selects text and copy menu appears
- **THEN** menu contains "复制" button
- **AND** menu contains all extended custom items
- **AND** custom items receive ElementContext with selection info

#### Scenario: Extended item accesses selection
- **WHEN** custom item in copy menu is tapped
- **AND** callback uses ElementContext
- **THEN** callback can access `selectedText` containing user's selection

### Requirement: Support conditional menu items

The system SHALL allow users to provide different menu items based on conditions.

#### Scenario: Element-type specific items
- **WHEN** user provides items based on element type check
- **THEN** menu shows items appropriate for that element type

#### Scenario: Code block specific items
- **WHEN** element is a code block
- **AND** user provides code-specific items
- **THEN** menu includes code-specific items (e.g., "运行代码", "复制代码")

#### Scenario: Image specific items
- **WHEN** element is an image
- **AND** user provides image-specific items
- **THEN** menu includes image-specific items (e.g., "下载图片")

### Requirement: Execute custom actions with context

The system SHALL properly execute custom callbacks with full context.

#### Scenario: Simple callback
- **WHEN** user taps custom item with simple onTap callback
- **THEN** specified function is executed
- **AND** menu disappears after callback

#### Scenario: Context callback
- **WHEN** user taps custom item with onContextTap callback
- **THEN** callback is executed with ElementContext
- **AND** callback can access all context properties
- **AND** menu disappears after callback

#### Scenario: Callback error handling
- **WHEN** custom item callback throws an exception
- **THEN** exception is caught and logged
- **AND** menu disappears
- **AND** app continues to function

### Requirement: Support custom item ordering

The system SHALL maintain custom items in the order specified by user.

#### Scenario: Multiple custom items order
- **WHEN** user provides multiple custom items in a list
- **THEN** items appear in menu in the order provided

#### Scenario: Mixed built-in and custom ordering
- **WHEN** user specifies position and provides custom items
- **THEN** built-in items maintain their order
- **AND** custom items appear in their specified position relative to built-in items
