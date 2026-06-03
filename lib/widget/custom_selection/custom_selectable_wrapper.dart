import 'package:flutter/material.dart';
import '../../config/custom_selection_config.dart';
import 'element_context.dart';
import 'menu/menu_overlay.dart';

/// Wrapper widget that provides custom selection functionality for markdown elements
class CustomSelectableWrapper extends StatefulWidget {
  /// The child widget to wrap
  final Widget child;

  /// The text span to render
  final InlineSpan textSpan;

  /// Element context information
  final ElementContext elementContext;

  /// Custom selection configuration
  final CustomSelectionConfig config;

  /// Text style for the content
  final TextStyle? textStyle;

  /// Text align
  final TextAlign textAlign;

  /// Text direction
  final TextDirection? textDirection;

  const CustomSelectableWrapper({
    Key? key,
    required this.child,
    required this.textSpan,
    required this.elementContext,
    required this.config,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.textDirection,
  }) : super(key: key);

  @override
  State<CustomSelectableWrapper> createState() => _CustomSelectableWrapperState();
}

class _CustomSelectableWrapperState extends State<CustomSelectableWrapper> {
  /// Current selection mode (static or selectable)
  bool _isSelectableMode = false;

  /// Current selection range
  TextSelection? _currentSelection;

  /// Whether user is currently dragging selection handles
  bool _isDragging = false;

  /// Overlay entry for menu
  OverlayEntry? _menuOverlay;

  /// Global position of long press
  Offset? _longPressPosition;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isSelectableMode
          ? _buildSelectableMode()
          : _buildStaticMode(),
    );
  }

  /// Build static mode (non-selectable with long press detection)
  Widget _buildStaticMode() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _handleLongPressStart,
      child: widget.child,
    );
  }

  /// Build selectable mode (with text selection)
  Widget _buildSelectableMode() {
    return SelectableText.rich(
      widget.textSpan,
      style: widget.textStyle,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      onSelectionChanged: _handleSelectionChanged,
    );
  }

  /// Handle long press start
  void _handleLongPressStart(LongPressStartDetails details) {
    _longPressPosition = details.globalPosition;
    _showInitialMenu(details.globalPosition);
  }

  /// Show initial menu with "Select Text" and other options
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
        onDismiss: _removeMenu,
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  /// Show copy menu after selection
  void _showCopyMenu() {
    if (_currentSelection == null || _isDragging) return;

    _removeMenu();

    // Calculate position above selection
    // For now, use approximate position
    final position = _longPressPosition ?? Offset.zero;

    _menuOverlay = OverlayEntry(
      builder: (context) => MenuOverlay(
        position: position,
        config: widget.config,
        elementContext: widget.elementContext.copyWith(
          selection: _currentSelection,
          selectedText: _getSelectedText(),
        ),
        isInitialMenu: false,
        onCopy: () => _handleCopy(_getSelectedText()),
        onDismiss: _removeMenu,
      ),
    );

    Overlay.of(context).insert(_menuOverlay!);
  }

  /// Handle "Select Text" action
  void _handleSelectText() {
    setState(() {
      _isSelectableMode = true;
      _removeMenu();
    });

    // Auto-select entire element content after mode switch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _currentSelection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.elementContext.plainText.length,
        );
      });
      _showCopyMenu();
    });
  }

  /// Handle selection changes
  void _handleSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    final wasDragging = _isDragging;
    _isDragging = cause == SelectionChangedCause.drag;

    setState(() {
      _currentSelection = selection;
    });

    // Hide menu while dragging
    if (_isDragging && !wasDragging) {
      _removeMenu();
    }

    // Show menu after drag ends
    if (!_isDragging && wasDragging && selection.isValid && !selection.isCollapsed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isDragging) {
          _showCopyMenu();
        }
      });
    }
  }

  /// Handle copy action
  void _handleCopy(String text) {
    // Copy to clipboard
    // Note: Actual clipboard implementation will be added later
    _removeMenu();

    // Clear selection and return to static mode
    setState(() {
      _isSelectableMode = false;
      _currentSelection = null;
    });
  }

  /// Get currently selected text
  String _getSelectedText() {
    if (_currentSelection == null || !_currentSelection!.isValid) {
      return '';
    }

    final text = widget.elementContext.plainText;
    return text.substring(
      _currentSelection!.baseOffset,
      _currentSelection!.extentOffset,
    );
  }

  /// Remove menu overlay
  void _removeMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }
}
