import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Navigation item for the bottom bar.
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Glass-morphism bottom navigation bar with a center camera FAB.
///
/// Supports 4 or 5 [items] arranged around a center FAB.
/// For 4 items: left-1 | left-2 | FAB | right-1 | right-2.
/// For 5 items: left-1 | left-2 | FAB | right-1 | right-2 | right-3 (compact).
/// Tapping the FAB triggers [onCameraTap]. Long-pressing reveals
/// a floating menu with [onGalleryTap] and [onTextPostTap] options.
class LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  final Map<int, int> badges;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onTextPostTap;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.badges = const {},
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onTextPostTap,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _menuOpen = false;
  OverlayEntry? _menuOverlay;

  static const double _fabSize = 58.0;
  static const double _barHeight = 68.0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _removeMenu();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Menu management ──────────────────────────────────────────────────

  void _removeMenu() {
    _menuOverlay?.remove();
    _menuOverlay?.dispose();
    _menuOverlay = null;
  }

  void _onFabTap() {
    if (_menuOpen) {
      _closeMenu();
      return;
    }
    HapticFeedback.lightImpact();
    widget.onCameraTap();
  }

  void _onFabLongPress() {
    HapticFeedback.mediumImpact();
    setState(() => _menuOpen = true);
    _showMenuOverlay();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
    _removeMenu();
  }

  void _showMenuOverlay() {
    _removeMenu();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final fabCenterX = pos.dx + box.size.width / 2;
    final fabCenterY = pos.dy + _fabSize / 2 + 6;

    _menuOverlay = OverlayEntry(
      builder: (_) => _CameraMenuOverlay(
        fabCenter: Offset(fabCenterX, fabCenterY),
        onDismiss: _closeMenu,
        onGallery: () {
          _closeMenu();
          widget.onGalleryTap();
        },
        onTextPost: () {
          _closeMenu();
          widget.onTextPostTap();
        },
      ),
    );
    Overlay.of(context).insert(_menuOverlay!);
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safePad = MediaQuery.of(context).padding.bottom;
    final totalBarH = _barHeight + safePad;

    return SizedBox(
      height: totalBarH + _fabSize / 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass bar
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: _glassBar(scheme, isDark, safePad, totalBarH),
          ),
          // Cradle behind FAB
          Positioned(
            bottom: totalBarH - 6,
            left: 0,
            right: 0,
            child: Center(child: _cradle(isDark, scheme)),
          ),
          // Camera FAB
          Positioned(
            bottom: totalBarH - _fabSize / 2 - 2,
            left: 0,
            right: 0,
            child: Center(child: _fab(scheme, isDark)),
          ),
        ],
      ),
    );
  }

  // ─── Glass bar ────────────────────────────────────────────────────────

  Widget _glassBar(ColorScheme scheme, bool isDark, double safePad, double h) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: h,
          padding: EdgeInsets.only(bottom: safePad),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xDD0B0D21)
                : Colors.white.withAlpha(230),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? scheme.primary.withAlpha(35)
                  : Colors.grey.withAlpha(50),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? scheme.primary : Colors.black).withAlpha(12),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < 2; i++) _navItem(i, scheme, isDark),
              SizedBox(width: _fabSize + 28),
              for (var i = 2; i < widget.items.length; i++)
                _navItem(i, scheme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Cradle ───────────────────────────────────────────────────────────

  Widget _cradle(bool isDark, ColorScheme scheme) {
    return Container(
      width: _fabSize + 26,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xDD0B0D21) : Colors.white.withAlpha(230),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular((_fabSize + 26) / 2),
        ),
      ),
    );
  }

  // ─── Nav item ─────────────────────────────────────────────────────────

  Widget _navItem(int i, ColorScheme scheme, bool isDark) {
    final active = i == widget.currentIndex;
    final item = widget.items[i];
    final badge = widget.badges[i] ?? 0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_menuOpen) _closeMenu();
          HapticFeedback.selectionClick();
          widget.onTap(i);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: active ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    color: active
                        ? scheme.primary
                        : (isDark
                              ? Colors.white.withAlpha(100)
                              : Colors.grey.withAlpha(160)),
                    size: 24,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: _badge(badge, scheme, isDark),
                  ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(top: 4),
              width: active ? 5 : 0,
              height: active ? 5 : 0,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: scheme.primary.withAlpha(100),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(int count, ColorScheme scheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.error,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF0B0D21) : Colors.white,
          width: 1.5,
        ),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────

  Widget _fab(ColorScheme scheme, bool isDark) {
    return GestureDetector(
      onTap: _onFabTap,
      onLongPress: _onFabLongPress,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) {
          final pulse = Tween<double>(begin: 1.0, end: 1.06).evaluate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
          );
          return AnimatedScale(
            scale: _menuOpen ? 0.88 : pulse,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
        child: Container(
          width: _fabSize,
          height: _fabSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                Color.lerp(scheme.primary, scheme.secondary, 0.3)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withAlpha(isDark ? 90 : 50),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: scheme.primary.withAlpha(30),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: RotationTransition(
                turns: Tween(begin: 0.5, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: Icon(
              _menuOpen ? Icons.close_rounded : Icons.camera_alt_rounded,
              key: ValueKey(_menuOpen),
              color: scheme.onPrimary,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

// Camera menu overlay (displayed on FAB long-press)

class _CameraMenuOverlay extends StatefulWidget {
  final Offset fabCenter;
  final VoidCallback onDismiss;
  final VoidCallback onGallery;
  final VoidCallback onTextPost;

  const _CameraMenuOverlay({
    required this.fabCenter,
    required this.onDismiss,
    required this.onGallery,
    required this.onTextPost,
  });

  @override
  State<_CameraMenuOverlay> createState() => _CameraMenuOverlayState();
}

class _CameraMenuOverlayState extends State<_CameraMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _ctrl
        .reverse()
        .whenComplete(() {
          if (mounted) widget.onDismiss();
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          final fade = Curves.easeOut.transform(t);

          return GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.translucent,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  // Dim scrim
                  Container(color: Colors.black.withAlpha((fade * 90).round())),

                  // Gallery (left-above FAB)
                  _menuItem(
                    offset: const Offset(-65, -85),
                    index: 0,
                    t: t,
                    fade: fade,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: widget.onGallery,
                    scheme: scheme,
                    isDark: isDark,
                  ),

                  // Text (right-above FAB)
                  _menuItem(
                    offset: const Offset(65, -85),
                    index: 1,
                    t: t,
                    fade: fade,
                    icon: Icons.text_fields_rounded,
                    label: 'Text',
                    onTap: widget.onTextPost,
                    scheme: scheme,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _menuItem({
    required Offset offset,
    required int index,
    required double t,
    required double fade,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme scheme,
    required bool isDark,
  }) {
    const size = 54.0;

    // Staggered spring per item
    final interval = Interval(
      index * 0.1,
      0.7 + index * 0.1,
      curve: Curves.easeOutBack,
    );
    final spring = interval.transform(t.clamp(0.0, 1.0));

    final x = widget.fabCenter.dx - size / 2 + offset.dx * spring;
    final y = widget.fabCenter.dy - size / 2 + offset.dy * spring;

    return Positioned(
      left: x,
      top: y,
      child: Transform.scale(
        scale: spring.clamp(0.0, 1.3),
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? scheme.surface.withAlpha(240)
                        : Colors.white,
                    border: Border.all(
                      color: scheme.primary.withAlpha(80),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withAlpha(40),
                        blurRadius: 16,
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: scheme.primary, size: 24),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withAlpha(
                      180,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
