import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/avatar_widget.dart';

/// A simple friend/user model for tagging.
class TagUser {
  final String id;
  final String displayName;
  final String? profilePictureUrl;

  const TagUser({
    required this.id,
    required this.displayName,
    this.profilePictureUrl,
  });

  @override
  bool operator ==(Object other) => other is TagUser && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Bottom-sheet widget to search and pick friends/users to tag.
class TagFriendPicker extends StatefulWidget {
  final List<TagUser> alreadySelected;

  const TagFriendPicker({super.key, this.alreadySelected = const []});

  /// Show as bottom-sheet and return selected users (or null on cancel).
  static Future<List<TagUser>?> show(
    BuildContext context, {
    List<TagUser> selected = const [],
  }) {
    return showModalBottomSheet<List<TagUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagFriendPicker(alreadySelected: selected),
    );
  }

  @override
  State<TagFriendPicker> createState() => _TagFriendPickerState();
}

class _TagFriendPickerState extends State<TagFriendPicker> {
  final _searchCtrl = TextEditingController();
  List<TagUser> _results = [];
  late Set<TagUser> _selected;
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.alreadySelected);
    _loadFriends();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final res = await dioClient.get('/friends');
      final list = res.data as List<dynamic>? ?? [];
      setState(() {
        _results = list
            .map(
              (e) => TagUser(
                id: (e['friendId'] ?? e['id'] ?? '') as String,
                displayName:
                    (e['displayName'] ?? e['friendName'] ?? 'Unknown')
                        as String,
                profilePictureUrl:
                    (e['profilePictureUrl'] ?? e['friendProfilePicture'])
                        as String?,
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _loadFriends();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      try {
        final res = await dioClient.get(
          '/users/search',
          queryParameters: {'query': query.trim()},
        );
        final list = res.data as List<dynamic>? ?? [];
        setState(() {
          _results = list
              .map(
                (e) => TagUser(
                  id: (e['id'] ?? '') as String,
                  displayName: (e['displayName'] ?? 'Unknown') as String,
                  profilePictureUrl: e['profilePictureUrl'] as String?,
                ),
              )
              .toList();
          _loading = false;
        });
      } catch (_) {
        setState(() => _loading = false);
      }
    });
  }

  void _toggle(TagUser user) {
    setState(() {
      if (_selected.contains(user)) {
        _selected.remove(user);
      } else {
        _selected.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title + Done
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Tag Friends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    'Done (${_selected.length})',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Selected chips
          if (_selected.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final u = _selected.elementAt(i);
                  return Chip(
                    avatar: AvatarWidget(
                      url: u.profilePictureUrl,
                      name: u.displayName,
                      radius: 12,
                    ),
                    label: Text(
                      u.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _toggle(u),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              ),
            ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const Divider(),
          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Text(
                      'No users found',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final user = _results[i];
                      final isSelected = _selected.contains(user);
                      return ListTile(
                        leading: AvatarWidget(
                          url: user.profilePictureUrl,
                          name: user.displayName,
                          radius: 20,
                        ),
                        title: Text(user.displayName),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: scheme.primary)
                            : Icon(
                                Icons.circle_outlined,
                                color: scheme.onSurface.withAlpha(60),
                              ),
                        onTap: () => _toggle(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
