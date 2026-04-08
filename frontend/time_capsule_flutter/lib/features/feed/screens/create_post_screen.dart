import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/feed_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/glass_button.dart';
import '../widgets/tag_friend_picker.dart';
import '../../../shared/widgets/avatar_widget.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? initialImagePath;
  const CreatePostScreen({super.key, this.initialImagePath});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  File? _image;
  bool _loading = false;
  List<TagUser> _taggedUsers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _image = File(widget.initialImagePath!);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (res != null) setState(() => _image = File(res.path));
  }

  Future<void> _pickTags() async {
    final result = await TagFriendPicker.show(context, selected: _taggedUsers);
    if (result != null) {
      setState(() => _taggedUsers = result);
    }
  }

  Future<void> _submit() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final formMap = <String, dynamic>{
        'content': text,
        if (_image != null)
          'mediaFile': await MultipartFile.fromFile(
            _image!.path,
            filename: 'post.jpg',
          ),
        if (_taggedUsers.isNotEmpty)
          'taggedUserIds': _taggedUsers.map((u) => u.id).join(','),
      };
      final form = FormData.fromMap(formMap);
      await dioClient.post('/posts', data: form);
      await ref.read(feedProvider.notifier).fetchFeed(refresh: true);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create post')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            if (_image != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _image!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _image = null),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image_outlined, color: scheme.primary),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: Icon(
                    Icons.person_add_alt_1_outlined,
                    color: scheme.primary,
                  ),
                  onPressed: _pickTags,
                  tooltip: 'Tag friends',
                ),
                const Spacer(),
                GlassButton(
                  title: 'Post',
                  onPressed: _submit,
                  loading: _loading,
                ),
              ],
            ),
            // Tagged users chips
            if (_taggedUsers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _taggedUsers
                    .map(
                      (u) => Chip(
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
                        onDeleted: () => setState(() => _taggedUsers.remove(u)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
