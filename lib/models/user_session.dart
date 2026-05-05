import 'user_role.dart';

class UserSession {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const UserSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: UserRoleX.parse(json['role'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.wire,
      };
}
