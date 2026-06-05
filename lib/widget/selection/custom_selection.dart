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
  final Map<String, _MarkdownSelectionDelegate> _selectionUnits =
      <String, _MarkdownSelectionDelegate>{};
  final Map<String, _MarkdownSelectionTargetWidgetState> _selectionUnitStates =
      <String, _MarkdownSelectionTargetWidgetState>{};
  OverlayEntry? _menuEntry;
  OverlayEntry? _handlesEntry;
  MarkdownSelectionTarget? _selectedTarget;
  _MarkdownSelectionDelegate? _activeSelectionDelegate;
  String? _selectedTextOverride;
  Rect? _selectedRect;
  Offset? _handleDragAnchor;
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
    final delegate = _selectionUnits[target.id];
    if (delegate == null) {
      clearSelection();
      return;
    }
    _selectionDelegate.clear();
    _clearUnitSelections(exceptTargetId: target.id);
    _selectedTarget = target;
    _activeSelectionDelegate = delegate;
    _selectedTextOverride = target.plainText;
    delegate.selectAllContent();
    _selectedRect = delegate.selectedGlobalRect ?? targetRect;
    _showHandles();
    _showSelectedMenu(target, _selectedRect!);
    setState(() {});
  }

  void clearSelection() {
    _selectedTarget = null;
    _activeSelectionDelegate = null;
    _selectedTextOverride = null;
    _selectedRect = null;
    _removeMenu();
    _removeHandles();
    _selectionDelegate.clear();
    _clearUnitSelections();
    if (mounted) setState(() {});
  }

  void handleTap(Offset globalPosition) {
    final selectedTarget = _selectedTarget;
    if (selectedTarget == null) return;
    final delegate = _activeSelectionDelegate ?? _selectionDelegate;
    if (delegate.containsGlobalPosition(globalPosition)) {
      final rect = delegate.selectedGlobalRect ?? _selectedRect;
      if (rect != null) _showSelectedMenu(selectedTarget, rect);
    } else {
      clearSelection();
    }
  }

  bool isSelected(String targetId) => _selectedTarget?.id == targetId;

  void _showSelectedMenu(MarkdownSelectionTarget target, Rect targetRect) {
    final menuPosition = Offset(targetRect.center.dx, targetRect.top);
    final selectedText = _selectedTextOverride ??
        _activeSelectionDelegate?.selectedPlainText ??
        _selectionDelegate.selectedPlainText ??
        target.plainText;
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
    final delegate = _currentSelectionDelegate;
    final rect = delegate.selectedGlobalRect;
    _selectedRect = rect ?? _selectedRect;
    if (_selectedTarget == null || !delegate.hasSelection) {
      _removeHandles();
      return;
    }
    _showHandles();
  }

  _MarkdownSelectionDelegate get _currentSelectionDelegate =>
      _activeSelectionDelegate ?? _selectionDelegate;

  void _showHandles() {
    final delegate = _currentSelectionDelegate;
    if (!delegate.hasVisibleEndpoints) {
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
          delegate: () => _currentSelectionDelegate,
          color: widget.config.handleColor,
          onDragStart: _handleSelectionHandleDragStart,
          onDragUpdate: _handleSelectionHandleDragUpdate,
          onDragEnd: () {
            final target = _selectedTarget;
            final rect = _currentSelectionDelegate.selectedGlobalRect;
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
      final delegate = _currentSelectionDelegate;
      if (_selectedTarget != null && delegate.hasSelection) {
        _showHandles();
      }
    });
  }

  void registerSelectionUnit(
    String targetId,
    _MarkdownSelectionDelegate delegate,
    _MarkdownSelectionTargetWidgetState state,
  ) {
    final existingDelegate = _selectionUnits[targetId];
    if (existingDelegate == delegate) return;
    existingDelegate?.removeListener(_handleSelectionGeometryChanged);
    _selectionUnits[targetId] = delegate;
    _selectionUnitStates[targetId] = state;
    delegate.addListener(_handleSelectionGeometryChanged);
    _restoreSelectedUnitIfNeeded(targetId, delegate, state);
  }

  void unregisterSelectionUnit(
    String targetId,
    _MarkdownSelectionDelegate delegate,
  ) {
    if (_selectionUnits[targetId] != delegate) return;
    delegate.removeListener(_handleSelectionGeometryChanged);
    _selectionUnits.remove(targetId);
    _selectionUnitStates.remove(targetId);
    if (_activeSelectionDelegate == delegate) {
      _activeSelectionDelegate = null;
      _removeHandles();
      _removeMenu();
    }
  }

  void _restoreSelectedUnitIfNeeded(
    String targetId,
    _MarkdownSelectionDelegate delegate,
    _MarkdownSelectionTargetWidgetState state,
  ) {
    final selectedTarget = _selectedTarget;
    if (selectedTarget == null || selectedTarget.id != targetId) return;
    _selectedTarget = state.widget.target;
    _activeSelectionDelegate = delegate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedTarget?.id != targetId) return;
      if (_selectionUnits[targetId] != delegate) return;
      delegate.selectAllContent();
      _selectedRect =
          delegate.selectedGlobalRect ?? state.globalRect ?? _selectedRect;
      _showHandles();
      if (mounted) setState(() {});
    });
  }

  void _clearUnitSelections({String? exceptTargetId}) {
    for (final entry in _selectionUnits.entries) {
      if (entry.key == exceptTargetId) continue;
      entry.value.clear();
    }
  }

  void _handleSelectionHandleDragStart() {
    _ignoreNextPointerUpAfterHandleDrag = true;
    _selectedTextOverride = null;
    _handleDragAnchor = null;
    _removeMenu();
  }

  void _handleSelectionHandleDragUpdate(bool isStart, Offset globalPosition) {
    if (_activeSelectionDelegate == _selectionDelegate &&
        _handleDragAnchor != null) {
      _selectUnitRangeBetweenGlobalPoints(
        _handleDragAnchor!,
        globalPosition,
      );
      return;
    }

    final activeDelegate = _activeSelectionDelegate;
    if (activeDelegate != null &&
        activeDelegate != _selectionDelegate &&
        _dragPositionLeftSelectedUnit(globalPosition)) {
      final anchor = isStart
          ? activeDelegate.globalEndPoint
          : activeDelegate.globalStartPoint;
      if (anchor != null) {
        _selectUnitRangeBetweenGlobalPoints(
          anchor,
          globalPosition,
        );
        if (_selectionDelegate.hasSelection) {
          _activeSelectionDelegate = _selectionDelegate;
          _handleDragAnchor = anchor;
          _selectedRect =
              _selectionDelegate.selectedGlobalRect ?? _selectedRect;
          _handlesEntry?.markNeedsBuild();
          return;
        }
      }
    }
    _currentSelectionDelegate.updateSelectionEdge(
      isStart: isStart,
      globalPosition: globalPosition,
    );
  }

  void _selectUnitRangeBetweenGlobalPoints(Offset anchor, Offset extent) {
    final units = _selectionUnitStates.values.where((state) {
      final target = state.widget.target;
      return target.canSelectText && target.hasText && state.globalRect != null;
    }).toList(growable: false)
      ..sort((a, b) {
        final rectA = a.globalRect!;
        final rectB = b.globalRect!;
        final vertical = rectA.top.compareTo(rectB.top);
        return vertical != 0 ? vertical : rectA.left.compareTo(rectB.left);
      });
    if (units.isEmpty) return;
    final anchorIndex = _nearestUnitIndex(units, anchor);
    final extentIndex = _nearestUnitIndex(units, extent);
    final startIndex = anchorIndex < extentIndex ? anchorIndex : extentIndex;
    final endIndex = anchorIndex < extentIndex ? extentIndex : anchorIndex;
    final selectedDelegates = <_MarkdownSelectionDelegate>[];
    for (var index = 0; index < units.length; index += 1) {
      final delegate = units[index].selectionDelegate;
      if (index >= startIndex && index <= endIndex) {
        delegate.selectAllContent();
        selectedDelegates.add(delegate);
      } else {
        delegate.clear();
      }
    }
    _selectionDelegate.setManualSelectionDelegates(selectedDelegates);
  }

  int _nearestUnitIndex(
    List<_MarkdownSelectionTargetWidgetState> units,
    Offset globalPosition,
  ) {
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < units.length; index += 1) {
      final rect = units[index].globalRect!;
      if (rect.inflate(8).contains(globalPosition)) return index;
      final distance = (rect.center - globalPosition).distanceSquared;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    return closestIndex;
  }

  bool _dragPositionLeftSelectedUnit(Offset globalPosition) {
    final selectedTargetId = _selectedTarget?.id;
    if (selectedTargetId == null) return false;
    final rect = _selectionUnitStates[selectedTargetId]?.globalRect;
    if (rect == null) return false;
    return !rect.inflate(8).contains(globalPosition);
  }
}

class MarkdownSelectionTargetWidget extends StatefulWidget {
  final MarkdownSelectionTarget target;
  final Widget child;

  const MarkdownSelectionTargetWidget({
    Key? key,
    required this.target,
    required this.child,
  }) : super(key: key);

  @override
  State<MarkdownSelectionTargetWidget> createState() =>
      _MarkdownSelectionTargetWidgetState();
}

class _MarkdownSelectionTargetWidgetState
    extends State<MarkdownSelectionTargetWidget> {
  final GlobalKey _targetKey = GlobalKey();
  final _MarkdownSelectionDelegate _selectionDelegate =
      _MarkdownSelectionDelegate();
  _MarkdownCustomSelectionAreaState? _controller;
  String? _registeredTargetId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(MarkdownSelectionTargetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id) {
      _unregister();
      _syncRegistration();
    }
  }

  @override
  void dispose() {
    _unregister();
    _selectionDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _MarkdownCustomSelectionScope.maybeOf(context);
    if (controller == null) return widget.child;
    _syncRegistration(controller);
    return GestureDetector(
      key: _targetKey,
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        final rect = _globalRectOfTarget();
        controller.showInitialMenu(widget.target, details.globalPosition, rect);
      },
      child: SelectionContainer(
        delegate: _selectionDelegate,
        child: widget.child,
      ),
    );
  }

  void _syncRegistration([_MarkdownCustomSelectionAreaState? controller]) {
    final nextController =
        controller ?? _MarkdownCustomSelectionScope.maybeOf(context);
    if (_controller == nextController &&
        _registeredTargetId == widget.target.id) {
      return;
    }
    _unregister();
    _controller = nextController;
    _registeredTargetId = widget.target.id;
    nextController?.registerSelectionUnit(
      widget.target.id,
      _selectionDelegate,
      this,
    );
  }

  void _unregister() {
    final controller = _controller;
    final targetId = _registeredTargetId;
    if (controller != null && targetId != null) {
      controller.unregisterSelectionUnit(targetId, _selectionDelegate);
    }
    _controller = null;
    _registeredTargetId = null;
  }

  Rect _globalRectOfTarget() {
    final renderObject = _targetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      return topLeft & renderObject.size;
    }
    return Rect.zero;
  }

  Rect? get globalRect {
    final renderObject = _targetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      return topLeft & renderObject.size;
    }
    return null;
  }

  _MarkdownSelectionDelegate get selectionDelegate => _selectionDelegate;
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
  List<_MarkdownSelectionDelegate>? _manualSelectionDelegates;
  bool _restoreAllContentOnChildUpdate = false;

  bool get hasSelection {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      return manualDelegates.any((delegate) => delegate.hasSelection);
    }
    return value.hasSelection;
  }

  bool get hasVisibleEndpoints {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      return globalStartPoint != null && globalEndPoint != null;
    }
    return globalStartPoint != null && globalEndPoint != null;
  }

  String? get selectedPlainText {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      final text = manualDelegates
          .map((delegate) => delegate.selectedPlainText)
          .whereType<String>()
          .join();
      return text.isEmpty ? null : text;
    }
    return getSelectedContent()?.plainText;
  }

  Offset? get globalStartPoint {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      for (final delegate in manualDelegates) {
        final point = delegate.globalStartPoint;
        if (point != null) return point;
      }
      return null;
    }
    final point = value.startSelectionPoint;
    if (point != null) {
      return MatrixUtils.transformPoint(
          getTransformTo(null), point.localPosition);
    }
    final rects = _globalSelectionRects;
    if (rects.isEmpty) return null;
    final rect = rects.first;
    return Offset(rect.left, rect.top);
  }

  Offset? get globalEndPoint {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      for (final delegate in manualDelegates.reversed) {
        final point = delegate.globalEndPoint;
        if (point != null) return point;
      }
      return null;
    }
    final point = value.endSelectionPoint;
    if (point != null) {
      return MatrixUtils.transformPoint(
          getTransformTo(null), point.localPosition);
    }
    final rects = _globalSelectionRects;
    if (rects.isEmpty) return null;
    final rect = rects.last;
    return Offset(rect.right, rect.bottom);
  }

  Rect? get selectedGlobalRect {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      Rect? result;
      for (final delegate in manualDelegates) {
        final rect = delegate.selectedGlobalRect;
        if (rect == null) continue;
        result = result == null ? rect : result.expandToInclude(rect);
      }
      return result;
    }
    Rect? result;
    for (final globalRect in _globalSelectionRects) {
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
    _restoreAllContentOnChildUpdate = false;
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

  void selectAllContent() {
    _activeTargetRect = null;
    _manualSelectionDelegates = null;
    _restoreAllContentOnChildUpdate = true;
    _selectAllVisibleChildren();
  }

  void setManualSelectionDelegates(
    List<_MarkdownSelectionDelegate> delegates,
  ) {
    _activeTargetRect = null;
    _manualSelectionDelegates = delegates;
    _restoreAllContentOnChildUpdate = false;
    notifyListeners();
  }

  void selectRangeBetweenGlobalPoints(Offset anchor, Offset extent) {
    _activeTargetRect = null;
    _restoreAllContentOnChildUpdate = false;
    if (selectables.isEmpty) return;
    selectables.sort(compareOrder);
    final anchorIndex = _indexAtGlobalPosition(anchor);
    final extentIndex = _indexAtGlobalPosition(extent);
    if (anchorIndex == null || extentIndex == null) return;
    final startIndex = anchorIndex < extentIndex ? anchorIndex : extentIndex;
    final endIndex = anchorIndex < extentIndex ? extentIndex : anchorIndex;
    for (var index = 0; index < selectables.length; index += 1) {
      dispatchSelectionEventToChild(
        selectables[index],
        index >= startIndex && index <= endIndex
            ? const SelectAllSelectionEvent()
            : const ClearSelectionEvent(),
      );
    }
    currentSelectionStartIndex = startIndex;
    currentSelectionEndIndex = endIndex;
    layoutDidChange();
  }

  void clear() {
    _activeTargetRect = null;
    _manualSelectionDelegates = null;
    _restoreAllContentOnChildUpdate = false;
    dispatchSelectionEvent(const ClearSelectionEvent());
  }

  void updateSelectionEdge({
    required bool isStart,
    required Offset globalPosition,
  }) {
    _restoreAllContentOnChildUpdate = false;
    dispatchSelectionEvent(
      isStart
          ? SelectionEdgeUpdateEvent.forStart(globalPosition: globalPosition)
          : SelectionEdgeUpdateEvent.forEnd(globalPosition: globalPosition),
    );
  }

  bool containsGlobalPosition(Offset globalPosition) {
    final manualDelegates = _manualSelectionDelegates;
    if (manualDelegates != null) {
      return manualDelegates
          .any((delegate) => delegate.containsGlobalPosition(globalPosition));
    }
    for (final globalRect in _globalSelectionRects) {
      if (globalRect.inflate(4).contains(globalPosition)) return true;
    }
    return false;
  }

  List<Rect> get _globalSelectionRects {
    final transform = getTransformTo(null);
    return value.selectionRects
        .map((rect) => MatrixUtils.transformRect(transform, rect))
        .toList(growable: false)
      ..sort((a, b) {
        final vertical = a.top.compareTo(b.top);
        return vertical != 0 ? vertical : a.left.compareTo(b.left);
      });
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    if (_restoreAllContentOnChildUpdate) {
      _selectAllVisibleChildren();
      return;
    }
    final targetRect = _activeTargetRect;
    if (targetRect == null) return;
    if (_selectableIntersectsGlobalRect(selectable, targetRect)) {
      dispatchSelectionEventToChild(
          selectable, const SelectAllSelectionEvent());
    } else {
      dispatchSelectionEventToChild(selectable, const ClearSelectionEvent());
    }
  }

  void _selectAllVisibleChildren() {
    if (selectables.isEmpty) {
      currentSelectionStartIndex = -1;
      currentSelectionEndIndex = -1;
      layoutDidChange();
      return;
    }
    selectables.sort(compareOrder);
    for (final selectable in selectables) {
      dispatchSelectionEventToChild(
        selectable,
        const SelectAllSelectionEvent(),
      );
    }
    currentSelectionStartIndex = 0;
    currentSelectionEndIndex = selectables.length - 1;
    layoutDidChange();
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

  int? _indexAtGlobalPosition(Offset globalPosition) {
    if (selectables.isEmpty) return null;
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < selectables.length; index += 1) {
      final rect = _selectableGlobalRect(selectables[index]);
      if (rect == null) continue;
      if (rect.inflate(8).contains(globalPosition)) return index;
      final distance = (rect.center - globalPosition).distanceSquared;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    return closestIndex;
  }

  Rect? _selectableGlobalRect(Selectable selectable) {
    Rect? result;
    for (final box in selectable.boundingBoxes) {
      final rect =
          MatrixUtils.transformRect(selectable.getTransformTo(null), box);
      result = result == null ? rect : result.expandToInclude(rect);
    }
    return result;
  }
}

class _MarkdownSelectionHandlesOverlay extends StatelessWidget {
  final _MarkdownSelectionDelegate Function() delegate;
  final Color color;
  final VoidCallback onDragStart;
  final void Function(bool isStart, Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;

  const _MarkdownSelectionHandlesOverlay({
    Key? key,
    required this.delegate,
    required this.color,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentDelegate = delegate();
    final start = currentDelegate.globalStartPoint;
    final end = currentDelegate.globalEndPoint;
    if (start == null || end == null) return const SizedBox.shrink();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return const SizedBox.shrink();
    final startLocal = overlay.globalToLocal(start);
    final endLocal = overlay.globalToLocal(end);
    const touchExtent = 44.0;
    final viewportRect = Offset.zero & overlay.size;
    final interactiveRect = viewportRect.inflate(touchExtent);
    final children = <Widget>[];
    if (interactiveRect.contains(startLocal)) {
      children.add(
        _MarkdownSelectionHandle(
          position: startLocal,
          color: color,
          isStart: true,
          onDragStart: onDragStart,
          onDragUpdate: (globalPosition) => onDragUpdate(true, globalPosition),
          onDragEnd: onDragEnd,
        ),
      );
    }
    if (interactiveRect.contains(endLocal)) {
      children.add(
        _MarkdownSelectionHandle(
          position: endLocal,
          color: color,
          isStart: false,
          onDragStart: onDragStart,
          onDragUpdate: (globalPosition) => onDragUpdate(false, globalPosition),
          onDragEnd: onDragEnd,
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: Stack(children: children),
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
