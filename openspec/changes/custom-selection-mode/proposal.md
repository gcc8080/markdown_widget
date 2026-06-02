# Custom Selection Mode for MarkdownWidget

## Why

Current `MarkdownWidget` uses Flutter's `SelectionArea` for text selection, which provides limited customization options. Users cannot customize the selection menu's appearance, extend menu items with custom actions, or control the selection behavior at a per-element level. Real-world applications need more flexibility to provide branded experiences and integrate custom workflows like translation, bookmarking, or AI-powered features.

## What Changes

### New Capabilities

- **Custom Selection Mode**: A global toggle that enables custom selection behavior instead of Flutter's default `SelectionArea`

- **Customizable Selection Menu**: Fully customizable menu appearance including colors, icons, layout, spacing, and animations

- **Element-Level Selection Control**: Each markdown element (heading, paragraph, code block, list item, etc.) can be individually selected with custom behavior

- **Extended Menu Items**: API for users to add custom menu items that can access element context (content, index, full markdown document)

### Behavior Changes

When custom selection mode is enabled:

1. **Long press on content** → Shows custom menu (not immediate text selection)
2. **Custom menu items**:
   - "选取文字" (Select Text) - Enters selection mode, selects entire element
   - "复制" (Copy) - Copies element content
   - "收藏" (Bookmark) - Bookmarks the full markdown document
   - "分享" (Share) - Shares the full markdown document
   - Extended items (user-defined)
3. **After clicking "Select Text"**:
   - Entire element content is selected
   - Selection handles appear
   - Copy menu appears above selection
   - User can drag handles to adjust selection range
   - Menu hides during drag, reappears when drag ends
   - Clicking inside selection re-shows menu
   - Clicking outside selection clears everything
4. **Scroll behavior**: Selection and handles persist when scrolling in/out of view

When custom selection mode is disabled (default), behavior remains unchanged using Flutter's `SelectionArea`.

## Capabilities

### New Capabilities

- `custom-selection`: Core custom selection mode functionality including element-level selection control, menu positioning, and overlay management

- `custom-menu-style`: Menu appearance customization including container styles, item styles, layout modes, and animation configuration

- `menu-extension`: API for extending menu items with custom actions that can access element context

### Modified Capabilities

None. This is a new feature that does not modify existing capabilities.

## Impact

### Code Changes

- **New files**:
  - `lib/widget/custom_selection/` - Custom selection implementation
  - `lib/config/custom_selection_config.dart` - Configuration classes
  - `lib/widget/custom_selection/custom_selectable_wrapper.dart` - Element wrapper
  - `lib/widget/custom_selection/menu/` - Menu components
  - `lib/widget/custom_selection/builder/` - Menu builder

- **Modified files**:
  - `lib/widget/markdown.dart` - Add custom selection mode support
  - `lib/config/markdown_generator.dart` - Conditionally wrap elements
  - `lib/markdown_widget.dart` - Export new APIs

### API Changes

- `MarkdownWidget` - New parameters:
  - `enableCustomSelection: bool`
  - `customSelectionConfig: CustomSelectionConfig?`

- `MarkdownGenerator` - Optional parameter for custom selection context

### Dependencies

No new external dependencies. Uses existing Flutter APIs:
- `SelectableText` for selection control
- `Overlay` for menu display
- `TextPainter` for position calculation

### Example Changes

New example in `example/lib/pages/custom_selection_page.dart` demonstrating:
- Basic custom selection setup
- Custom menu styling
- Extended menu items
- Dark/light mode compatibility
