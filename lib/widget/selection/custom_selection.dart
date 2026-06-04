import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'selection_config.dart';

const _selectTextActionId = 'markdown_widget.select_text';
const _copyActionId = 'markdown_widget.copy';

/// Root wrapper for Markdown custom selection mode.
class MarkdownCustomSelectionArea extends StatefulWidget {
  final Widget child;
  final MarkdownSelectionConfig config;

  const MarkdownCustomSelectionArea({
    Key? key,
    required this.child,
    required this.config,
  }) : super(key: key);

  @override
  State<MarkdownCustomSelectionArea> createState() =>
      _MarkdownCustomSelectionAreaState();
}

class _MarkdownCustomSelectionAreaState
    extends State<MarkdownCustomSelectionArea> {
  final _MarkdownSelectionDelegate _selectionDelegate =
      _MarkdownSelectionDelegate();
  OverlayEntry? _menuEntry;
  OverlayEntry? _handlesEntry;
  MarkdownSelectionTarget? _selectedTarget;
  Rect? _selectedRect;
  bool _ignoreNextPointerUpAfterScroll = false;
  bool _ignoreNextPointerUpAfterHandleDrag = false;
  bool _pendingHandleRefresh = false;

  @override
  void initState() {
    super.initState();
    _selectionDelegate.addListener(_handleSelectionGeometryChanged);
  }

  @override
  void dispose() {
    _selectionDelegate.removeListener(_handleSelectionGeometryChanged);
    _removeMenu();
    _removeHandles();
    _selectionDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MarkdownCustomSelectionScope(
      controller: this,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (event) {
          if (_ignoreNextPointerUpAfterScroll ||
              _ignoreNextPointerUpAfterHandleDrag) {
            _ignoreNextPointerUpAfterScroll = false;
            _ignoreNextPointerUpAfterHandleDrag = false;
            return;
          }
          handleTap(event.position);
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _ignoreNextPointerUpAfterScroll = true;
              _removeMenu();
            }
            _scheduleHandleRefresh();
            return false;
          },
          child: SelectionContainer(
            delegate: _selectionDelegate,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  void showInitialMenu(
    MarkdownSelectionTarget target,
    Offset globalPosition,
    Rect targetRect,
  ) {
    final applicationActions = widget.config.initialMenuActions;
    final builtInActions = target.canSelectText && target.hasText
        ? [
            MarkdownSelectionMenuAction(
              id: _selectTextActionId,
              label: '选取文字',
              onPressed: (context) => context.selectText(),
            )
          ]
        : const <MarkdownSelectionMenuAction>[];
    if (builtInActions.isEmpty && applicationActions.isEmpty) {
      _removeMenu();
      return;
    }
    final menuContext = MarkdownSelectionMenuContext(
      target: target,
      globalPosition: globalPosition,
      selectedRect: null,
      selectedText: '',
      hasSelection: false,
      builtInActions: builtInActions,
      applicationActions: applicationActions,
      dismiss: _removeMenu,
      selectText: () => selectTarget(target, targetRect),
      copy: () {},
      clearSelection: clearSelection,
    );
    _showMenu(
      globalPosition,
      widget.config.initialMenuBuilder,
      menuContext,
    );
  }

  void selectTarget(MarkdownSelectionTarget target, Rect targetRect) {
    _removeMenu();
    _selectedTarget = target;
    _selectionDelegate.selectTargetRect(targetRect);
    _selectedRect = _selectionDelegate.selectedGlobalRect ?? targetRect;
    _showHandles();
    _showSelectedMenu(target, _selectedRect!);
    setState(() {});
  }

  void clearSelection() {
    _selectedTarget = null;
    _selectedRect = null;
    _removeMenu();
    _removeHandles();
    _selectionDelegate.clear();
    if (mounted) setState(() {});
  }

  void handleTap(Offset globalPosition) {
    final selectedTarget = _selectedTarget;
    if (selectedTarget == null) return;
    if (_selectionDelegate.containsGlobalPosition(globalPosition)) {
      final rect = _selectionDelegate.selectedGlobalRect ?? _selectedRect;
      if (rect != null) _showSelectedMenu(selectedTarget, rect);
    } else {
      clearSelection();
    }
  }

  bool isSelected(String targetId) => _selectedTarget?.id == targetId;

  void _showSelectedMenu(MarkdownSelectionTarget target, Rect targetRect) {
    final menuPosition = Offset(targetRect.center.dx, targetRect.top);
    final selectedText =
        _selectionDelegate.selectedPlainText ?? target.plainText;
    final applicationActions = widget.config.selectedTextMenuActions
        .map(
          (action) => MarkdownSelectionMenuAction(
            id: action.id,
            label: action.label,
            icon: action.icon,
            onPressed: (context) {
              clearSelection();
              action.onPressed(context);
            },
          ),
        )
        .toList(growable: false);
    final menuContext = MarkdownSelectionMenuContext(
      target: target,
      globalPosition: menuPosition,
      selectedRect: targetRect,
      selectedText: selectedText,
      hasSelection: true,
      builtInActions: [
        MarkdownSelectionMenuAction(
          id: _copyActionId,
          label: '复制',
          onPressed: (context) => context.copy(),
        )
      ],
      applicationActions: applicationActions,
      dismiss: _removeMenu,
      selectText: () => selectTarget(target, targetRect),
      copy: () => _copyAndClear(selectedText),
      clearSelection: clearSelection,
    );
    _showMenu(
      menuPosition,
      widget.config.selectedTextMenuBuilder,
      menuContext,
    );
  }

  void _copyAndClear(String text) {
    clearSelection();
    Clipboard.setData(ClipboardData(text: text));
  }

  void _showMenu(
    Offset globalPosition,
    MarkdownSelectionMenuBuilder? builder,
    MarkdownSelectionMenuContext menuContext,
  ) {
    _removeMenu();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _menuEntry = OverlayEntry(
      builder: (context) => _MarkdownSelectionMenuOverlay(
        globalPosition: globalPosition,
        child: builder?.call(context, menuContext) ??
            _DefaultMarkdownSelectionMenu(context: menuContext),
      ),
    );
    overlay.insert(_menuEntry!);
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _handleSelectionGeometryChanged() {
    final rect = _selectionDelegate.selectedGlobalRect;
    _selectedRect = rect ?? _selectedRect;
    if (_selectedTarget == null || !_selectionDelegate.hasSelection) {
      _removeHandles();
      return;
    }
    _showHandles();
  }

  void _showHandles() {
    if (!_selectionDelegate.hasVisibleEndpoints) {
      _removeHandles();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final existingEntry = _handlesEntry;
    if (existingEntry != null) {
      existingEntry.markNeedsBuild();
    } else {
      _handlesEntry = OverlayEntry(
        builder: (context) => _MarkdownSelectionHandlesOverlay(
          delegate: _selectionDelegate,
          color: widget.config.handleColor,
          onDragStart: () {
            _ignoreNextPointerUpAfterHandleDrag = true;
            _removeMenu();
          },
          onDragEnd: () {
            final target = _selectedTarget;
            final rect = _selectionDelegate.selectedGlobalRect;
            if (target != null && rect != null) {
              _selectedRect = rect;
              _showSelectedMenu(target, rect);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ignoreNextPointerUpAfterHandleDrag = false;
            });
          },
        ),
      );
      overlay.insert(_handlesEntry!);
    }
  }

  void _removeHandles() {
    _handlesEntry?.remove();
    _handlesEntry = null;
  }

  void _scheduleHandleRefresh() {
    if (_pendingHandleRefresh) return;
    _pendingHandleRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingHandleRefresh = false;
      if (!mounted) return;
      if (_selectedTarget != null && _selectionDelegate.hasSelection) {
        _showHandles();
      }
    });
  }
}

class MarkdownSelectionTargetWidget extends StatelessWidget {
  final MarkdownSelectionTarget target;
  final Widget child;

  const MarkdownSelectionTargetWidget({
    Key? key,
    required this.target,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = _MarkdownCustomSelectionScope.maybeOf(context);
    if (controller == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        final rect = _globalRectOf(context);
        controller.showInitialMenu(target, details.globalPosition, rect);
      },
      child: child,
    );
  }

  Rect _globalRectOf(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      return topLeft & renderObject.size;
    }
    return Rect.zero;
  }
}

class _MarkdownCustomSelectionScope extends InheritedWidget {
  final _MarkdownCustomSelectionAreaState controller;

  const _MarkdownCustomSelectionScope({
    required this.controller,
    required Widget child,
  }) : super(child: child);

  static _MarkdownCustomSelectionAreaState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MarkdownCustomSelectionScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_MarkdownCustomSelectionScope oldWidget) {
    return true;
  }
}

class _MarkdownSelectionDelegate
    extends MultiSelectableSelectionContainerDelegate {
  Rect? _activeTargetRect;

  bool get hasSelection => value.hasSelection;

  bool get hasVisibleEndpoints {
    return value.startSelectionPoint != null && value.endSelectionPoint != null;
  }

  String? get selectedPlainText => getSelectedContent()?.plainText;

  Offset? get globalStartPoint {
    final point = value.startSelectionPoint;
    if (point == null) return null;
    return MatrixUtils.transformPoint(
        getTransformTo(null), point.localPosition);
  }

  Offset? get globalEndPoint {
    final point = value.endSelectionPoint;
    if (point == null) return null;
    return MatrixUtils.transformPoint(
        getTransformTo(null), point.localPosition);
  }

  Rect? get selectedGlobalRect {
    final transform = getTransformTo(null);
    Rect? result;
    for (final rect in value.selectionRects) {
      final globalRect = MatrixUtils.transformRect(transform, rect);
      result = result == null ? globalRect : result.expandToInclude(globalRect);
    }
    if (result != null) return result;
    final start = globalStartPoint;
    final end = globalEndPoint;
    if (start != null && end != null) {
      return Rect.fromPoints(start, end).inflate(1);
    }
    final point = start ?? end;
    if (point == null) return null;
    return Rect.fromCenter(center: point, width: 1, height: 1);
  }

  void selectTargetRect(Rect targetRect) {
    _activeTargetRect = targetRect;
    if (selectables.isEmpty) return;
    selectables.sort(compareOrder);
    final selectedIndexes = <int>[];
    for (var i = 0; i < selectables.length; i += 1) {
      final selectable = selectables[i];
      if (_selectableIntersectsGlobalRect(selectable, targetRect)) {
        selectedIndexes.add(i);
      } else {
        dispatchSelectionEventToChild(selectable, const ClearSelectionEvent());
      }
    }
    if (selectedIndexes.isEmpty) {
      currentSelectionStartIndex = -1;
      currentSelectionEndIndex = -1;
      layoutDidChange();
      return;
    }
    for (final index in selectedIndexes) {
      dispatchSelectionEventToChild(
        selectables[index],
        const SelectAllSelectionEvent(),
      );
    }
    currentSelectionStartIndex = selectedIndexes.first;
    currentSelectionEndIndex = selectedIndexes.last;
    layoutDidChange();
  }

  void clear() {
    _activeTargetRect = null;
    dispatchSelectionEvent(const ClearSelectionEvent());
  }

  void updateSelectionEdge({
    required bool isStart,
    required Offset globalPosition,
  }) {
    dispatchSelectionEvent(
      isStart
          ? SelectionEdgeUpdateEvent.forStart(globalPosition: globalPosition)
          : SelectionEdgeUpdateEvent.forEnd(globalPosition: globalPosition),
    );
  }

  bool containsGlobalPosition(Offset globalPosition) {
    for (final rect in value.selectionRects) {
      final globalRect = MatrixUtils.transformRect(getTransformTo(null), rect);
      if (globalRect.inflate(4).contains(globalPosition)) return true;
    }
    return false;
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    final targetRect = _activeTargetRect;
    if (targetRect == null) return;
    if (_selectableIntersectsGlobalRect(selectable, targetRect)) {
      dispatchSelectionEventToChild(
          selectable, const SelectAllSelectionEvent());
    } else {
      dispatchSelectionEventToChild(selectable, const ClearSelectionEvent());
    }
  }

  bool _selectableIntersectsGlobalRect(Selectable selectable, Rect globalRect) {
    for (final box in selectable.boundingBoxes) {
      final selectableRect =
          MatrixUtils.transformRect(selectable.getTransformTo(null), box);
      if (selectableRect.inflate(1).overlaps(globalRect)) return true;
      if (globalRect.contains(selectableRect.center)) return true;
    }
    return false;
  }
}

class _MarkdownSelectionHandlesOverlay extends StatelessWidget {
  final _MarkdownSelectionDelegate delegate;
  final Color color;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _MarkdownSelectionHandlesOverlay({
    Key? key,
    required this.delegate,
    required this.color,
    required this.onDragStart,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final start = delegate.globalStartPoint;
    final end = delegate.globalEndPoint;
    if (start == null || end == null) return const SizedBox.shrink();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return const SizedBox.shrink();
    final startLocal = overlay.globalToLocal(start);
    final endLocal = overlay.globalToLocal(end);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            _MarkdownSelectionHandle(
              position: startLocal,
              color: color,
              isStart: true,
              onDragStart: onDragStart,
              onDragUpdate: (globalPosition) {
                delegate.updateSelectionEdge(
                  isStart: true,
                  globalPosition: globalPosition,
                );
              },
              onDragEnd: onDragEnd,
            ),
            _MarkdownSelectionHandle(
              position: endLocal,
              color: color,
              isStart: false,
              onDragStart: onDragStart,
              onDragUpdate: (globalPosition) {
                delegate.updateSelectionEdge(
                  isStart: false,
                  globalPosition: globalPosition,
                );
              },
              onDragEnd: onDragEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownSelectionHandle extends StatelessWidget {
  final Offset position;
  final Color color;
  final bool isStart;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  const _MarkdownSelectionHandle({
    Key? key,
    required this.position,
    required this.color,
    required this.isStart,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const touchExtent = 44.0;
    const knobSize = 12.0;
    final dx = position.dx - touchExtent / 2;
    final dy = position.dy - (isStart ? touchExtent - knobSize : 0);
    return Positioned(
      key: ValueKey(
        isStart
            ? 'markdown-selection-start-handle'
            : 'markdown-selection-end-handle',
      ),
      left: dx,
      top: dy,
      width: touchExtent,
      height: touchExtent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (details) => onDragUpdate(details.globalPosition),
        onPanEnd: (_) => onDragEnd(),
        onPanCancel: onDragEnd,
        child: CustomPaint(
          painter: _MarkdownSelectionHandlePainter(
            color: color,
            isStart: isStart,
          ),
        ),
      ),
    );
  }
}

class _MarkdownSelectionHandlePainter extends CustomPainter {
  final Color color;
  final bool isStart;

  const _MarkdownSelectionHandlePainter({
    required this.color,
    required this.isStart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerX = size.width / 2;
    final lineTop = isStart ? 0.0 : 4.0;
    final lineBottom = isStart ? size.height - 4.0 : size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(centerX - 1, lineTop, centerX + 1, lineBottom),
        const Radius.circular(1),
      ),
      paint,
    );
    final knobCenter = Offset(centerX, isStart ? 6 : size.height - 6);
    canvas.drawCircle(knobCenter, 6, paint);
  }

  @override
  bool shouldRepaint(_MarkdownSelectionHandlePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isStart != isStart;
  }
}

class _MarkdownSelectionMenuOverlay extends StatelessWidget {
  final Offset globalPosition;
  final Widget child;

  const _MarkdownSelectionMenuOverlay({
    Key? key,
    required this.globalPosition,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const estimatedWidth = 220.0;
            const verticalOffset = 56.0;
            final maxLeft = (constraints.maxWidth - estimatedWidth)
                .clamp(0.0, constraints.maxWidth)
                .toDouble();
            final left = (globalPosition.dx - estimatedWidth / 2)
                .clamp(0.0, maxLeft)
                .toDouble();
            final maxTop = constraints.maxHeight - 64.0;
            final clampedMaxTop = maxTop < 8.0 ? 8.0 : maxTop;
            final top = (globalPosition.dy - verticalOffset)
                .clamp(8.0, clampedMaxTop)
                .toDouble();
            return Stack(
              children: [
                Positioned(left: left, top: top, child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DefaultMarkdownSelectionMenu extends StatelessWidget {
  final MarkdownSelectionMenuContext context;

  const _DefaultMarkdownSelectionMenu({
    Key? key,
    required this.context,
  }) : super(key: key);

  @override
  Widget build(BuildContext buildContext) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: context.allActions
            .map(
              (action) => TextButton.icon(
                onPressed: () => action.onPressed(context),
                icon: action.icon ?? const SizedBox.shrink(),
                label: Text(action.label),
              ),
            )
            .toList(),
      ),
    );
  }
}
