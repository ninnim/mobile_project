import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/capsule_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../features/gameroom/providers/gameroom_provider.dart';
import '../../../features/gameroom/models/gameroom_model.dart';
import 'capsule_detail_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final myCapsuleProvider = FutureProvider.autoDispose<List<CapsuleModel>>((ref) async {
  final res = await dioClient.get('/capsules');
  return (res.data as List<dynamic>)
      .map((e) => CapsuleModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CapsuleListScreen extends ConsumerStatefulWidget {
  final VoidCallback onCreateCapsule;
  const CapsuleListScreen({super.key, required this.onCreateCapsule});

  @override
  ConsumerState<CapsuleListScreen> createState() => _CapsuleListScreenState();
}

class _CapsuleListScreenState extends ConsumerState<CapsuleListScreen> {
  int _tab = 0; // 0 = My Capsules, 1 = Game Rooms

  void _createAction(BuildContext ctx) {
    HapticFeedback.lightImpact();
    if (_tab == 0) {
      widget.onCreateCapsule();
    } else {
      Navigator.pushNamed(ctx, '/create-gameroom').then((_) {
        ref.invalidate(publicGameRoomsProvider);
        ref.invalidate(myGameRoomsProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              _tab == 0 ? Icons.inventory_2_outlined : Icons.emoji_events_rounded,
              key: ValueKey(_tab),
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              _tab == 0 ? 'My Capsules' : 'Game Rooms',
              key: ValueKey(_tab),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        actions: [
          GestureDetector(
            onTap: () => _createAction(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: scheme.primary.withAlpha(80), blurRadius: 12)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 16, color: isDark ? Colors.black : Colors.white),
                const SizedBox(width: 4),
                Text('New', style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: isDark ? Colors.black : Colors.white,
                )),
              ]),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _PillTabs(
              selected: _tab,
              labels: const ['My Capsules', 'Game Rooms'],
              icons: const [Icons.inventory_2_outlined, Icons.emoji_events_outlined],
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _tab = i);
              },
              scheme: scheme,
              isDark: isDark,
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _CapsulesTab(onCreateCapsule: widget.onCreateCapsule),
          _GameRoomsTab(),
        ],
      ),
    );
  }
}

// ── Pill tab switcher ─────────────────────────────────────────────────────────

class _PillTabs extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;
  final ColorScheme scheme;
  final bool isDark;

  const _PillTabs({
    required this.selected,
    required this.labels,
    required this.icons,
    required this.onChanged,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D3D) : const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) => Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: selected == i ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected == i
                    ? [BoxShadow(color: scheme.primary.withAlpha(70), blurRadius: 8)]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icons[i], size: 13,
                    color: selected == i
                        ? (isDark ? Colors.black : Colors.white)
                        : scheme.onSurface.withAlpha(140)),
                const SizedBox(width: 5),
                Text(labels[i], style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected == i
                      ? (isDark ? Colors.black : Colors.white)
                      : scheme.onSurface.withAlpha(140),
                )),
              ]),
            ),
          ),
        )),
      ),
    );
  }
}

// ── Capsules tab ──────────────────────────────────────────────────────────────

class _CapsulesTab extends ConsumerWidget {
  final VoidCallback onCreateCapsule;
  const _CapsulesTab({required this.onCreateCapsule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsulesAsync = ref.watch(myCapsuleProvider);
    final scheme = Theme.of(context).colorScheme;

    return capsulesAsync.when(
      loading: () => ListView.builder(
        itemCount: 4,
        itemBuilder: (ctx, i) => const SkeletonCard(),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Failed to load capsules',
        actionLabel: 'Try Again',
        onAction: () => ref.refresh(myCapsuleProvider),
      ),
      data: (capsules) => capsules.isEmpty
          ? EmptyState(
              icon: Icons.rocket_launch_outlined,
              title: 'No capsules yet!',
              subtitle: 'Send your first message to the future',
              actionLabel: 'Create Capsule',
              onAction: onCreateCapsule,
            )
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async => ref.refresh(myCapsuleProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 400,
                itemCount: capsules.length,
                addRepaintBoundaries: false, // we add manual RepaintBoundary below
                itemBuilder: (ctx, i) {
                  final card = RepaintBoundary(
                    child: _CapsuleCard(
                      capsule: capsules[i],
                      onTap: () => Navigator.push(ctx, MaterialPageRoute(
                        builder: (_) => CapsuleDetailScreen(capsule: capsules[i]),
                      )),
                    ),
                  );
                  if (i < 7) {
                    return card
                        .animate(delay: Duration(milliseconds: i * 45))
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.04, duration: 300.ms, curve: Curves.easeOutCubic);
                  }
                  return card;
                },
              ),
            ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  final CapsuleModel capsule;
  final VoidCallback? onTap;
  const _CapsuleCard({required this.capsule, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlockDate = DateTime.tryParse(capsule.unlockDate);
    final isLocked = capsule.isLocked;
    final now = DateTime.now();
    final canUnlock = unlockDate != null && now.isAfter(unlockDate) && isLocked;
    final daysLeft = unlockDate != null && unlockDate.isAfter(now)
        ? unlockDate.difference(now).inDays
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        blur: false,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLocked ? scheme.error.withAlpha(20) : scheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                    color: isLocked ? scheme.error : scheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(capsule.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (capsule.isPublic)
                      Text('Public', style: TextStyle(
                          color: scheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLocked ? scheme.error.withAlpha(20) : scheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isLocked ? scheme.error.withAlpha(80) : scheme.primary.withAlpha(80)),
                  ),
                  child: Text(
                    isLocked ? 'Locked' : 'Unlocked',
                    style: TextStyle(
                        color: isLocked ? scheme.error : scheme.primary,
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 13,
                    color: scheme.onSurface.withAlpha(120)),
                const SizedBox(width: 6),
                Text(
                  unlockDate != null ? 'Unlocks ${_fmt(unlockDate)}' : 'No date',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (isLocked && daysLeft > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$daysLeft days left',
                        style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
                  ),
                ],
              ]),
              if (canUnlock) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.primary.withAlpha(80)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_open, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text('Ready to unlock!', style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ],
              if (!isLocked && capsule.message != null) ...[
                const SizedBox(height: 10),
                Text(capsule.message!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── Game Rooms tab ────────────────────────────────────────────────────────────

class _GameRoomsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GameRoomsTab> createState() => _GameRoomsTabState();
}

class _GameRoomsTabState extends ConsumerState<_GameRoomsTab> {
  int _roomTab = 0; // 0 = Public, 1 = My Rooms

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Sub-tab: Public / My Rooms
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _PillTabs(
            selected: _roomTab,
            labels: const ['Public', 'My Rooms'],
            icons: const [Icons.public_rounded, Icons.manage_accounts_rounded],
            onChanged: (i) => setState(() => _roomTab = i),
            scheme: scheme,
            isDark: isDark,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _roomTab,
            children: [
              _RoomList(
                provider: publicGameRoomsProvider,
                emptyTitle: 'No public rooms yet',
                emptySubtitle: 'Create the first treasure hunt!',
                onAction: () => Navigator.pushNamed(context, '/create-gameroom').then((_) {
                  ref.invalidate(publicGameRoomsProvider);
                  ref.invalidate(myGameRoomsProvider);
                }),
                actionLabel: 'Create Room',
              ),
              _RoomList(
                provider: myGameRoomsProvider,
                emptyTitle: 'No rooms created yet',
                emptySubtitle: 'Start your first treasure hunt!',
                onAction: () => Navigator.pushNamed(context, '/create-gameroom').then((_) {
                  ref.invalidate(publicGameRoomsProvider);
                  ref.invalidate(myGameRoomsProvider);
                }),
                actionLabel: 'Create Room',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<GameRoomModel>>> provider;
  final String emptyTitle, emptySubtitle, actionLabel;
  final VoidCallback onAction;

  const _RoomList({
    required this.provider,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => ListView.builder(
        itemCount: 4,
        itemBuilder: (ctx, i) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: SkeletonCard(),
        ),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Failed to load',
        subtitle: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(provider),
      ),
      data: (rooms) => rooms.isEmpty
          ? EmptyState(
              icon: Icons.emoji_events_outlined,
              title: emptyTitle,
              subtitle: emptySubtitle,
              actionLabel: actionLabel,
              onAction: onAction,
            )
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async => ref.invalidate(provider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 400,
                itemCount: rooms.length,
                addRepaintBoundaries: false,
                itemBuilder: (ctx, i) {
                  final card = RepaintBoundary(
                    child: _RoomCard(
                      room: rooms[i],
                      onTap: () => Navigator.pushNamed(ctx, '/gameroom',
                          arguments: {'id': rooms[i].id, 'title': rooms[i].title}),
                    ),
                  );
                  if (i < 7) {
                    return card
                        .animate(delay: Duration(milliseconds: i * 40))
                        .fadeIn(duration: 280.ms)
                        .slideY(begin: 0.05, duration: 280.ms, curve: Curves.easeOutCubic);
                  }
                  return card;
                },
              ),
            ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final GameRoomModel room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = room.capsuleCount > 0
        ? room.unlockedCount / room.capsuleCount
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        blur: false,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary.withAlpha(70)),
                  ),
                  child: Icon(Icons.emoji_events_rounded, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(room.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.person_outline, size: 12, color: scheme.onSurface.withAlpha(110)),
                    const SizedBox(width: 3),
                    Text(room.creatorName,
                        style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(140))),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.primary.withAlpha(50)),
                      ),
                      child: Text(room.isPublic ? 'Public' : 'Private',
                          style: TextStyle(fontSize: 10, color: scheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ])),
                Icon(Icons.chevron_right_rounded, color: scheme.primary.withAlpha(160)),
              ]),
              if (room.capsuleCount > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: scheme.onSurface.withAlpha(20),
                        color: scheme.primary,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${room.unlockedCount}/${room.capsuleCount}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(Icons.inventory_2_outlined, size: 12, color: scheme.onSurface.withAlpha(110)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
