import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'custom_selection_config.dart';
import 'custom_selection_scope.dart';
import 'range_resolver.dart';

/// Top-level controller widget. Hosts the gesture detector that triggers the
/// long-press menu and the overlay rendering for highlight + handles + menus.
class CustomSelectionController extends StatefulWidget {
  final CustomSelectionConfig config;
  final Widget child;

  const CustomSelectionController({
    Key? key,
    required this.config,
    required this.child,
  }) : super(key: key);

  @override
  State<CustomSelectionController> createState() =>
      _CustomSelectionControllerState();
}

class _CustomSelectionControllerState extends State<CustomSelectionController> {
  OverlayEntry? _menuEntry;
  OverlayEntry? _highlightEntry;

  // Active selection
  CustomSelectableBlock? _activeBlock;
  int _selStart = 0;
  int _selEnd = 0;
  String _selText = '';

  CustomSelectionScopeState? get _scope =>
      CustomSelectionScope.maybeOf(context);

  @override
  void dispose() {
    _removeMenu();
    _removeHighlight();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final scope = _scope;
    if (scope == null) return;
    final block = scope.hitTestBlock(d.globalPosition);
    if (block == null) return;
    _showLongPressMenu(d.globalPosition, block);
  }

  void _showLongPressMenu(Offset globalPos, CustomSelectableBlock block) {
    final cfg = widget.config;

    void onSelect() {
      _removeMenu();
      _beginSelection(block, globalPos);
    }

    final items = <CustomSelectionMenuItem>[
      CustomSelectionMenuItem(
        label: cfg.selectTextLabel,
        icon: Icons.text_fields,
        onTap: (_) => onSelect(),
      ),
      ...cfg.longPressMenuItems
          .where((e) => e.longPressOnly != false),
    ];

    _showMenu(
      anchor: globalPos,
      phase: CustomSelectionPhase.longPress,
      items: items,
      selectedText: null,
    );
  }

  void _beginSelection(CustomSelectableBlock block, Offset hitGlobal) {
    final scope = _scope!;
    ResolvedRange range;
    final spanIdx = scope.indexOf(block.index);
    if (spanIdx != null && block.rootSpan != null) {
      final paragraphOffset = scope.paragraphOffsetAt(block, hitGlobal);
      if (paragraphOffset >= 0) {
        range = spanIdx.resolve(block.rootSpan!, paragraphOffset);
      } else {
        range = spanIdx.wholeRange(block.rootSpan!);
      }
    } else {
      range = const ResolvedRange(start: 0, end: 0, text: '');
    }
    setState(() {
      _activeBlock = block;
      _selStart = range.start;
      _selEnd = range.end;
      _selText = range.text;
    });
    _showHighlightOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSelectionMenu();
    });
  }

  void _updateSelection({int? start, int? end}) {
    if (_activeBlock == null) return;
    final scope = _scope!;
    final spanIdx = scope.indexOf(_activeBlock!.index);
    if (spanIdx == null) return;
    final fullText = spanIdx.text;
    int s = start ?? _selStart;
    int e = end ?? _selEnd;
    s = s.clamp(0, fullText.length);
    e = e.clamp(0, fullText.length);
    if (s > e) {
      final t = s;
      s = e;
      e = t;
    }
    setState(() {
      _selStart = s;
      _selEnd = e;
      _selText = fullText.substring(s, e);
    });
    _highlightEntry?.markNeedsBuild();
    _menuEntry?.markNeedsBuild();
  }

  void _showSelectionMenu() {
    if (_activeBlock == null) return;
    final scope = _scope!;
    final rect = scope.rangeGlobalRect(_activeBlock!, _selStart, _selEnd);
    final anchor = Offset(rect.left + rect.width / 2, rect.top);
    final cfg = widget.config;
    final items = <CustomSelectionMenuItem>[
      CustomSelectionMenuItem(
        label: cfg.copyLabel,
        icon: Icons.copy,
        onTap: (ctx) async {
          await Clipboard.setData(ClipboardData(text: ctx.selectedText ?? ''));
          _clearAll();
        },
      ),
      ...cfg.selectionMenuItems.where((e) => e.longPressOnly != true),
    ];
    _showMenu(
      anchor: anchor,
      phase: CustomSelectionPhase.selection,
      items: items,
      selectedText: _selText,
    );
  }

  void _showMenu({
    required Offset anchor,
    required CustomSelectionPhase phase,
    required List<CustomSelectionMenuItem> items,
    required String? selectedText,
  }) {
    _removeMenu();
    final overlay = Overlay.of(context, rootOverlay: true);
    _menuEntry = OverlayEntry(builder: (ctx) {
      final ctxObj = CustomSelectionContext(
        phase: phase,
        selectedText: phase == CustomSelectionPhase.selection
            ? _selText
            : selectedText,
        anchorGlobalPosition: phase == CustomSelectionPhase.selection
            ? _currentSelectionAnchor() ?? anchor
            : anchor,
        dismiss: _clearAll,
        clearSelection: _clearAll,
      );
      Widget menu;
      if (widget.config.menuBuilder != null) {
        menu = widget.config.menuBuilder!(ctx, phase, items, ctxObj);
      } else {
        menu = _DefaultMenu(items: items, ctx: ctxObj);
      }
      return _MenuPositioner(
        anchor: ctxObj.anchorGlobalPosition,
        gap: widget.config.menuGap,
        onTapOutside: _clearAll,
        child: menu,
      );
    });
    overlay.insert(_menuEntry!);
  }

  Offset? _currentSelectionAnchor() {
    if (_activeBlock == null) return null;
    final rect =
        _scope!.rangeGlobalRect(_activeBlock!, _selStart, _selEnd);
    return Offset(rect.left + rect.width / 2, rect.top);
  }

  void _showHighlightOverlay() {
    _removeHighlight();
    final overlay = Overlay.of(context, rootOverlay: true);
    _highlightEntry = OverlayEntry(builder: (_) {
      if (_activeBlock == null) return const SizedBox.shrink();
      final rects =
          _scope!.selectionRectsGlobal(_activeBlock!, _selStart, _selEnd);
      return _HighlightLayer(
        rects: rects,
        color: widget.config.highlightColor,
        startHandlePosition: _handlePosition(true),
        endHandlePosition: _handlePosition(false),
        onStartDrag: (g) => _handleDrag(true, g),
        onEndDrag: (g) => _handleDrag(false, g),
      );
    });
    overlay.insert(_highlightEntry!);
  }

  Offset _handlePosition(bool start) {
    final scope = _scope!;
    final rects =
        scope.selectionRectsGlobal(_activeBlock!, _selStart, _selEnd);
    if (rects.isEmpty) return Offset.zero;
    if (start) return rects.first.bottomLeft;
    return rects.last.bottomRight;
  }

  void _handleDrag(bool isStart, Offset globalPos) {
    if (_activeBlock == null) return;
    final scope = _scope!;
    final hit = scope.hitTestBlock(globalPos) ?? _activeBlock!;
    if (hit.index != _activeBlock!.index) {
      // Stay within current block for simplicity.
      return;
    }
    final off = scope.paragraphOffsetAt(_activeBlock!, globalPos);
    if (off < 0) return;
    if (isStart) {
      _updateSelection(start: off);
    } else {
      _updateSelection(end: off);
    }
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _removeHighlight() {
    _highlightEntry?.remove();
    _highlightEntry = null;
  }

  void _clearAll() {
    _removeMenu();
    _removeHighlight();
    setState(() {
      _activeBlock = null;
      _selStart = 0;
      _selEnd = 0;
      _selText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _onLongPressStart,
      onTap: () {
        // Tapping outside the menu/handles dismisses everything.
        if (_menuEntry != null || _highlightEntry != null) _clearAll();
      },
      child: widget.child,
    );
  }
}

/// Positions [child] above (or below if no room) [anchor] in global coords.
class _MenuPositioner extends StatelessWidget {
  final Offset anchor;
  final double gap;
  final Widget child;
  final VoidCallback onTapOutside;

  const _MenuPositioner({
    Key? key,
    required this.anchor,
    required this.gap,
    required this.child,
    required this.onTapOutside,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTapOutside,
          ),
        ),
        CustomSingleChildLayout(
          delegate: _MenuLayoutDelegate(anchor: anchor, gap: gap),
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchor;
  final double gap;

  _MenuLayoutDelegate({required this.anchor, required this.gap});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = anchor.dx - childSize.width / 2;
    double y = anchor.dy - childSize.height - gap;
    if (y < 8) y = anchor.dy + gap; // flip below if no room
    if (x < 8) x = 8;
    if (x + childSize.width > size.width - 8) {
      x = size.width - childSize.width - 8;
    }
    if (y + childSize.height > size.height - 8) {
      y = size.height - childSize.height - 8;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _MenuLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.gap != gap;
}

class _DefaultMenu extends StatelessWidget {
  final List<CustomSelectionMenuItem> items;
  final CustomSelectionContext ctx;

  const _DefaultMenu({Key? key, required this.items, required this.ctx})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map((it) => InkWell(
                    onTap: () => it.onTap(ctx),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (it.icon != null) ...[
                            Icon(it.icon, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Text(it.label),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// Paints the highlight rects + drag handles in the overlay.
class _HighlightLayer extends StatelessWidget {
  final List<Rect> rects;
  final Color color;
  final Offset startHandlePosition;
  final Offset endHandlePosition;
  final void Function(Offset globalPos) onStartDrag;
  final void Function(Offset globalPos) onEndDrag;

  const _HighlightLayer({
    Key? key,
    required this.rects,
    required this.color,
    required this.startHandlePosition,
    required this.endHandlePosition,
    required this.onStartDrag,
    required this.onEndDrag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: true,
            child: CustomPaint(
              size: Size.infinite,
              painter: _HighlightPainter(rects: rects, color: color),
            ),
          ),
          _Handle(
            position: startHandlePosition,
            onDrag: onStartDrag,
          ),
          _Handle(
            position: endHandlePosition,
            onDrag: onEndDrag,
          ),
        ],
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final List<Rect> rects;
  final Color color;

  _HighlightPainter({required this.rects, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in rects) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) =>
      oldDelegate.rects != rects || oldDelegate.color != color;
}

class _Handle extends StatelessWidget {
  final Offset position;
  final void Function(Offset globalPos) onDrag;

  const _Handle({Key? key, required this.position, required this.onDrag})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDrag(d.globalPosition),
        child: SizedBox(
          width: size,
          height: size + 8,
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
