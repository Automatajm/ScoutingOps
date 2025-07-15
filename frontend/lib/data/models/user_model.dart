// This file defines the UserModel class, which represents a user in the system.
// It includes properties like id, username, name, email, roles, and methods to check user roles.
class UserModel {
  final int id;
  final int codigo;
  final String username;
  final String name;
  final String? email;
  final int funcion; // Representa el rol del usuario
  final List<String> roles; // Lista de roles (para mayor flexibilidad)
  final String? token;
  final int estatus;

  UserModel({
    required this.id,
    required this.codigo,
    required this.username,
    this.name = '',
    this.email,
    required this.funcion,
    required this.roles,
    this.token,
    this.estatus = 1,
  });

  // Método para verificar si el usuario tiene un rol específico
  bool hasRole(String role) {
    return roles.contains(role.toLowerCase());
  }

  // Métodos de conveniencia para verificar roles comunes
  bool get isMonitoreador => hasRole('monitoreador') || funcion == 4;
  bool get isAdmin => hasRole('admin') || funcion == 1;

  // Método para crear una copia del modelo con algunos cambios
  UserModel copyWith({
    int? id,
    int? codigo,
    String? username,
    String? name,
    String? email,
    int? funcion,
    List<String>? roles,
    String? token,
    int? estatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      funcion: funcion ?? this.funcion,
      roles: roles ?? this.roles,
      token: token ?? this.token,
      estatus: estatus ?? this.estatus,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Manejo flexible de roles (pueden venir como lista o como string separado por comas)
    List<String> parseRoles(dynamic rolesData) {
      if (rolesData == null) {
        // Si no hay datos de roles, asignar basado en el campo funcion
        final funcion = map['pmus_funcion'] ?? map['funcion'] ?? 1;
        if (funcion == 1) return ['admin'];
        if (funcion == 4) return ['monitoreador'];
        return [];
      }
      if (rolesData is List)
        return List<String>.from(
            rolesData.map((r) => r.toString().toLowerCase()));
      if (rolesData is String)
        return rolesData.split(',').map((r) => r.trim().toLowerCase()).toList();
      return [];
    }

    // Obtener el valor de funcion
    final funcion = map['pmus_funcion'] ?? map['funcion'] ?? 1;

    // Definir los roles basados en funcion si no vienen explícitamente
    final roles = parseRoles(map['roles']);

    return UserModel(
      id: map['pmus_id'] ?? map['id'] ?? 0,
      codigo: map['pmus_codigo'] ?? map['codigo'] ?? 0,
      username: map['pmus_usuario'] ?? map['usuario'] ?? map['username'] ?? '',
      name: map['nombre'] ?? map['name'] ?? '',
      email: map['pmus_correo'] ?? map['correo'] ?? map['email'],
      funcion: funcion,
      roles: roles,
      token: map['token'],
      estatus: map['pmus_estatus'] ?? map['estatus'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'username': username,
      'name': name,
      'email': email,
      'funcion': funcion,
      'roles': roles,
      'token': token,
      'estatus': estatus,
    };
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, funcion: $funcion, roles: $roles)';
  }
}
