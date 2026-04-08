class ProfileModel {
  final String id;
  final String displayName;
  final String email;
  final String? profilePictureUrl;
  final String? bio;
  final int capsuleCount;
  final int postCount;
  final String createdAt;

  const ProfileModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.profilePictureUrl,
    this.bio,
    required this.capsuleCount,
    required this.postCount,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> j) => ProfileModel(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        email: j['email'] as String? ?? '',
        profilePictureUrl: j['profilePictureUrl'] as String?,
        bio: j['bio'] as String?,
        capsuleCount: j['capsuleCount'] as int? ?? 0,
        postCount: j['postCount'] as int? ?? 0,
        createdAt: j['createdAt'] as String? ?? '',
      );
}
