import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';

class AvatarWidget extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    this.url,
    required this.name,
    this.radius = 20,
    this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String? get _fullUrl {
    if (url == null || url!.isEmpty) return null;
    if (url!.startsWith('http')) return url;
    return '${ApiConstants.uploadsBase}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final widget = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withAlpha(60),
      child: _fullUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: _fullUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (ctx, url, err) => _initialsWidget(scheme),
              ),
            )
          : _initialsWidget(scheme),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }
    return widget;
  }

  Widget _initialsWidget(ColorScheme scheme) => Text(
        _initials,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      );
}
