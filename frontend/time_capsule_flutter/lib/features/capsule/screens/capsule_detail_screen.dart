import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/capsule_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_button.dart';

class CapsuleDetailScreen extends ConsumerStatefulWidget {
  final CapsuleModel capsule;
  const CapsuleDetailScreen({super.key, required this.capsule});

  @override
  ConsumerState<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

class _CapsuleDetailScreenState extends ConsumerState<CapsuleDetailScreen> {
  late CapsuleModel _capsule;
  bool _unlocking = false;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;
  int _mediaPage = 0;

  @override
  void initState() {
    super.initState();
    _capsule = widget.capsule;
    _startCountdown();
  }

  void _startCountdown() {
    final unlockDate = DateTime.tryParse(_capsule.unlockDate);
    if (unlockDate == null) return;
    _updateTimeLeft(unlockDate);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTimeLeft(unlockDate);
    });
  }

  void _updateTimeLeft(DateTime unlockDate) {
    final now = DateTime.now();
    final diff = unlockDate.toLocal().difference(now);
    setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => _unlocking = true);
    try {
      Position? pos;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        pos = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      final res = await dioClient.post('/capsules/${_capsule.id}/unlock', data: {
        'latitude': pos?.latitude ?? 0.0,
        'longitude': pos?.longitude ?? 0.0,
      });

      final success = res.data['success'] as bool? ?? false;
      final message = res.data['message'] as String? ?? '';
      if (!mounted) return;

      if (success) {
        // Reload capsule
        final detailRes = await dioClient.get('/capsules/${_capsule.id}');
        setState(() {
          _capsule = CapsuleModel.fromJson(detailRes.data as Map<String, dynamic>);
        });
        _showResult(message, success: true);
        NotificationService.showCapsuleUnlocked(_capsule.title);
      } else {
        _showResult(message, success: false);
      }
    } catch (e) {
      if (mounted) _showResult('Unlock failed. Try again.', success: false);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _showResult(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capsule = _capsule;
    final unlockDate = DateTime.tryParse(capsule.unlockDate)?.toLocal();
    final isLocked = capsule.isLocked;
    final now = DateTime.now();
    final canUnlock = unlockDate != null && now.isAfter(unlockDate) && isLocked;
    final tooEarly = isLocked && unlockDate != null && now.isBefore(unlockDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(capsule.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLocked ? scheme.error.withAlpha(20) : scheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isLocked ? scheme.error.withAlpha(100) : scheme.primary.withAlpha(100)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: isLocked ? scheme.error : scheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(isLocked ? 'Locked' : 'Unlocked',
                  style: TextStyle(
                      color: isLocked ? scheme.error : scheme.primary,
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Info Card ──────────────────────────────────────────────────────
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.person_outline, size: 16, color: scheme.onSurface.withAlpha(150)),
                const SizedBox(width: 6),
                Text('From ${capsule.senderName}',
                    style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(180))),
                const Spacer(),
                if (capsule.isPublic)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.primary.withAlpha(80)),
                    ),
                    child: Text('Public', style: TextStyle(color: scheme.primary, fontSize: 11)),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  unlockDate != null
                      ? 'Unlocks ${unlockDate.day}/${unlockDate.month}/${unlockDate.year}'
                      : 'No date',
                  style: TextStyle(color: scheme.onSurface.withAlpha(200), fontSize: 14),
                ),
              ]),
              if (capsule.pointsReward > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.star_rounded, size: 15, color: const Color(0xFFFFD740)),
                  const SizedBox(width: 8),
                  Text('${capsule.pointsReward} points reward',
                      style: TextStyle(color: scheme.onSurface.withAlpha(200), fontSize: 14)),
                ]),
              ],
            ]),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          // ── Countdown Timer (if locked & too early) ───────────────────────
          if (tooEarly) ...[
            GlassCard(
              child: Column(children: [
                Text('Opens In',
                    style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withAlpha(150),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _CountdownRow(duration: _timeLeft),
              ]),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            const SizedBox(height: 12),
          ],

          // ── Unlock Button (if time has passed) ────────────────────────────
          if (canUnlock) ...[
            GlassButton(
              title: 'Unlock Capsule',
              onPressed: _unlocking ? null : _unlock,
              loading: _unlocking,
              width: double.infinity,
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            const SizedBox(height: 12),
          ],

          // ── Message (if unlocked or sender) ───────────────────────────────
          if (!isLocked && capsule.message != null) ...[
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.lock_open_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Message', style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                Text(capsule.message!,
                    style: const TextStyle(fontSize: 16, height: 1.6)),
              ]),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .shimmer(duration: 1500.ms, color: scheme.primary.withAlpha(60)),
            const SizedBox(height: 12),
          ] else if (isLocked) ...[
            GlassCard(
              child: Column(children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.error.withAlpha(120)),
                const SizedBox(height: 12),
                Text('Message is locked', style: TextStyle(
                    color: scheme.onSurface.withAlpha(150), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    tooEarly
                        ? 'Come back when the timer runs out'
                        : 'Get close to the location to unlock',
                    style: TextStyle(color: scheme.onSurface.withAlpha(100), fontSize: 13),
                    textAlign: TextAlign.center),
              ]),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: 12),
          ],

          // ── Media Gallery ──────────────────────────────────────────────────
          if (capsule.media.isNotEmpty && !isLocked) ...[
            GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Media', style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: scheme.primary)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: capsule.media.length,
                    onPageChanged: (i) => setState(() => _mediaPage = i),
                    itemBuilder: (ctx, i) {
                      final media = capsule.media[i];
                      final url = media.fileUrl.startsWith('http')
                          ? media.fileUrl
                          : '${ApiConstants.uploadsBase}/${media.fileUrl}';
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(color: scheme.surface),
                          errorWidget: (ctx, url, err) => const Icon(Icons.broken_image),
                        ),
                      );
                    },
                  ),
                ),
                if (capsule.media.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(capsule.media.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _mediaPage == i ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _mediaPage == i ? scheme.primary : scheme.primary.withAlpha(80),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                ],
              ]),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          ],
        ]),
      ),
    );
  }
}

// ─── Countdown Widget ─────────────────────────────────────────────────────────

class _CountdownRow extends StatelessWidget {
  final Duration duration;
  const _CountdownRow({required this.duration});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final mins = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TimeUnit(value: days, label: 'Days', scheme: scheme),
        _Colon(scheme: scheme),
        _TimeUnit(value: hours, label: 'Hours', scheme: scheme),
        _Colon(scheme: scheme),
        _TimeUnit(value: mins, label: 'Min', scheme: scheme),
        _Colon(scheme: scheme),
        _TimeUnit(value: secs, label: 'Sec', scheme: scheme),
      ],
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;
  final ColorScheme scheme;
  const _TimeUnit({required this.value, required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: scheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.primary.withAlpha(80)),
          ),
          child: Center(
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: scheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(150))),
      ]);
}

class _Colon extends StatelessWidget {
  final ColorScheme scheme;
  const _Colon({required this.scheme});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
        child: Text(':', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w900, color: scheme.primary)),
      );
}
