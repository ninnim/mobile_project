import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gameroom_model.dart';
import '../providers/gameroom_provider.dart';
import '../../capsule/models/capsule_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton_loader.dart';

// ─── Root screen ──────────────────────────────────────────────────────────────

class GameRoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomTitle;

  const GameRoomDetailScreen({super.key, required this.roomId, required this.roomTitle});

  @override
  ConsumerState<GameRoomDetailScreen> createState() => _GameRoomDetailScreenState();
}

class _GameRoomDetailScreenState extends ConsumerState<GameRoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roomAsync = ref.watch(gameRoomDetailProvider(widget.roomId));

    return Scaffold(
      body: roomAsync.when(
        loading: _buildLoading,
        error: (e, _) => _buildError(e),
        data: (room) => _buildContent(room, scheme, isDark),
      ),
    );
  }

  Widget _buildLoading() => Scaffold(
    appBar: AppBar(
      title: Text(widget.roomTitle,
          style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, i) => const Padding(
          padding: EdgeInsets.only(bottom: 10), child: SkeletonCard()),
    ),
  );

  Widget _buildError(Object e) => Scaffold(
    appBar: AppBar(
        title: Text(widget.roomTitle,
            style: const TextStyle(fontWeight: FontWeight.w800))),
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 60),
        const SizedBox(height: 12),
        Text('$e', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => ref.invalidate(gameRoomDetailProvider(widget.roomId)),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );

  void _shareInvite(GameRoomModel room) {
    final text = '🎮 Join my TimeCapsule game room!\n\n'
        '🏷️ Room: ${room.title}\n'
        '🔒 Capsules: ${room.capsuleCount} hidden capsules to unlock\n'
        '🆔 Room ID: ${room.id}\n\n'
        'Open TimeCapsule app → Game Rooms → find "${room.title}"';
    Share.share(text, subject: 'Join ${room.title} on TimeCapsule');
  }

  Widget _buildContent(GameRoomModel room, ColorScheme scheme, bool isDark) {
    final total = room.capsuleCount;
    final unlocked = room.unlockedCount;
    final progress = total > 0 ? unlocked / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.roomTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite friends',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary.withAlpha(60)),
              ),
              child: Icon(Icons.person_add_outlined,
                  color: scheme.primary, size: 18),
            ),
            onPressed: () => _shareInvite(room),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Stats strip ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 13, color: scheme.onSurface.withAlpha(120)),
                  const SizedBox(width: 4),
                  Text(room.creatorName,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withAlpha(150))),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: scheme.primary.withAlpha(50)),
                    ),
                    child: Text(
                      room.isPublic ? 'Public' : 'Private',
                      style: TextStyle(
                          fontSize: 10,
                          color: scheme.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.inventory_2_outlined,
                      size: 13, color: scheme.onSurface.withAlpha(120)),
                  const SizedBox(width: 4),
                  Text('$unlocked/$total unlocked',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withAlpha(150),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: scheme.onSurface.withAlpha(20),
                    color: scheme.primary,
                    minHeight: 5,
                  ),
                ),
              ),
              // ── Tab bar ──
              TabBar(
                controller: _tabCtrl,
                indicatorColor: scheme.primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurface.withAlpha(120),
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: 'Capsules'),
                  Tab(
                      icon: Icon(Icons.emoji_events_outlined, size: 18),
                      text: 'Leaderboard'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _CapsulesTab(
            room: room,
            onRefresh: () =>
                ref.invalidate(gameRoomDetailProvider(widget.roomId)),
          ),
          _LeaderboardTab(roomId: widget.roomId),
        ],
      ),
    );
  }
}

// ─── Capsules tab ─────────────────────────────────────────────────────────────

class _CapsulesTab extends StatelessWidget {
  final GameRoomModel room;
  final VoidCallback onRefresh;
  const _CapsulesTab({required this.room, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capsules = room.capsules ?? [];

    if (capsules.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 60,
              color: scheme.primary.withAlpha(70)),
          const SizedBox(height: 12),
          const Text('No capsules in this room yet',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Add capsules from the Create screen',
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(140))),
        ]),
      );
    }

    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        physics: const BouncingScrollPhysics(),
        cacheExtent: 400,
        itemCount: capsules.length,
        addRepaintBoundaries: false,
        itemBuilder: (ctx, i) {
          final card = RepaintBoundary(
            child: _CapsuleCard(capsule: capsules[i]),
          );
          if (i < 6) {
            return card
                .animate(delay: Duration(milliseconds: i * 45))
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic);
          }
          return card;
        },
      ),
    );
  }
}

// ─── Capsule card with GPS unlock ─────────────────────────────────────────────

class _CapsuleCard extends StatefulWidget {
  final CapsuleModel capsule;
  const _CapsuleCard({required this.capsule});

  @override
  State<_CapsuleCard> createState() => _CapsuleCardState();
}

class _CapsuleCardState extends State<_CapsuleCard> {
  bool _unlocking = false;

  Future<void> _unlock() async {
    HapticFeedback.mediumImpact();
    setState(() => _unlocking = true);

    double lat = 0, lng = 0;
    try {
      final pos = await _acquirePosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // proceed with 0,0 — server will return distance error
    }

    try {
      final res = await dioClient.post(
        '/capsules/${widget.capsule.id}/unlock',
        data: {'latitude': lat, 'longitude': lng},
      );
      final success = res.data['success'] as bool? ?? false;
      final msg = res.data['message'] as String? ?? (success ? 'Unlocked!' : 'Cannot unlock');

      if (mounted) {
        if (success) {
          HapticFeedback.heavyImpact();
          _showResult(true, msg);
        } else {
          HapticFeedback.vibrate();
          _showResult(false, msg);
        }
      }
    } catch (e) {
      if (mounted) {
        _showResult(false, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<Position?> _acquirePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  }

  void _showResult(bool success, String msg) {
    final ctx = context;
    if (!ctx.mounted) return;
    final scheme = Theme.of(ctx).colorScheme;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.lock_open_rounded : Icons.lock_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: success ? scheme.primary : scheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capsule = widget.capsule;
    final isUnlocked = capsule.status == 'Unlocked';
    final unlockDt = DateTime.tryParse(capsule.unlockDate);
    final canUnlock = !isUnlocked &&
        unlockDt != null &&
        DateTime.now().isAfter(unlockDt);
    final tooEarly = !isUnlocked && (unlockDt == null || !DateTime.now().isAfter(unlockDt));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        blur: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title row
          Row(children: [
            Expanded(
              child: Text(capsule.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _StatusBadge(isUnlocked: isUnlocked, scheme: scheme),
          ]),

          // Unlocked message
          if (isUnlocked && capsule.message != null) ...[
            const SizedBox(height: 8),
            Text(capsule.message!,
                style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(200))),
          ],

          const SizedBox(height: 10),

          // Meta row
          Row(children: [
            Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFD740)),
            const SizedBox(width: 4),
            Text('${capsule.pointsReward} pts',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150),
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 14),
            Icon(Icons.lock_clock_outlined, size: 14,
                color: scheme.onSurface.withAlpha(110)),
            const SizedBox(width: 4),
            Text(_fmtDate(capsule.unlockDate),
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
            const Spacer(),
            // Action button
            if (!isUnlocked)
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: canUnlock && !_unlocking ? _unlock : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tooEarly
                        ? scheme.onSurface.withAlpha(40)
                        : scheme.primary,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _unlocking
                      ? SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white))
                      : Text(
                          tooEarly ? 'Too early' : 'Unlock',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            if (isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.primary.withAlpha(60)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events_rounded,
                      size: 13, color: const Color(0xFFFFD740)),
                  const SizedBox(width: 4),
                  Text('+${capsule.pointsReward}',
                      style: TextStyle(fontSize: 12, color: scheme.primary,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ]),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isUnlocked;
  final ColorScheme scheme;
  const _StatusBadge({required this.isUnlocked, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(isUnlocked ? 'Unlocked' : 'Locked',
            style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Leaderboard tab ──────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final String roomId;
  const _LeaderboardTab({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(leaderboardProvider(roomId));

    return async.when(
      loading: () => ListView.builder(
        itemCount: 4,
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => const Padding(
            padding: EdgeInsets.only(bottom: 10), child: SkeletonCard()),
      ),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 10),
          Text('$e', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => ref.invalidate(leaderboardProvider(roomId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.emoji_events_outlined, size: 60,
                  color: scheme.primary.withAlpha(70)),
              const SizedBox(height: 12),
              const Text('No one has unlocked a capsule yet',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Be the first to claim the throne!',
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w600)),
            ]),
          );
        }

        return RefreshIndicator(
          color: scheme.primary,
          onRefresh: () async => ref.invalidate(leaderboardProvider(roomId)),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 400,
            slivers: [
              // Podium for top ≤ 3
              if (entries.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Podium(entries: entries.take(3).toList(),
                      scheme: scheme),
                ),

              // Rank list for position 4+
              if (entries.length > 3)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final entry = entries[i + 3];
                        final card = RepaintBoundary(
                          child: _RankRow(entry: entry, scheme: scheme),
                        );
                        if (i < 5) {
                          return card
                              .animate(delay: Duration(milliseconds: i * 40))
                              .fadeIn(duration: 260.ms)
                              .slideX(begin: 0.04, duration: 260.ms,
                                  curve: Curves.easeOutCubic);
                        }
                        return card;
                      },
                      childCount: entries.length - 3,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Podium ───────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final ColorScheme scheme;
  const _Podium({required this.entries, required this.scheme});

  @override
  Widget build(BuildContext context) {
    // positions: 2nd (left), 1st (centre, taller), 3rd (right)
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (second != null)
            Expanded(
              child: _PodiumSlot(
                entry: second,
                height: 80,
                crownIcon: '🥈',
                color: const Color(0xFFC0C0C0),
                scheme: scheme,
              ).animate(delay: 120.ms).fadeIn(duration: 400.ms).slideY(
                  begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // 1st place — tallest
          if (first != null)
            Expanded(
              flex: 2,
              child: _PodiumSlot(
                entry: first,
                height: 110,
                crownIcon: '👑',
                color: const Color(0xFFFFD700),
                scheme: scheme,
                isWinner: true,
              ).animate(delay: 40.ms).fadeIn(duration: 500.ms).slideY(
                  begin: 0.12, duration: 500.ms, curve: Curves.easeOutBack),
            )
          else
            const Expanded(flex: 2, child: SizedBox()),

          const SizedBox(width: 8),

          // 3rd place
          if (third != null)
            Expanded(
              child: _PodiumSlot(
                entry: third,
                height: 60,
                crownIcon: '🥉',
                color: const Color(0xFFCD7F32),
                scheme: scheme,
              ).animate(delay: 200.ms).fadeIn(duration: 360.ms).slideY(
                  begin: 0.1, duration: 360.ms, curve: Curves.easeOutCubic),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final String crownIcon;
  final Color color;
  final ColorScheme scheme;
  final bool isWinner;

  const _PodiumSlot({
    required this.entry,
    required this.height,
    required this.crownIcon,
    required this.color,
    required this.scheme,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Crown emoji
        Text(crownIcon, style: TextStyle(fontSize: isWinner ? 28 : 22)),
        const SizedBox(height: 4),
        // Avatar
        AvatarWidget(
          url: entry.profilePictureUrl,
          name: entry.displayName,
          radius: isWinner ? 26 : 20,
        ),
        const SizedBox(height: 6),
        // Name
        Text(
          entry.displayName.split(' ').first,
          style: TextStyle(
              fontSize: isWinner ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: isWinner ? color : scheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        // Points
        Text(
          '${entry.totalPoints} pts',
          style: TextStyle(
              fontSize: isWinner ? 12 : 10,
              fontWeight: FontWeight.w800,
              color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        // Podium block
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withAlpha(120), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${entry.rank}',
            style: TextStyle(
                fontSize: isWinner ? 22 : 18,
                fontWeight: FontWeight.w900,
                color: color),
          ),
        ),
      ],
    );
  }
}

// ─── Rank row (positions 4+) ──────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final ColorScheme scheme;
  const _RankRow({required this.entry, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        child: Row(children: [
          SizedBox(
            width: 36,
            child: Text('#${entry.rank}',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15,
                    color: scheme.onSurface.withAlpha(150)),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          AvatarWidget(
              url: entry.profilePictureUrl, name: entry.displayName, radius: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(
              '${entry.unlockedCount} capsule${entry.unlockedCount == 1 ? '' : 's'} unlocked',
              style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(140)),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${entry.totalPoints}',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18,
                    color: scheme.primary)),
            Text('pts',
                style: TextStyle(fontSize: 10, color: scheme.onSurface.withAlpha(110))),
          ]),
        ]),
      ),
    );
  }
}
