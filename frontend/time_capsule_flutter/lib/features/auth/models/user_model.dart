class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? profilePictureUrl;
  final String? bio;
  final String createdAt;
  final int capsuleCount;
  final int postCount;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.profilePictureUrl,
    this.bio,
    required this.createdAt,
    this.capsuleCount = 0,
    this.postCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'] as String,
    email: j['email'] as String,
    displayName: j['displayName'] as String,
    profilePictureUrl: j['profilePictureUrl'] as String?,
    bio: j['bio'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
    capsuleCount: j['capsuleCount'] as int? ?? 0,
    postCount: j['postCount'] as int? ?? 0,
  );

  UserModel copyWith({
    String? displayName,
    String? profilePictureUrl,
    String? bio,
  }) => UserModel(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    bio: bio ?? this.bio,
    createdAt: createdAt,
    capsuleCount: capsuleCount,
    postCount: postCount,
  );
}

class AuthResponse {
  final String token;
  final UserModel user;
  AuthResponse({required this.token, required this.user});
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
    token: j['token'] as String,
    user: UserModel.fromJson(j['user'] as Map<String, dynamic>),
  );
}
