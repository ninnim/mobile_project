import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/network/dio_client.dart';

// ─── Wheel segment data (must match backend SpinController.Segments order) ───

class _Segment {
  final String label;
  final int points;
  final Color color;
  const _Segment(this.label, this.points, this.color);
}

const _segments = [
  _Segment('100 pts',  100, Color(0xFF00E5FF)),  // 0 cyan
  _Segment('Free\nSpin', 50, Color(0xFF7B2FBE)), // 1 purple
  _Segment('200 pts',  200, Color(0xFF00E676)),  // 2 green
  _Segment('No Luck',    0, Color(0xFFFF5252)),  // 3 red
  _Segment('150 pts',  150, Color(0xFFB388FF)),  // 4 lavender
  _Segment('25 pts',    25, Color(0xFFFFD740)),  // 5 gold
  _Segment('JACKPOT\n500!', 500, Color(0xFFFF4081)), // 6 pink
  _Segment('75 pts',    75, Color(0xFF40C4FF)),  // 7 light blue
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final AudioPlayer _audio;

  bool _spinning = false;
  final bool _canSpin = true;
  double _currentAngle = 0.0;   // radians, cumulative
  int? _newBalance;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _audio = AudioPlayer();
    _preloadAudio();
  }

  Future<void> _preloadAudio() async {
    try {
      await _audio.setAsset('assets/sounds/unlock.wav');
    } catch (_) {}
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── Spin logic ──────────────────────────────────────────────────────────────

  Future<void> _spin() async {
    if (_spinning || !_canSpin) return;
    setState(() => _spinning = true);

    // 1. Call backend first — get the winning segment index
    Map<String, dynamic> result;
    try {
      final res = await dioClient.post('/spin');
      result = res.data as Map<String, dynamic>;
    } catch (e) {
      if (mounted) {
        setState(() => _spinning = false);
        final msg = (e is Exception) ? e.toString() : 'Spin failed';
        final data = (e as dynamic).response?.data;
        final errMsg = (data is Map && data['error'] != null)
            ? data['error'] as String
            : msg;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errMsg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
      return;
    }

    final segmentIndex = result['segmentIndex'] as int;
    final pointsWon    = result['pointsWon'] as int;
    final prizeName    = result['prizeName'] as String;
    final newBalance   = result['newBalance'] as int;

    // 2. Calculate target angle so the wheel lands on segmentIndex
    //    Each segment spans 2π/8 = π/4 radians.
    //    Segment 0 starts at angle 0 (top of wheel, 12 o'clock).
    //    We want the centre of segmentIndex to face the pointer (top).
    const segCount = 8; // must match _segments.length
    const segAngle = 2 * math.pi / segCount;

    // Centre angle of target segment (in wheel-local coords, 0 = top)
    final targetCentre = segmentIndex * segAngle + segAngle / 2;

    // Add 5 full rotations for drama, then align to target
    final spins = 5 * 2 * math.pi;
    // We want wheel to rotate so that targetCentre aligns with pointer (0).
    // Net wheel rotation = spins + (2π - targetCentre) to bring it to top.
    final targetAngle = _currentAngle + spins + (2 * math.pi - targetCentre);

    // 3. Animate
    final startAngle = _currentAngle;
    final tween = Tween<double>(begin: startAngle, end: targetAngle);
    final curved = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOutCubic,
    );

    _animCtrl.reset();

    // Haptic ticks every ~45° during spin
    _animCtrl.addListener(() {
      final progress = _animCtrl.value;
      final angle = tween.evaluate(curved);
      final tick = ((angle) / (segAngle / 2)).floor();
      if (tick % 2 == 0 && progress < 0.85) {
        HapticFeedback.selectionClick();
      }
    });

    try {
      await _audio.seek(Duration.zero);
      await _audio.play();
    } catch (_) {}

    await _animCtrl.forward();

    setState(() {
      _currentAngle = targetAngle % (2 * math.pi);
      _newBalance   = newBalance;
      _spinning     = false;
    });

    HapticFeedback.heavyImpact();
    _showResult(prizeName, pointsWon, newBalance, segmentIndex);
  }

  void _showResult(
      String prize, int points, int balance, int segIdx) {
    final seg = _segments[segIdx];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D3D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: seg.color.withAlpha(180), width: 2),
              boxShadow: [
                BoxShadow(
                  color: seg.color.withAlpha(80),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  points == 0 ? '😔' : (points >= 500 ? '🎉' : '🎊'),
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 12),
                Text(
                  prize,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: seg.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (points > 0) ...[
                  Text(
                    '+$points points',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD740),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  'New balance: $balance pts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _newBalance = balance);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: seg.color,
                      foregroundColor:
                          seg.color.computeLuminance() > 0.4
                              ? Colors.black
                              : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Awesome!',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Spin & Win',
            style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0D21), Color(0xFF1A1D3D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Balance display
              _BalanceBar(balance: _newBalance, scheme: scheme),
              const SizedBox(height: 8),
              // Cost hint
              Text(
                'Each spin costs 50 pts • New users get 150 pts free',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withAlpha(120)),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Wheel + pointer
              _WheelWithPointer(
                animCtrl: _animCtrl,
                currentAngle: _currentAngle,
                spinning: _spinning,
              ),
              const Spacer(),
              // Spin button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: (_spinning || !_canSpin) ? null : _spin,
                    icon: _spinning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.casino_outlined, size: 22),
                    label: Text(
                      _spinning ? 'Spinning...' : 'SPIN  (50 pts)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD740),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          const Color(0xFFFFD740).withAlpha(80),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      elevation: _spinning ? 0 : 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Balance bar ──────────────────────────────────────────────────────────────

class _BalanceBar extends StatelessWidget {
  final int? balance;
  final ColorScheme scheme;
  const _BalanceBar({required this.balance, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD740).withAlpha(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD740).withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFD740), size: 22),
          const SizedBox(width: 8),
          Text(
            balance != null ? '$balance pts' : '— pts',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD740),
            ),
          ),
          const SizedBox(width: 6),
          Text('balance',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withAlpha(140))),
        ],
      ),
    );
  }
}

// ─── Wheel widget + pointer ───────────────────────────────────────────────────

class _WheelWithPointer extends StatelessWidget {
  final AnimationController animCtrl;
  final double currentAngle;
  final bool spinning;

  const _WheelWithPointer({
    required this.animCtrl,
    required this.currentAngle,
    required this.spinning,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Glow ring
        Container(
          width: 310,
          height: 310,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withAlpha(spinning ? 80 : 40),
                blurRadius: spinning ? 40 : 24,
                spreadRadius: spinning ? 8 : 2,
              ),
            ],
          ),
        ),
        // Animated wheel
        AnimatedBuilder(
          animation: animCtrl,
          builder: (_, _) {
            final angle = spinning
                ? currentAngle + animCtrl.value * 2 * math.pi * 5
                : currentAngle;
            return Transform.rotate(
              angle: angle,
              child: CustomPaint(
                size: const Size(300, 300),
                painter: _WheelPainter(),
              ),
            );
          },
        ),
        // Centre hub
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B0D21),
            border: Border.all(color: const Color(0xFF00E5FF), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withAlpha(120),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.casino_rounded,
              color: Color(0xFF00E5FF), size: 24),
        ),
        // Pointer triangle at top
        Positioned(
          top: 0,
          child: CustomPaint(
            size: const Size(28, 36),
            painter: _PointerPainter(),
          ),
        ),
      ],
    );
  }
}

// ─── Wheel painter ────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const segCount = 8; // must match _segments.length
    const sweepAngle = 2 * math.pi / segCount;

    for (var i = 0; i < segCount; i++) {
      final startAngle = i * sweepAngle - math.pi / 2;
      final seg = _segments[i];

      // Segment fill
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
          Rect.fromCircle(center: centre, radius: radius),
          startAngle, sweepAngle, true, paint);

      // Segment border
      final border = Paint()
        ..color = Colors.black.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
          Rect.fromCircle(center: centre, radius: radius),
          startAngle, sweepAngle, true, border);

      // Label
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(startAngle + sweepAngle / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: TextStyle(
            color: seg.color.computeLuminance() > 0.4
                ? Colors.black
                : Colors.white,
            fontSize: seg.label.length > 8 ? 11 : 13,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(blurRadius: 2, color: Colors.black54),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.55);

      tp.paint(
        canvas,
        Offset(radius * 0.42 - tp.width / 2, -tp.height / 2),
      );
      canvas.restore();
    }

    // Outer ring
    final ring = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(centre, radius - 2, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Pointer painter ─────────────────────────────────────────────────────────

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFD740)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withAlpha(80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
