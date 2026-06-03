# Custom Selection Mode Implementation Tasks

## 1. Project Structure and Configuration

- [x] 1.1 Create directory structure for custom selection module
  - Create `lib/widget/custom_selection/` directory
  - Create subdirectories: `menu/`, `style/`, `builder/`
- [x] 1.2 Create configuration classes file
  - Create `lib/config/custom_selection_config.dart`
  - Define `CustomSelectionConfig`, `MenuStyle`, `MenuAnimationConfig`, `MenuExtension`
  - Define enums: `MenuLayout`, `MenuAnimationType`, `MenuInsertPosition`, `BuiltInMenuItem`

## 2. Core Selection Wrapper

- [x] 2.1 Create ElementContext class
  - Create `lib/widget/custom_selection/element_context.dart`
  - Implement properties: index, elementType, plainText, fullMarkdown, selection, selectedText
- [x] 2.2 Create CustomSelectableWrapper widget
  - Create `lib/widget/custom_selection/custom_selectable_wrapper.dart`
  - Implement StatefulWidget with selection mode state
  - Add AnimatedSwitcher for mode transitions
  - Implement GestureDetector for long press detection
- [x] 2.3 Implement mode switching logic
  - Add static mode: Text.rich with GestureDetector overlay
  - Add selectable mode: SelectableText.rich with selection control
  - Implement smooth transition between modes
- [x] 2.4 Implement selection state management
  - Track selection mode state
  - Track selection range
  - Track dragging state
  - Handle SelectionChangedCause for drag detection

## 3. Menu System

- [x] 3.1 Create MenuItem class
  - Create `lib/widget/custom_selection/menu/menu_item.dart`
  - Define properties: label, icon, onTap, onContextTap, enabled, style overrides
  - Create `CustomMenuItem` subclass with context support
- [x] 3.2 Create MenuOverlay widget
  - Create `lib/widget/custom_selection/menu/menu_overlay.dart`
  - Implement StatefulWidget with animation controller
  - Add position adjustment for screen boundaries
  - Implement enter and exit animations
- [x] 3.3 Create MenuBuilder class
  - Create `lib/widget/custom_selection/menu/menu_builder.dart`
  - Implement buildInitialMenu() method
  - Implement buildCopyMenu() method
  - Handle insertion positions for custom items
  - Inject ElementContext into custom items
- [x] 3.4 Implement menu lifecycle management
  - Add Overlay insert/remove logic
  - Handle overlay disposal in widget dispose
  - Implement single-menu enforcement (remove previous before showing new)

## 4. Style System

- [x] 4.1 Create MenuStyle class
  - Create `lib/widget/custom_selection/style/menu_style.dart`
  - Define container style properties
  - Define text style properties
  - Define layout properties
  - Add default light/dark theme factories
- [x] 4.2 Create MenuAnimationConfig class
  - Create `lib/widget/custom_selection/style/menu_animation.dart`
  - Define animation properties
  - Define animation types enum
- [x] 4.3 Implement menu item rendering
  - Create menu item widget with styling
  - Apply container styles (background, border, shadow)
  - Apply text and icon styles
  - Implement layout modes (horizontal, vertical, grid)
- [x] 4.4 Implement interactive states
  - Add hover state detection and styling
  - Add pressed state detection and styling
  - Implement disabled state styling
- [x] 4.5 Implement responsive styles
  - Add screen size detection
  - Apply mobile/tablet/desktop styles

## 5. Menu Animation

- [x] 5.1 Implement animation controller
  - Add AnimationController to MenuOverlay
  - Configure animation duration and curve
- [x] 5.2 Implement fade animation
  - Add FadeTransition for opacity changes
- [x] 5.3 Implement scale animation
  - Add ScaleTransition for size changes
- [x] 5.4 Implement slide animations
  - Add SlideTransition for direction-based animations
- [x] 5.5 Implement animation types
  - Support fade-only, scale-only, fade-scale combinations
  - Support slide-from-top, slide-from-bottom, slide-from-left, slide-from-right
- [x] 5.6 Implement exit animation
  - Handle reverse animation on menu dismiss
  - Remove overlay after animation completes

## 6. Selection Control Integration

- [ ] 6.1 Integrate SelectableText
  - Replace Text.rich with SelectableText.rich in selectable mode
  - Configure selection parameter for initial full selection
- [ ] 6.2 Implement selection change callbacks
  - Add onSelectionChanged handler
  - Detect drag start/end via SelectionChangedCause
  - Show/hide menu based on drag state
- [ ] 6.3 Implement outside tap detection
  - Add GestureDetector for tap detection
  - Calculate selection bounds using TextPainter.getBoxesForSelection
  - Clear selection on outside tap
- [ ] 6.4 Implement inside tap handling
  - Re-show menu when tapping inside selection
  - Maintain selection state

## 7. Element Integration

- [ ] 7.1 Modify MarkdownGenerator
  - Add optional custom selection context parameter
  - Conditionally wrap elements with CustomSelectableWrapper
  - Pass element metadata to wrapper
- [ ] 7.2 Modify MarkdownWidget
  - Add enableCustomSelection parameter
  - Add customSelectionConfig parameter
  - Pass config to MarkdownGenerator
  - Export new public APIs
- [ ] 7.3 Implement element type detection
  - Add logic to determine element type from SpanNode
  - Pass element type to ElementContext
- [ ] 7.4 Implement element-specific selection rules
  - Add table cell selection logic
  - Add image element exclusion logic
  - Add link display text selection logic
  - Add nested element (innermost) selection logic
  - Add inline element (paragraph) selection logic
  - Add non-content element exclusion logic

## 8. Extension API

- [ ] 8.1 Implement ElementContextAction typedef
  - Define callback signature for context-aware actions
- [ ] 8.2 Implement custom item context injection
  - Create closure that captures ElementContext
  - Pass context to custom item callbacks
- [ ] 8.3 Implement MenuExtension configuration
  - Add support for items list
  - Add support for position specification
- [ ] 8.4 Implement built-in item hiding
  - Add hiddenBuiltInItems processing
  - Skip hidden items in menu building

## 9. Boundary and Position Handling

- [ ] 9.1 Implement finger position capture
  - Capture LongPressStartDetails.globalPosition
  - Pass to menu positioning
- [ ] 9.2 Implement selection rect calculation
  - Use TextPainter.getBoxesForSelection
  - Convert to global coordinates
- [ ] 9.3 Implement boundary detection
  - Check menu against screen edges
  - Handle top edge case
  - Handle bottom edge case
  - Handle left/right edge cases
- [ ] 9.4 Implement position adjustment
  - Shift menu down if near top
  - Shift menu up if near bottom
  - Shift horizontally if near edges

## 10. Scroll and Lifecycle

- [ ] 10.1 Implement selection persistence during scroll
  - Ensure selection state survives scroll
  - Ensure handles remain visible
- [ ] 10.2 Implement WidgetsBindingObserver
  - Add didChangeMetrics handler
  - Reposition menu on device rotation
  - Handle keyboard appearance/disappearance
- [ ] 10.3 Implement cleanup
  - Remove overlay in dispose
  - Remove animation controller in dispose
  - Remove observer in dispose

## 11. Example Application

- [ ] 11.1 Create example page
  - Create `example/lib/pages/custom_selection_page.dart`
  - Show basic custom selection usage
- [ ] 11.2 Add style customization example
  - Demonstrate custom colors, icons, layout
  - Show light/dark theme variants
- [ ] 11.3 Add extension examples
  - Show simple custom item
  - Show context-aware custom item
  - Show conditional items by element type
- [ ] 11.4 Update example navigation
  - Add entry point to custom selection example
  - Update example app routing

## 12. Testing

- [ ] 12.1 Add unit tests for MenuBuilder
  - Test menu construction
  - Test insertion positions
  - Test built-in item hiding
- [ ] 12.2 Add widget tests for CustomSelectableWrapper
  - Test mode transitions
  - Test long press detection
  - Test menu display
- [ ] 12.3 Add integration tests
  - Test full selection flow
  - Test menu interactions
  - Test extension API
- [ ] 12.4 Add element-specific selection tests
  - Test table cell selection
  - Test image element exclusion
  - Test link text selection
  - Test nested element selection (innermost)
  - Test inline element selection (paragraph)
  - Test non-content element exclusion
  - Test drag selection across nested boundaries
- [ ] 12.5 Manual testing on devices
  - Test on Android
  - Test on iOS
  - Test scroll behavior
  - Test edge cases

## 13. Documentation

- [ ] 13.1 Write API documentation
  - Document all public classes
  - Document configuration options
  - Add code examples
- [ ] 13.2 Create README section
  - Add custom selection section to main README
  - Include quick start guide
  - Link to example code
- [ ] 13.3 Update CHANGELOG
  - Add entry for new feature
  - Document breaking changes (none expected)

## 14. Release Preparation

- [ ] 14.1 Version bump
  - Update pubspec.yaml version
  - Follow semantic versioning
- [ ] 14.2 Final testing pass
  - Run all tests
  - Manual verification on devices
  - Performance check
- [ ] 14.3 Create release notes
  - Summarize new feature
  - Document migration guide (if needed)
