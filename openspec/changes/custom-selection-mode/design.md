# Custom Selection Mode Design

## Context

### Current State

The `markdown_widget` currently uses Flutter's `SelectionArea` widget for text selection. When `selectable=true`, the entire `ListView` is wrapped with `SelectionArea`, which provides:
- Default long-press to select behavior
- System-style context menu
- Copy functionality
- Selection handles for adjustment

This approach is simple but limited:
- Menu appearance cannot be customized
- Menu items cannot be extended
- Selection behavior is all-or-nothing (entire widget or none)
- No per-element control

### Constraints

- Flutter version: 3.27.4
- Must not break existing `selectable` behavior
- Must support both light and dark themes
- Performance must not degrade for documents with hundreds of elements
- Example app must demonstrate the feature

### Stakeholders

- End users: Expect branded, app-consistent menu experiences
- Developers: Need easy-to-use extension API
- UI/UX: Menus must follow platform conventions while being customizable

## Goals / Non-Goals

**Goals:**
1. Provide fully customizable menu appearance (colors, icons, layout, animations)
2. Enable per-element selection control with element-aware menu positioning
3. Support extensible menu items with access to element context
4. Maintain smooth scrolling and performance
5. Provide clear API for enabling/disabling custom selection mode
6. Support both mobile and desktop platforms

**Non-Goals:**
1. Rich text editing within selected content
2. Multi-element selection (selecting across element boundaries)
3. Undo/redo for selection actions
4. Persistent selection state across app sessions
5. Custom selection for `MarkdownBlock` (only `MarkdownWidget`)

## Decisions

### Decision 1: Element-Level Wrapper Architecture

**Choice:** Wrap each markdown element individually with `CustomSelectableWrapper` instead of replacing the global `SelectionArea`.

**Rationale:**
- Enables per-element context access (index, type, content)
- Allows element-specific menu positioning
- Supports element-type-specific menu items (e.g., "Run Code" for code blocks)
- Maintains clean separation between elements

**Alternatives Considered:**
- **A. Keep global SelectionArea, override contextMenuBuilder**
  - Rejected: Cannot control when selection starts, limited customization
- **B. Replace entire ListView with custom selection widget**
  - Rejected: Tighter coupling, harder to maintain, breaks ListView features

### Decision 2: AnimatedSwitcher for Mode Transitions

**Choice:** Use `AnimatedSwitcher` to transition between static (Text.rich) and selectable (SelectableText) modes.

**Rationale:**
- Smooth visual transition reduces perceived jank
- Automatic cross-fade animation
- Simple state-based switching

**Alternatives Considered:**
- **A. Direct setState without animation**
  - Rejected: Visual flicker, poor UX
- **B. Stack with Opacity layer**
  - Rejected: Renders content twice (performance waste)

### Decision 3: Overlay for Menu Display

**Choice:** Use Flutter's `Overlay` mechanism to display menus as floating layers above the content.

**Rationale:**
- Menus can appear anywhere without affecting layout
- Proper z-index ordering (above content)
- Natural dismissal mechanism (remove from Overlay)
- Widely used pattern in Flutter ecosystem

**Alternatives Considered:**
- **A. CustomPaint to draw menu directly**
  - Rejected: Complex, no built-in interaction handling
- **B. Positioned widgets in element's Stack**
  - Rejected: Menus clipped by element bounds, overflow issues

### Decision 4: MenuBuilder Pattern for Extension

**Choice:** Use a builder pattern that accepts config and context to construct menus with user-defined items.

**Rationale:**
- Clean separation of menu structure and content
- Type-safe context passing to custom items
- Flexible positioning options (after built-in, replace built-in, replace all)

**Alternatives Considered:**
- **A. Direct callback list passed to widget**
  - Rejected: Less structured, harder to manage positions
- **B. Widget composition for menu items**
  - Rejected: More complex for simple use cases

### Decision 5: ElementContext for Extension API

**Choice:** Provide `ElementContext` object with index, type, plainText, fullMarkdown, and selection to custom menu items.

**Rationale:**
- Single object contains all relevant information
- Immutable, easy to pass around
- Extensible for future properties

**Alternatives Considered:**
- **A. Pass individual parameters to callbacks**
  - Rejected: Callback signature changes when adding properties
- **B. Pass entire SpanNode**
  - Rejected: Tighter coupling to internal representation

### Decision 6: GestureDetector with HitTestBehavior.translucent

**Choice:** Use `GestureDetector` with `HitTestBehavior.translucent` on top of content for long-press detection.

**Rationale:**
- Detects long-press without blocking other gestures
- Does not interfere with ListView scrolling
- Allows tap-through for other gestures

**Alternatives Considered:**
- **A. Listener widget**
  - Rejected: Lower-level, more complex
- **B. AbsorbPointer**
  - Rejected: Would block all child interactions

## Architecture

### Component Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    MarkdownWidget                           │
│  enableCustomSelection: bool                                │
│  customSelectionConfig: CustomSelectionConfig               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                 MarkdownGenerator                           │
│  (conditionally wraps elements when custom mode on)        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              CustomSelectableWrapper                        │
│  • Long press detection                                      │
│  • Mode switching (static ↔ selectable)                      │
│  • Menu orchestration                                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    MenuBuilder                               │
│  • Constructs menu from built-in + extended items           │
│  • Injects ElementContext                                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                 MenuOverlay (via Overlay)                   │
│  • Positioned menu display                                    │
│  • Animation handling                                        │
│  • Boundary detection                                        │
└─────────────────────────────────────────────────────────────┘
```

### State Machine

```
┌─────────────┐   Long press   ┌──────────┐   Select text   ┌─────────────┐
│   Static    │ ──────────────▶│  Menu    │ ────────────────▶│ Selectable  │
│   (Text)    │                │ Shown    │                  │  (Select)   │
└─────────────┘                └──────────┘                  └─────────────┘
                                                                            │
                                                                            │ Drag end
                      Copy/Bookmark/Share or                        ┌──────────┐
                      click outside                                 │Menu with │
                          │                                       │   Copy   │
                          ▼                                       └──────────┘
                   ┌─────────────┐
                   │   Static    │
                   └─────────────┘
```

### Key Classes

```dart
// Configuration
CustomSelectionConfig {
  enabled: bool
  menuStyle: MenuStyle
  animationConfig: MenuAnimationConfig
  extension: MenuExtension
  hiddenBuiltInItems: Set<BuiltInMenuItem>
}

// Core wrapper
CustomSelectableWrapper (StatefulWidget)
  _CustomSelectableWrapperState
    - _isInSelectionMode: bool
    - _selection: TextSelection
    - _menuOverlay: OverlayEntry?

// Context
ElementContext {
  index: int
  elementType: String
  plainText: String
  fullMarkdown: String
  selection: TextSelection?
  selectedText: String?
}

// Menu system
MenuBuilder
  + buildInitialMenu() → List<MenuItem>
  + buildCopyMenu() → List<MenuItem>

MenuOverlay (StatefulWidget)
  _MenuOverlayState
    - AnimationController
    - position adjustment
    - boundary handling
```

## Data Flow

### Initial Menu Flow

```
User long press
    ↓
CustomSelectableWrapper.onLongPressStart
    ↓
Capture global position
    ↓
Create ElementContext
    ↓
MenuBuilder.buildInitialMenu(built-in + extended items)
    ↓
Overlay.insert(MenuOverlay)
    ↓
Menu positioned above finger
    ↓
User taps item
    ↓
Execute callback (with ElementContext if custom item)
    ↓
Remove overlay
```

### Selection Flow

```
User taps "Select Text"
    ↓
setState → _isInSelectionMode = true
    ↓
AnimatedSwitcher → SelectableText.rich with full selection
    ↓
Selection handles appear
    ↓
onSelectionChanged triggers
    ↓
If drag: hide menu
    ↓
If drag ends: show menu with selection rect
    ↓
User drags handles: onSelectionChanged → menu hides
    ↓
User releases: menu reappears
```

## Risks / Trade-offs

### Risks

1. **Performance with many elements**
   - **Risk**: Wrapping each element adds overhead
   - **Mitigation**: Use `const` constructors where possible, avoid rebuilding unnecessarily

2. **Menu positioning edge cases**
   - **Risk**: Menu may appear off-screen near edges
   - **Mitigation**: Boundary detection with position adjustment

3. **Memory leaks with Overlay**
   - **Risk**: OverlayEntry not properly disposed
   - **Mitigation**: Always remove overlay in dispose, use widget lifecycle

4. **Gesture conflicts**
   - **Risk**: Custom gestures may interfere with scrolling
   - **Mitigation**: Use `HitTestBehavior.translucent`, test thoroughly

### Trade-offs

1. **Element wrapping vs. Global control**
   - **Trade-off**: Individual wrappers add complexity vs. cleaner separation
   - **Decision**: Individual wrappers for flexibility

2. **AnimatedSwitcher vs. instant switch**
   - **Trade-off**: Animation adds perceived polish vs. slight performance cost
   - **Decision**: AnimatedSwitcher for better UX

3. **Overlay vs. Positioned widget**
   - **Trade-off**: Overlay is more flexible vs. Positioned is simpler
   - **Decision**: Overlay for proper z-index and boundary handling

## Migration Plan

### Phase 1: Core Implementation
1. Create configuration classes
2. Implement CustomSelectableWrapper
3. Implement basic menu system
4. Add to MarkdownWidget

### Phase 2: Menu Customization
1. Implement MenuStyle system
2. Implement MenuAnimationConfig
3. Add default styles for light/dark themes

### Phase 3: Extension API
1. Implement ElementContext
2. Implement MenuExtension
3. Implement MenuBuilder

### Phase 4: Example and Testing
1. Create example page
2. Add tests for core functionality
3. Performance testing

### Rollback Strategy

If issues arise:
1. Set `enableCustomSelection = false` globally
2. Falls back to existing SelectionArea behavior
3. No code changes required, just configuration

## Open Questions

1. **Should menu support keyboard navigation?**
   - Currently focused on touch interactions
   - Desktop users may expect keyboard access
   - **Decision**: Defer to future enhancement

2. **Should selection state persist across route navigation?**
   - Current design clears selection on dispose
   - **Decision**: Current behavior is sufficient, enhancement can be added later

3. **How to handle accessibility (screen readers)?**
   - SelectableText has some accessibility support
   - Custom menus may need Semaphore annotations
   - **Decision**: Document for future accessibility improvement

## Implementation Notes

### File Structure
```
lib/
├── config/
│   └── custom_selection_config.dart       # Configuration classes
├── widget/
│   ├── markdown.dart                       # Modified: Add custom mode
│   ├── custom_selection/
│   │   ├── custom_selectable_wrapper.dart  # Core wrapper
│   │   ├── element_context.dart            # Context object
│   │   ├── menu/
│   │   │   ├── menu_builder.dart           # Menu construction
│   │   │   ├── menu_overlay.dart           # Menu display
│   │   │   └── menu_item.dart             # Menu item widgets
│   │   └── style/
│   │       ├── menu_style.dart             # Style configuration
│   │       └── menu_animation.dart         # Animation config
```

### Key Dependencies
- Flutter SDK (SelectableText, Overlay, AnimatedSwitcher)
- No external package dependencies

### Testing Strategy
1. Unit tests for MenuBuilder logic
2. Widget tests for CustomSelectableWrapper
3. Integration tests for full flow
4. Manual testing on physical devices for touch behavior
