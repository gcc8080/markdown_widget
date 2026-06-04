import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import '../../config/custom_selection_config.dart';
import 'element_context.dart';
import 'menu/menu_overlay.dart';
import 'vendor/selectable_region_fork.dart';

/// Wraps a single markdown element with custom long-press selection behavior.
///
/// All elements share the single [MdSelectableRegionState] from the outer
/// region, so selection can cross element boundaries by dragging. On
/// "select text", the wrapper computes its own global rect and calls
/// [MdSelectableRegionState.selectRange] to select exactly this element,
/// after which the user can drag the native handles to extend across nodes.
class CustomSelectableWrapper extends StatefulWidget {
  final Widget child;
  final ElementContext elementContext;
  final CustomSelectionConfig config;
  final GlobalKey<MdSelectableRegionState> regionKey;
  final ValueNotifier<String> selectedTextNotifier;

  const CustomSelectableWrapper({
    Key? key,
    required this.child,
    required this.elementContext,
    required this.config,
    required this.regionKey,
    required this.selectedTextNotifier,
  }) : super(key: key);

  @override
  State<CustomSelectableWrapper> createState() =>
      _CustomSelectableWrapperState();
}

class _CustomSelectableWrapperState extends State<CustomSelectableWrapper>
    with WidgetsBindingObserver {
  final GlobalKey _contentKey = GlobalKey();
  OverlayEntry? _menuOverlay;
  Offset? _longPressPosition;
  Timer? _menuTimer;
  bool _menuIsActive = false;
  /// True after the user tapped "选取文字" — only then should onSelectionChanged drive the menu.
  bool _inSelectionPhase = false;

  MdSelectableRegionState? get _region => widget.regionKey.currentState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.selectedTextNotifier.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.selectedTextNotifier.removeListener(_onSelectionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _menuTimer?.cancel();
    _removeMenu();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_menuOverlay != null) {
      _removeMenu();
      _scheduleShowCopyMenu();
    }
  }

  void _onSelectionChanged() {
    // Only respond after the user tapped "选取文字"; ignore the clearSelection()
    // that fires right after long-press to reset the auto-selected word.
    if (!_menuIsActive || !_inSelectionPhase) return;
    final text = widget.selectedTextNotifier.value;
    if (text.isEmpty) {
      _removeMenu();
      return;
    }
    _menuTimer?.cancel();
    _removeMenu();
    _menuTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _menuIsActive) _showCopyMenu(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _handleLongPressStart,
      child: KeyedSubtree(key: _contentKey, child: widget.child),
    );
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _menuIsActive = true;
    _longPressPosition = details.globalPosition;
    // The region's own long-press toolbar is suppressed via contextMenuBuilder,
    // so the auto-selected word is invisible. We leave it in place and let
    // selectRange() replace it when the user taps "选取文字".
    _showInitialMenu(details.globalPosition);
  }

  void _showInitialMenu(Offset position) {
    _removeMenu();
    _menuOverlay = OverlayEntry(
      builder: (context) => MenuOverlay(
        position: position,
        config: widget.config,
        elementContext: widget.elementContext,
        isInitialMenu: true,
        onSelectText: _handleSelectText,
        onCopy: () => _handleCopy(widget.elementContext.plainText),
        onDismiss: _clearAll,
      ),
    );
    Overlay.of(context).insert(_menuOverlay!);
  }

  void _showCopyMenu(String selectedText) {
    _removeMenu();
    final position = _longPressPosition ?? Offset.zero;
    _menuOverlay = OverlayEntry(
      builder: (context) => MenuOverlay(
        position: position,
        config: widget.config,
        elementContext:
            widget.elementContext.copyWith(selectedText: selectedText),
        isInitialMenu: false,
        onCopy: () => _handleCopy(selectedText),
        onDismiss: _clearAll,
      ),
    );
    Overlay.of(context).insert(_menuOverlay!);
  }

  void _scheduleShowCopyMenu() {
    _menuTimer?.cancel();
    _menuTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _menuIsActive) {
        final text = widget.selectedTextNotifier.value;
        if (text.isNotEmpty) _showCopyMenu(text);
      }
    });
  }

  /// "选取文字": select this element's content.
  void _handleSelectText() {
    _removeMenu();
    _inSelectionPhase = true;
    _selectElementWithRetry(0);
  }

  void _selectElementWithRetry(int attempt) {
    const max = 8;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuIsActive) return;
      if (_region != null && _applyElementSelection()) {
        // Selection dispatched; onSelectionChanged fires next frame and
        // _onSelectionChanged shows the copy menu.
        return;
      }
      if (attempt < max) {
        _selectElementWithRetry(attempt + 1);
      }
    });
  }

  /// Selects the pressed element in the shared region. Returns false if the
  /// render tree isn't ready yet (caller retries).
  ///
  /// Strategy by element type:
  /// - code block / blockquote → "container" elements whose content may span
  ///   several RenderParagraphs (one per code line, or multiple quote
  ///   paragraphs). We select the whole element with a plain coordinate
  ///   [selectRange] from the first paragraph's top to the last's bottom. Using
  ///   the inner paragraph rects (not the margin-inflated outer box) keeps the
  ///   range from bleeding into the block above.
  /// - everything else (heading, paragraph, list item, table cell) is a single
  ///   logical paragraph → [selectParagraphAt] its center, which selects
  ///   exactly that paragraph without the upward bleed a coordinate range
  ///   causes for short targets.
  bool _applyElementSelection() {
    final paragraphs = _textParagraphRects();
    if (paragraphs.isEmpty) return false;
    paragraphs.sort((a, b) => a.top.compareTo(b.top));

    final type = widget.elementContext.elementType;
    if (type == 'codeBlock' || type == 'blockquote') {
      _region!.selectRange(
        paragraphs.first.topLeft + const Offset(1, 1),
        paragraphs.last.bottomRight - const Offset(1, 1),
      );
      return true;
    }

    // Choose the paragraph to select: the one under the long-press point if
    // any, else the first. Select at that paragraph's center so the point is
    // guaranteed to land on real glyphs (not padding / a bbox edge).
    final press = _longPressPosition;
    Rect target = paragraphs.first;
    if (press != null) {
      double bestArea = double.infinity;
      for (final r in paragraphs) {
        if (r.contains(press)) {
          final area = r.width * r.height;
          if (area < bestArea) {
            bestArea = area;
            target = r;
          }
        }
      }
    }
    _region!.selectParagraphAt(target.center);
    return true;
  }

  /// Global rects of every real-text [RenderParagraph] in this element.
  ///
  /// Container paragraphs that only host a WidgetSpan render as the
  /// object-replacement char (U+FFFC); those outer boxes are excluded so we
  /// operate on actual text lines.
  List<Rect> _textParagraphRects() {
    final ctx = _contentKey.currentContext;
    final root = ctx?.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return const [];

    final rects = <Rect>[];
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        final text = node.text.toPlainText().replaceAll('￼', '').trim();
        if (text.isNotEmpty) {
          final tl = node.localToGlobal(Offset.zero);
          rects.add(tl & node.size);
        }
      }
      node.visitChildren(visit);
    }

    visit(root);
    return rects;
  }

  Future<void> _handleCopy(String text) async {
    _clearAll();
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  void _removeMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  void _clearAll() {
    _menuTimer?.cancel();
    _menuIsActive = false;
    _inSelectionPhase = false;
    _removeMenu();
    _region?.clearSelection();
  }
}
