import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gameroom_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_input.dart';

class CreateGameRoomScreen extends ConsumerStatefulWidget {
  const CreateGameRoomScreen({super.key});

  @override
  ConsumerState<CreateGameRoomScreen> createState() => _CreateGameRoomScreenState();
}

class _CreateGameRoomScreenState extends ConsumerState<CreateGameRoomScreen> {
  final _titleCtrl = TextEditingController();
  bool _isPublic = true;
  bool _loading = false;
  String? _titleError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty ? 'Title is required' : null;
    });
    if (_titleError != null) return;

    setState(() => _loading = true);
    try {
      await dioClient.post('/gamerooms', data: {
        'title': _titleCtrl.text.trim(),
        'isPublic': _isPublic,
      });
      // Invalidate providers so lists refresh
      ref.invalidate(publicGameRoomsProvider);
      ref.invalidate(myGameRoomsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create game room')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New Game Room')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Room Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Create a treasure hunt room for other players to join.',
                    style: TextStyle(fontSize: 13, color: scheme.onSurface.withAlpha(150))),
              ]),
            ),
            const SizedBox(height: 16),
            GlassInput(
              label: 'Room Title',
              hint: 'e.g. Downtown Treasure Hunt',
              controller: _titleCtrl,
              errorText: _titleError,
              onBlur: () => setState(() {
                _titleError = _titleCtrl.text.trim().isEmpty ? 'Title is required' : null;
              }),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Row(children: [
                Icon(Icons.public_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Public Room', style: Theme.of(context).textTheme.bodyLarge),
                  Text('Anyone can discover and join',
                      style: TextStyle(fontSize: 12, color: scheme.onSurface.withAlpha(150))),
                ])),
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: scheme.primary,
                ),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('How it works', style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                for (final step in [
                  '1. Create this room',
                  '2. Create capsules and assign them to this room',
                  '3. Players discover and unlock capsules to earn points',
                  '4. See who tops the leaderboard!',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(step, style: TextStyle(fontSize: 13,
                        color: scheme.onSurface.withAlpha(180))),
                  ),
              ]),
            ),
            const SizedBox(height: 24),
            GlassButton(
              title: 'Create Room',
              onPressed: _create,
              loading: _loading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
