/// Modelo de usuario autenticado
class User {
  final String username;
  final String role;
  final String firstName;
  final String lastName;
  final String phone;

  const User({
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.phone = '',
  });

  /// Nombre completo del usuario
  String get fullName => '$firstName $lastName'.trim();

  /// Crear desde JSON (respuesta del servidor)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: (json['username'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }

  /// Convertir a JSON (para guardar en caché)
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
    };
  }

  @override
  String toString() => 'User(username: $username, firstName: $firstName, lastName: $lastName, role: $role, phone: $phone)';
}
