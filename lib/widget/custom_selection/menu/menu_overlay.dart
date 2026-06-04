import 'package:flutter/material.dart';
import '../../../config/custom_selection_config.dart';
import '../element_context.dart';
import 'menu_builder.dart';

/// Menu overlay widget that displays above selection
class MenuOverlay extends StatefulWidget {
  /// Position to display menu
  final Offset position;

  /// Custom selection configuration
  final CustomSelectionConfig config;

  /// Element context
  final ElementContext elementContext;

  /// Whether this is the initial menu (vs copy menu)
  final bool isInitialMenu;

  /// Callback for "Select Text" action
  final VoidCallback? onSelectText;

  /// Callback for "Copy" action
  final VoidCallback? onCopy;

  /// Callback when menu should be dismissed
  final VoidCallback onDismiss;

  const MenuOverlay({
    Key? key,
    required this.position,
    required this.config,
    required this.elementContext,
    required this.isInitialMenu,
    this.onSelectText,
    this.onCopy,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.config.animationConfig.enterDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.config.animationConfig.enterCurve,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.config.animationConfig.enterCurve,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.config.animationConfig.enterCurve,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate adjusted position to keep menu on screen
    final screenSize = MediaQuery.of(context).size;
    const menuSize = Size(200, 50); // Approximate menu size

    double left = widget.position.dx - menuSize.width / 2;
    double top = widget.position.dy - menuSize.height - 10;

    // Adjust for screen boundaries
    if (left < 10) left = 10;
    if (left + menuSize.width > screenSize.width - 10) {
      left = screenSize.width - menuSize.width - 10;
    }
    if (top < 10) {
      top = widget.position.dy + 10; // Show below if not enough space above
    }

    return Stack(
      children: [
        // Tap outside the menu bubble dismisses it.
        // HitTestBehavior.deferToChild: the fill layer only responds where no
        // child (menu bubble) is present, so tapping on a menu item reaches
        // the item's InkWell first and the fill layer never fires.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.deferToChild,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu - Positioned must be a direct child of Stack
        Positioned(
          left: left,
          top: top,
          child: _buildAnimatedMenu(),
        ),
      ],
    );
  }

  Widget _buildAnimatedMenu() {
    final menuWidget = _buildMenu();

    switch (widget.config.animationConfig.type) {
      case MenuAnimationType.fade:
        return FadeTransition(
          opacity: _fadeAnimation,
          child: menuWidget,
        );
      case MenuAnimationType.scale:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: menuWidget,
        );
      case MenuAnimationType.fadeScale:
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: menuWidget,
          ),
        );
      case MenuAnimationType.slideFromTop:
      case MenuAnimationType.slideFromBottom:
      case MenuAnimationType.slideFromLeft:
      case MenuAnimationType.slideFromRight:
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: menuWidget,
          ),
        );
    }
  }

  Widget _buildMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: widget.config.menuStyle.backgroundColor ?? Colors.white,
          borderRadius:
              widget.config.menuStyle.borderRadius ?? BorderRadius.circular(8),
          border: widget.config.menuStyle.border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: widget.config.menuStyle.elevation ?? 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: widget.config.menuStyle.padding ??
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: MenuBuilder.buildMenu(
          context: context,
          config: widget.config,
          elementContext: widget.elementContext,
          isInitialMenu: widget.isInitialMenu,
          onSelectText: widget.onSelectText,
          onCopy: widget.onCopy,
          onDismiss: widget.onDismiss,
        ),
      ),
    );
  }
}
