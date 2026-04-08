import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gameroom_model.dart';
import '../providers/gameroom_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton_loader.dart';

class GameRoomListScreen extends ConsumerStatefulWidget {
  final void Function(String id, String title) onOpenRoom;
  final VoidCallback onCreateRoom;

  const GameRoomListScreen({super.key, required this.onOpenRoom, required this.onCreateRoom});

  @override
  ConsumerState<GameRoomListScreen> createState() => _GameRoomListScreenState();
}

class _GameRoomListScreenState extends ConsumerState<GameRoomListScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.emoji_events_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Game Rooms', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          GestureDetector(
            onTap: widget.onCreateRoom,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: scheme.primary.withAlpha(80), blurRadius: 12)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 16,
                    color: isDark ? Colors.black : Colors.white),
                const SizedBox(width: 4),
                Text('Create', style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: isDark ? Colors.black : Colors.white,
                )),
              ]),
            ),
          ),
        ],
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
                _PillTab(
                  label: 'Public',
                  selected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                  scheme: scheme,
                  isDark: isDark,
                ),
                _PillTab(
                  label: 'My Rooms',
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
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _RoomList(provider: publicGameRoomsProvider, onOpen: widget.onOpenRoom,
              emptyTitle: 'No game rooms yet', emptySubtitle: 'Be the first to create one!',
              onAction: widget.onCreateRoom, actionLabel: 'Create Room'),
          _RoomList(provider: myGameRoomsProvider, onOpen: widget.onOpenRoom,
              emptyTitle: 'No rooms created', emptySubtitle: 'Create your first treasure hunt!',
              onAction: widget.onCreateRoom, actionLabel: 'Create Room'),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool isDark;

  const _PillTab({
    required this.label,
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? (isDark ? Colors.black : Colors.white)
                  : scheme.onSurface.withAlpha(150),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<GameRoomModel>>> provider;
  final void Function(String, String) onOpen;
  final String emptyTitle, emptySubtitle, actionLabel;
  final VoidCallback onAction;

  const _RoomList({
    required this.provider,
    required this.onOpen,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => ListView.builder(
          itemCount: 4,
          itemBuilder: (ctx, i) => const SkeletonCard().animate(delay: Duration(milliseconds: i * 60)).fadeIn()),
      error: (e, _) => EmptyState(
          icon: Icons.cloud_off_outlined, title: 'Failed to load',
          subtitle: e.toString(), actionLabel: 'Retry',
          onAction: () => ref.invalidate(provider)),
      data: (rooms) => rooms.isEmpty
          ? EmptyState(icon: Icons.emoji_events_outlined, title: emptyTitle,
              subtitle: emptySubtitle, actionLabel: actionLabel, onAction: onAction)
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () async => ref.invalidate(provider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: rooms.length,
                itemBuilder: (ctx, i) => _RoomCard(
                  room: rooms[i],
                  onTap: () => onOpen(rooms[i].id, rooms[i].title),
                ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.05),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary.withAlpha(80)),
                ),
                child: Icon(Icons.emoji_events_rounded, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.person_outline, size: 13, color: scheme.onSurface.withAlpha(120)),
                  const SizedBox(width: 3),
                  Text(room.creatorName, style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
                  const SizedBox(width: 10),
                  Icon(Icons.inventory_2_outlined, size: 13, color: scheme.onSurface.withAlpha(120)),
                  const SizedBox(width: 3),
                  Text('${room.capsuleCount} capsules',
                      style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
                ]),
              ])),
              Icon(Icons.chevron_right_rounded, color: scheme.primary.withAlpha(180)),
            ]),
          ),
        ),
      ),
    );
  }
}
