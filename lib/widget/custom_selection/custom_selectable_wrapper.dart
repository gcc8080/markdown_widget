import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/custom_selection_config.dart';
import 'element_context.dart';
import 'menu/menu_overlay.dart';

/// Wrapper widget that provides custom selection functionality for markdown elements
class CustomSelectableWrapper extends StatefulWidget {
  final Widget child;
  final TextSpan textSpan;
  final ElementContext elementContext;
  final CustomSelectionConfig config;
  final TextStyle? textStyle;
  final TextAlign textAlign;
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
  State<CustomSelectableWrapper> createState() =>
      _CustomSelectableWrapperState();
}

class _CustomSelectableWrapperState extends State<CustomSelectableWrapper>
    with WidgetsBindingObserver {
  bool _isSelectableMode = false;
  TextSelection? _currentSelection;
  bool _isDragging = false;
  bool _isScrolling = false;
  OverlayEntry? _menuOverlay;
  Offset? _longPressPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeMenu();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Reposition menu on device rotation or keyboard appearance
    if (_menuOverlay != null) {
      _removeMenu();
      if (_isSelectableMode && _currentSelection != null && !_isDragging) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCopyMenu();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for scroll notifications to hide/show menu
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _onScrollStart();
        } else if (notification is ScrollEndNotification) {
          _onScrollEnd();
        }
        return false; // don't absorb the notification
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: _isSelectableMode ? _buildSelectableMode() : _buildStaticMode(),
      ),
    );
  }

  Widget _buildStaticMode() {
    return GestureDetector(
      key: const ValueKey('static'),
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _handleLongPressStart,
      child: widget.child,
    );
  }

  Widget _buildSelectableMode() {
    return SelectableText.rich(
      widget.textSpan,
      key: const ValueKey('selectable'),
      style: widget.textStyle,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      onSelectionChanged: _handleSelectionChanged,
    );
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _longPressPosition = details.globalPosition;
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

  void _showCopyMenu() {
    if (!_isSelectableMode || _isDragging || _isScrolling) return;
    _removeMenu();

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
        onDismiss: _clearAll,
      ),
    );
    Overlay.of(context).insert(_menuOverlay!);
  }

  void _handleSelectText() {
    _removeMenu();
    setState(() => _isSelectableMode = true);

    // Select entire element content after mode switch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentSelection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.elementContext.plainText.length,
        );
      });
      _showCopyMenu();
    });
  }

  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    final wasDragging = _isDragging;
    _isDragging = cause == SelectionChangedCause.drag;
    setState(() => _currentSelection = selection);

    if (_isDragging && !wasDragging) {
      _removeMenu();
    } else if (!_isDragging && wasDragging) {
      if (selection.isValid && !selection.isCollapsed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isDragging) _showCopyMenu();
        });
      }
    }
  }

  Future<void> _handleCopy(String text) async {
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    _clearAll();
  }

  void _onScrollStart() {
    _isScrolling = true;
    _removeMenu(); // hide menu while scrolling, preserve selection
  }

  void _onScrollEnd() {
    _isScrolling = false;
    // Reshow menu if still in selectable mode with a valid selection
    if (_isSelectableMode &&
        _currentSelection != null &&
        _currentSelection!.isValid &&
        !_currentSelection!.isCollapsed) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_isDragging && !_isScrolling) _showCopyMenu();
      });
    }
  }

  void _removeMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  void _clearAll() {
    _removeMenu();
    setState(() {
      _isSelectableMode = false;
      _currentSelection = null;
      _isDragging = false;
    });
  }

  String _getSelectedText() {
    if (_currentSelection == null || !_currentSelection!.isValid) return '';
    final text = widget.elementContext.plainText;
    final start = _currentSelection!.start.clamp(0, text.length);
    final end = _currentSelection!.end.clamp(0, text.length);
    return start < end ? text.substring(start, end) : '';
  }
}
