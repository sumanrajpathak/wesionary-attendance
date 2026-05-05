enum UserRole { admin, user }

extension UserRoleX on UserRole {
  String get wire => name;

  static UserRole parse(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    return s == 'admin' ? UserRole.admin : UserRole.user;
  }
}
