class User {
  final int id;
  final String name;
  final String email;
  final String role;

  User({required this.id, required this.name, required this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'user',
      );

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  String get roleLabel {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin': return 'Quản trị';
      default: return 'Người dùng';
    }
  }
}
