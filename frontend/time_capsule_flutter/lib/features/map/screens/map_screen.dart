import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../capsule/models/capsule_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/glass_card.dart';

final publicCapsulesProvider = FutureProvider.autoDispose<List<CapsuleModel>>((ref) async {
  final res = await dioClient.get('/capsules/public');
  return (res.data as List<dynamic>)
      .map((e) => CapsuleModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsulesAsync = ref.watch(publicCapsulesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.explore_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Discover', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: capsulesAsync.when(
        loading: () => ListView.builder(itemCount: 4, itemBuilder: (ctx, i) => const SkeletonCard()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Failed to load capsules',
          actionLabel: 'Try Again',
          onAction: () => ref.refresh(publicCapsulesProvider),
        ),
        data: (capsules) {
          final locked = capsules.where((c) => c.isLocked).toList();
          final unlocked = capsules.where((c) => !c.isLocked).toList();
          final sorted = [...unlocked, ...locked];
          return sorted.isEmpty
              ? const EmptyState(
                  icon: Icons.explore_outlined,
                  title: 'No public capsules yet',
                  subtitle: 'Be the first to drop one!',
                )
              : RefreshIndicator(
                  color: scheme.primary,
                  onRefresh: () async => ref.refresh(publicCapsulesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: sorted.length,
                    itemBuilder: (ctx, i) => _CapsuleDiscoverCard(capsule: sorted[i])
                        .animate(delay: Duration(milliseconds: i * 40))
                        .fadeIn()
                        .slideY(begin: 0.05),
                  ),
                );
        },
      ),
    );
  }
}

class _CapsuleDiscoverCard extends StatelessWidget {
  final CapsuleModel capsule;
  const _CapsuleDiscoverCard({required this.capsule});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLocked = capsule.isLocked;
    final unlockDate = DateTime.tryParse(capsule.unlockDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isLocked ? scheme.error.withAlpha(20) : scheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(isLocked ? Icons.lock_outline : Icons.lock_open_outlined, color: isLocked ? scheme.error : scheme.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(capsule.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('by ${capsule.senderName}', style: Theme.of(context).textTheme.labelSmall),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isLocked ? scheme.error.withAlpha(15) : scheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(isLocked ? 'Locked' : 'Open', style: TextStyle(color: isLocked ? scheme.error : scheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 13, color: scheme.onSurface.withAlpha(120)),
            const SizedBox(width: 4),
            Text('${capsule.latitude.toStringAsFixed(4)}, ${capsule.longitude.toStringAsFixed(4)}', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 12),
            Icon(Icons.calendar_today_outlined, size: 13, color: scheme.onSurface.withAlpha(120)),
            const SizedBox(width: 4),
            Text(unlockDate != null ? _fmtDate(unlockDate) : '', style: Theme.of(context).textTheme.labelSmall),
          ]),
          if (!isLocked && capsule.message != null) ...[
            const SizedBox(height: 10),
            Text(capsule.message!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14), maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          if (isLocked) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.near_me_outlined, size: 13, color: scheme.onSurface.withAlpha(120)),
              const SizedBox(width: 4),
              Text('Within ${capsule.proximityTolerance}m to unlock', style: Theme.of(context).textTheme.labelSmall),
            ]),
          ],
          if (!isLocked && capsule.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: capsule.media.length,
                itemBuilder: (ctx, i) {
                  final url = capsule.media[i].fileUrl.startsWith('http')
                      ? capsule.media[i].fileUrl
                      : '${ApiConstants.uploadsBase}/${capsule.media[i].fileUrl}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(imageUrl: url, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
