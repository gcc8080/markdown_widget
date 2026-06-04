## 1. Data Models & Configuration

- [ ] 1.1 Create `lib/config/custom_selection_config.dart` — define `CustomSelectionConfig` class with `firstStageMenuBuilder`, `secondStageMenuBuilder`, `onTextSelected`, `selectionColor`, `hapticFeedback` fields
- [ ] 1.2 Create `MarkdownElementInfo` class in same file — with `tag` (MarkdownTag), `plainText`, `sourceText`, `widgetIndex`, `globalRect` fields
- [ ] 1.3 Modify `lib/config/configs.dart` — add `customSelectionConfig` as named parameter to `MarkdownConfig` constructor, update `copy()` method to propagate it

## 2. Element Metadata Extraction

- [ ] 2.1 Create `MarkdownBuildResult` class in `lib/config/markdown_generator.dart` — holding `widgets` and `elementInfos` lists
- [ ] 2.2 Implement `buildWidgetsWithInfo()` method in `MarkdownGenerator` — generates both widget list and parallel `MarkdownElementInfo` list
- [ ] 2.3 Implement sourceText extraction via line-number matching — track original markdown lines consumed by each top-level AST node to extract raw source text
- [ ] 2.4 Verify backward compatibility — ensure existing `buildWidgets()` signature and behavior unchanged

## 3. CustomSelectableRegion Widget

- [ ] 3.1 Create `lib/widget/custom_selectable_region.dart` — based on Flutter 3.27.4 `SelectableRegion` source, with minimal modifications
- [ ] 3.2 Replace long-press gesture handler — invoke `onLongPress(Offset)` callback instead of selecting a word
- [ ] 3.3 Suppress default context menu — remove `contextMenuBuilder` integration, all menus controlled externally
- [ ] 3.4 Expose programmatic selection API — implement `selectRange(Offset start, Offset end)`, `showHandles()`, `hideHandles()`, `getSelectedContent()`, `clearSelection()` on `CustomSelectableRegionState`
- [ ] 3.5 Add handle drag callbacks — `onHandleDragStart` and `onHandleDragEnd`
- [ ] 3.6 Support custom `selectionColor` — pass through to selection overlay painter
- [ ] 3.7 Implement hit-test for element identification — on long-press, walk render tree to find nearest ancestor with `MarkdownElementInfo` metadata

## 4. Element Metadata Widget Integration

- [ ] 4.1 Create `lib/widget/selectable_element_wrapper.dart` — a widget that attaches `MarkdownElementInfo` metadata to each block-level element via an InheritedWidget for hit-test lookup
- [ ] 4.2 Handle img/hr elements — do not attach metadata to image and horizontal rule elements (long-press ignored)

## 5. MarkdownWidget Integration

- [ ] 5.1 Modify `lib/widget/markdown.dart` — when `customSelectionConfig` is non-null and `selectable=true`, use `CustomSelectableRegion` instead of `SelectionArea`
- [ ] 5.2 Wrap each ListView item with `SelectableElementWrapper` — providing `MarkdownElementInfo` metadata for hit-test
- [ ] 5.3 Implement Overlay management in `_MarkdownWidgetState` — `_showFirstStageMenu()`, `_showSecondStageMenu()`, `_dismissMenu()` lifecycle methods
- [ ] 5.4 Implement state machine — idle → stage1 → stage2 → idle transitions, including re-long-press clearing previous selection
- [ ] 5.5 Wire `onTextSelected` callback — invoke when selection changes in Stage 2
- [ ] 5.6 Implement haptic feedback — trigger `HapticFeedback.mediumImpact()` on long-press when enabled

## 6. MarkdownBlock Integration

- [ ] 6.1 Modify `lib/widget/markdown_block.dart` — convert to StatefulWidget, apply same `CustomSelectableRegion` logic as MarkdownWidget
- [ ] 6.2 Verify Column layout compatibility — ensure selection works correctly with Column-based layout (no scroll controller)

## 7. Export & Package Updates

- [ ] 7.1 Update `lib/markdown_widget.dart` — add exports for `custom_selection_config.dart`
- [ ] 7.2 Update `lib/widget/all.dart` — add exports for `custom_selectable_region.dart` and `selectable_element_wrapper.dart`

## 8. Example App Integration

- [ ] 8.1 Create `example/lib/pages/custom_selection_page.dart` — demo page with rich markdown content covering all element types (headings, paragraphs, lists, nested lists, blockquotes, nested blockquotes, code blocks, tables, images, links, horizontal rules, checkboxes, inline code, bold/italic)
- [ ] 8.2 Implement Stage 1 menu UI — vertical list with "Select Text", "Copy Source", "Bookmark", "Share" buttons
- [ ] 8.3 Implement Stage 2 menu UI — horizontal toolbar with "Copy", "Bookmark", "Translate" buttons
- [ ] 8.4 Add debug info panel — display pressed element's tag, plainText, sourceText at bottom of page
- [ ] 8.5 Modify `example/lib/pages/router.dart` — add `custom_selection` route to `RouterEnum` and route configuration
- [ ] 8.6 Modify `example/lib/widget/menu.dart` — add "Custom Selection" `NavItem` with ✂️ emoji to sidebar menu

## 9. Verification

- [ ] 9.1 Run `fvm flutter analyze` — zero analysis errors
- [ ] 9.2 Run `fvm flutter test` — all existing tests pass
- [ ] 9.3 Manual testing via example app — verify all 20 functional scenarios from the verification plan
