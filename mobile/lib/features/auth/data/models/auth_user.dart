/// Server `user` object.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatar,
    required this.plan,
    required this.isEmailVerified,
  });

  final String id;
  final String email;
  final String displayName;
  final String avatar;

  /// `'free'` or `'premium'`.
  final String plan;
  final bool isEmailVerified;

  bool get isPremium => plan == 'premium';

  /// First word of the display name ("Alice Smith" → "Alice").
  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? displayName : parts.first;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
      plan: (json['plan'] ?? 'free').toString(),
      isEmailVerified: json['isEmailVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatar': avatar,
        'plan': plan,
        'isEmailVerified': isEmailVerified,
      };

  AuthUser copyWith({String? plan, String? displayName, String? avatar}) =>
      AuthUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        avatar: avatar ?? this.avatar,
        plan: plan ?? this.plan,
        isEmailVerified: isEmailVerified,
      );
}
