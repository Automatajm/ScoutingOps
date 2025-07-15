class User {
  final int id;
  final int codigo;
  final String usuario;
  final int funcion;
  final int estatus;
  final int? creador;
  final String? fechaCreacion;
  final int? modificador;
  final String? fechaModificacion;
  final String? password;
  final String? correo;
  final String? telefono;
  final String? rolDescripcion; // Para mostrar el nombre del rol en la UI

  User({
    required this.id,
    required this.codigo,
    required this.usuario,
    required this.funcion,
    required this.estatus,
    this.creador,
    this.fechaCreacion,
    this.modificador,
    this.fechaModificacion,
    this.password,
    this.correo,
    this.telefono,
    this.rolDescripcion,
  });

  // Método para crear una copia del usuario con algunos campos modificados
  User copyWith({
    int? id,
    int? codigo,
    String? usuario,
    int? funcion,
    int? estatus,
    int? creador,
    String? fechaCreacion,
    int? modificador,
    String? fechaModificacion,
    String? password,
    String? correo,
    String? telefono,
    String? rolDescripcion,
  }) {
    return User(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      usuario: usuario ?? this.usuario,
      funcion: funcion ?? this.funcion,
      estatus: estatus ?? this.estatus,
      creador: creador ?? this.creador,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      modificador: modificador ?? this.modificador,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      password: password ?? this.password,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      rolDescripcion: rolDescripcion ?? this.rolDescripcion,
    );
  }

  // Convertir JSON a objeto User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      codigo: json['codigo'] ?? 0,
      usuario: json['usuario'] ?? '',
      funcion: json['funcion'] ?? 1,
      estatus: json['estatus'] ?? 1,
      creador: json['creador'],
      fechaCreacion: json['fechacreacion'],
      modificador: json['modificador'],
      fechaModificacion: json['fechamodificacion'],
      password: json['password'],
      correo: json['correo'],
      telefono: json['telefono'],
      rolDescripcion: json['rol_descripcion'],
    );
  }

  // Convertir objeto User a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'codigo': codigo,
      'usuario': usuario,
      'funcion': funcion,
      'estatus': estatus,
    };

    // Solo incluir estos campos si no son nulos
    if (id > 0) data['id'] = id;
    if (creador != null) data['creador'] = creador;
    if (modificador != null) data['modificador'] = modificador;
    if (password != null) data['password'] = password;
    if (correo != null) data['correo'] = correo;
    if (telefono != null) data['telefono'] = telefono;

    return data;
  }

  // Constructor para usuarios nuevos (sin ID)
  factory User.newUser({
    required String usuario,
    required int funcion,
    required String password,
    int codigo = 0,
    int estatus = 1,
    String? correo,
    String? telefono,
    int creador = 1,
  }) {
    return User(
      id: 0, // ID temporal hasta que se obtenga de la BD
      codigo: codigo,
      usuario: usuario,
      funcion: funcion,
      estatus: estatus,
      password: password,
      correo: correo,
      telefono: telefono,
      creador: creador,
    );
  }
}
