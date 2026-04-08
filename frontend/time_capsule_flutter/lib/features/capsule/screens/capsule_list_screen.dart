import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/capsule_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/glass_card.dart';
import 'capsule_detail_screen.dart';

final myCapsuleProvider = FutureProvider.autoDispose<List<CapsuleModel>>((ref) async {
  final res = await dioClient.get('/capsules');
  return (res.data as List<dynamic>)
      .map((e) => CapsuleModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class CapsuleListScreen extends ConsumerWidget {
  final VoidCallback onCreateCapsule;

  const CapsuleListScreen({super.key, required this.onCreateCapsule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsulesAsync = ref.watch(myCapsuleProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.inventory_2_outlined, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('My Capsules', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          GestureDetector(
            onTap: onCreateCapsule,
            child: Container(
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
                Text('New', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.black : Colors.white)),
              ]),
            ),
          ),
        ],
      ),
      body: capsulesAsync.when(
        loading: () => ListView.builder(itemCount: 4, itemBuilder: (ctx, i) => const SkeletonCard()),
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: capsules.length,
                  itemBuilder: (ctx, i) => _CapsuleCard(
                        capsule: capsules[i],
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => CapsuleDetailScreen(capsule: capsules[i]),
                        )),
                      ).animate(delay: Duration(milliseconds: i * 50))
                      .fadeIn()
                      .slideY(begin: 0.05),
                ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
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
                  Text(capsule.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (capsule.isPublic)
                    Text('Public', style: TextStyle(color: scheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLocked ? scheme.error.withAlpha(20) : scheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isLocked ? scheme.error.withAlpha(80) : scheme.primary.withAlpha(80)),
                ),
                child: Text(
                  isLocked ? 'Locked' : 'Unlocked',
                  style: TextStyle(color: isLocked ? scheme.error : scheme.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: scheme.onSurface.withAlpha(120)),
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
                  child: Text('$daysLeft days left', style: TextStyle(fontSize: 11, color: scheme.onSurface.withAlpha(150))),
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
                  Text('Ready to unlock!', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ],
            if (!isLocked && capsule.message != null) ...[
              const SizedBox(height: 10),
              Text(capsule.message!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    ));
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
