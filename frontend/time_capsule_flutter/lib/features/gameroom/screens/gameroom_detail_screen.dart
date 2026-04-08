import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gameroom_model.dart';
import '../providers/gameroom_provider.dart';
import '../../capsule/models/capsule_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton_loader.dart';

class GameRoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomTitle;

  const GameRoomDetailScreen({super.key, required this.roomId, required this.roomTitle});

  @override
  ConsumerState<GameRoomDetailScreen> createState() => _GameRoomDetailScreenState();
}

class _GameRoomDetailScreenState extends ConsumerState<GameRoomDetailScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roomAsync = ref.watch(gameRoomDetailProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D3D) : const Color(0xFFECEFF1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.primary.withAlpha(40)),
              ),
              child: Row(children: [
                _DetailPillTab(
                  label: 'Capsules',
                  icon: Icons.inventory_2_outlined,
                  selected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                  scheme: scheme,
                  isDark: isDark,
                ),
                _DetailPillTab(
                  label: 'Leaderboard',
                  icon: Icons.emoji_events_outlined,
                  selected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                  scheme: scheme,
                  isDark: isDark,
                ),
              ]),
            ),
          ),
        ),
      ),
      body: roomAsync.when(
        loading: () => ListView.builder(
            itemCount: 4,
            itemBuilder: (ctx, i) => const SkeletonCard()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (room) => IndexedStack(
          index: _selectedTab,
          children: [
            _CapsulesTab(room: room, onRefresh: () => ref.invalidate(gameRoomDetailProvider(widget.roomId))),
            _LeaderboardTab(roomId: widget.roomId),
          ],
        ),
      ),
    );
  }
}

class _DetailPillTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool isDark;

  const _DetailPillTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [BoxShadow(color: scheme.primary.withAlpha(80), blurRadius: 8)]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : scheme.onSurface.withAlpha(150)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? (isDark ? Colors.black : Colors.white)
                  : scheme.onSurface.withAlpha(150),
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Capsules Tab ─────────────────────────────────────────────────────────────

class _CapsulesTab extends StatelessWidget {
  final GameRoomModel room;
  final VoidCallback onRefresh;
  const _CapsulesTab({required this.room, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final capsules = room.capsules ?? [];
    if (capsules.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 60, color: Theme.of(context).colorScheme.primary.withAlpha(80)),
        const SizedBox(height: 12),
        const Text('No capsules in this room yet'),
      ]));
    }
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: capsules.length,
        itemBuilder: (ctx, i) => _CapsuleCard(capsule: capsules[i])
            .animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.05),
      ),
    );
  }
}

class _CapsuleCard extends StatefulWidget {
  final CapsuleModel capsule;
  const _CapsuleCard({required this.capsule});
  @override
  State<_CapsuleCard> createState() => _CapsuleCardState();
}

class _CapsuleCardState extends State<_CapsuleCard> {
  bool _unlocking = false;

  Future<void> _unlock() async {
    setState(() => _unlocking = true);
    try {
      final res = await dioClient.post('/capsules/${widget.capsule.id}/unlock',
          data: {'latitude': 0.0, 'longitude': 0.0}); // GPS in real usage
      final success = res.data['success'] as bool? ?? false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] as String? ?? (success ? 'Unlocked!' : 'Cannot unlock')),
          backgroundColor: success
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capsule = widget.capsule;
    final isUnlocked = capsule.status == 'Unlocked';
    final canUnlock = !isUnlocked && DateTime.now().isAfter(DateTime.parse(capsule.unlockDate));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(capsule.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isUnlocked ? scheme.primary.withAlpha(30) : scheme.error.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isUnlocked ? scheme.primary : scheme.error, width: 0.8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(
                    color: isUnlocked ? scheme.primary : scheme.error, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(capsule.status,
                    style: TextStyle(color: isUnlocked ? scheme.primary : scheme.error,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          if (isUnlocked && capsule.message != null)
            Text(capsule.message!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFD740)),
            const SizedBox(width: 4),
            Text('${capsule.pointsReward} pts',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
            const SizedBox(width: 12),
            Icon(Icons.lock_clock_outlined, size: 14, color: scheme.onSurface.withAlpha(120)),
            const SizedBox(width: 4),
            Text(_formatDate(capsule.unlockDate),
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
            const Spacer(),
            if (!isUnlocked)
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: canUnlock && !_unlocking ? _unlock : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _unlocking
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(canUnlock ? 'Unlock' : 'Locked',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }
}

// ─── Leaderboard Tab ──────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final String roomId;
  const _LeaderboardTab({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(leaderboardProvider(roomId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) => entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.emoji_events_outlined, size: 60, color: scheme.primary.withAlpha(80)),
              const SizedBox(height: 12),
              const Text('No one has unlocked a capsule yet'),
              const SizedBox(height: 4),
              Text('Be the first!', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
            ]))
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async => ref.invalidate(leaderboardProvider(roomId)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: entries.length,
                itemBuilder: (ctx, i) {
                  final entry = entries[i];
                  final isTop3 = entry.rank <= 3;
                  final medalColors = [
                    const Color(0xFFFFD700), // gold
                    const Color(0xFFC0C0C0), // silver
                    const Color(0xFFCD7F32), // bronze
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      child: Row(children: [
                        // Rank
                        SizedBox(
                          width: 36,
                          child: isTop3
                              ? Icon(Icons.emoji_events_rounded,
                                  color: medalColors[entry.rank - 1], size: 24)
                              : Text('#${entry.rank}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface.withAlpha(150),
                                  ),
                                  textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 10),
                        AvatarWidget(url: entry.profilePictureUrl, name: entry.displayName, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('${entry.unlockedCount} capsule${entry.unlockedCount == 1 ? '' : 's'} unlocked',
                              style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${entry.totalPoints}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 20, color: scheme.primary)),
                          Text('pts', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(120))),
                        ]),
                      ]),
                    ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideX(begin: 0.05),
                  );
                },
              ),
            ),
    );
  }
}
