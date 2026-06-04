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

  /// "选取文字": select exactly this element's content via its global rect.
  void _handleSelectText() {
    _removeMenu();
    _inSelectionPhase = true;
    _selectElementWithRetry(0);
  }

  void _selectElementWithRetry(int attempt) {
    const max = 8;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuIsActive) return;
      final rect = _targetParagraphRect();
      if (rect != null && _region != null) {
        // Inset slightly so the edge points land on real glyphs, not the
        // paragraph's bounding-box border.
        final start = rect.topLeft + const Offset(1, 1);
        final end = rect.bottomRight - const Offset(1, 1);
        _region!.selectRange(start, end);
        // selectRange is synchronous; onSelectionChanged fires next frame.
        // _onSelectionChanged will show the copy menu when the notifier updates.
        return;
      }
      // rect not ready yet — retry next frame
      if (attempt < max) {
        _selectElementWithRetry(attempt + 1);
      }
    });
  }

  /// Returns the global rect of the [RenderParagraph] the user long-pressed.
  ///
  /// We select at paragraph granularity rather than the wrapper's outer render
  /// box. This is what makes element-scoped selection correct:
  /// - heading: picks the text paragraph, not the divider below it
  /// - list: picks only the tapped list item, not the whole list column
  /// - blockquote / table: picks the inner text, excluding the decoration
  ///   margin that would otherwise overshoot into the element above
  /// - table cell: picks just that cell's paragraph
  ///
  /// Falls back to the largest paragraph in the element if the press position
  /// can't be matched (e.g. menu re-show after rotation).
  Rect? _targetParagraphRect() {
    final ctx = _contentKey.currentContext;
    final root = ctx?.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return null;

    final paragraphs = <RenderParagraph>[];
    void visit(RenderObject node) {
      if (node is RenderParagraph) paragraphs.add(node);
      node.visitChildren(visit);
    }

    visit(root);

    // Keep only paragraphs that hold real text. Container paragraphs that just
    // host a WidgetSpan render as the object-replacement char (U+FFFC); those
    // are the outer list/heading/quote boxes we must NOT select as a whole.
    bool hasRealText(RenderParagraph p) {
      final t = p.text.toPlainText().replaceAll('￼', '').trim();
      return t.isNotEmpty;
    }

    final textParagraphs = paragraphs.where(hasRealText).toList();
    if (textParagraphs.isEmpty) {
      final tl = root.localToGlobal(Offset.zero);
      return tl & root.size;
    }

    Rect rectOf(RenderParagraph p) {
      final tl = p.localToGlobal(Offset.zero);
      return tl & p.size;
    }

    // Among paragraphs containing the long-press point, pick the innermost
    // (smallest area) — that's the specific list item / cell / line tapped.
    final press = _longPressPosition;
    if (press != null) {
      RenderParagraph? best;
      double bestArea = double.infinity;
      for (final p in textParagraphs) {
        final r = rectOf(p);
        if (r.contains(press)) {
          final area = r.width * r.height;
          if (area < bestArea) {
            bestArea = area;
            best = p;
          }
        }
      }
      if (best != null) return rectOf(best);
    }

    // Fallback: the tallest text paragraph (the main content block).
    textParagraphs.sort((a, b) => b.size.height.compareTo(a.size.height));
    return rectOf(textParagraphs.first);
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
