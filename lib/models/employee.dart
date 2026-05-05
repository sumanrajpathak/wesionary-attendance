import 'user_role.dart';

class Employee {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const Employee({
    required this.id,
    required this.name,
    this.email = '',
    this.role = UserRole.user,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
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
