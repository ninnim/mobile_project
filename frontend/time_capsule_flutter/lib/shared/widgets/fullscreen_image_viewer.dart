import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen image viewer with Hero animation, pinch-to-zoom, and swipe-to-dismiss.
class FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  /// Navigate to viewer with a Hero transition.
  static void open(
    BuildContext context, {
    required String imageUrl,
    required String heroTag,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) =>
            FullscreenImageViewer(imageUrl: imageUrl, heroTag: heroTag),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  final _transformCtrl = TransformationController();
  late final AnimationController _opacityCtrl;
  double _dragOffset = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _opacityCtrl = AnimationController(
      value: 1.0,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformCtrl.dispose();
    _opacityCtrl.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _dragOffset += d.delta.dy;
    });
    // Fade scrim as user drags
    final progress = (_dragOffset.abs() / 300).clamp(0.0, 1.0);
    _opacityCtrl.value = 1.0 - progress * 0.6;
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_dragOffset.abs() > 100 || d.velocity.pixelsPerSecond.dy.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _dragging = false;
      });
      _opacityCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityCtrl,
      builder: (_, __) => Scaffold(
        backgroundColor: Colors.black.withAlpha(
          (_opacityCtrl.value * 240).round(),
        ),
        body: Stack(
          children: [
            // Zoomable + draggable image
            GestureDetector(
              onVerticalDragUpdate: _transformCtrl.value.isIdentity()
                  ? _onVerticalDragUpdate
                  : null,
              onVerticalDragEnd: _transformCtrl.value.isIdentity()
                  ? _onVerticalDragEnd
                  : null,
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(0, _dragOffset, 0),
                  child: Hero(
                    tag: widget.heroTag,
                    child: InteractiveViewer(
                      transformationController: _transformCtrl,
                      minScale: 0.5,
                      maxScale: 4.0,
                      clipBehavior: Clip.none,
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
