/// Modelo de usuario autenticado
class User {
  /// Id del usuario en el backend. Null en sesiones guardadas antes de que el
  /// perfil lo incluyera: se completa con el siguiente login.
  final int? id;
  final String username;
  final String role;
  final String firstName;
  final String lastName;
  final String phone;

  const User({
    this.id,
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.phone = '',
  });

  /// Nombre completo del usuario
  String get fullName => '$firstName $lastName'.trim();

  /// Roles con acceso a la gestión interna (mantenimientos). La API valida lo
  /// mismo y responde 403 a cualquier otro rol.
  bool get isManagerOrAdmin => role == 'admin' || role == 'manager';

  /// Crear desde JSON (respuesta del servidor)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num?)?.toInt(),
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
      'id': id,
      'username': username,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
    };
  }

  @override
  String toString() => 'User(id: $id, username: $username, firstName: $firstName, lastName: $lastName, role: $role, phone: $phone)';
}
