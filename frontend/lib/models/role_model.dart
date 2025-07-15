class Role {
  final int id;
  final String descripcion;
  final String? fechaCreacion;
  final String? fechaModificacion;
  final int? creadoPor;
  final int? modificadoPor;
  final int? estatus;

  Role({
    required this.id,
    required this.descripcion,
    this.fechaCreacion,
    this.fechaModificacion,
    this.creadoPor,
    this.modificadoPor,
    this.estatus = 1,
  });

  // Constructor de fábrica para crear una nueva instancia
  factory Role.newRole({
    required String descripcion,
    int? creadoPor,
  }) {
    return Role(
      id: 0, // ID temporal, será asignado por la base de datos
      descripcion: descripcion,
      creadoPor: creadoPor ?? 1, // Default creador
      estatus: 1, // Por defecto activo
    );
  }

  // Método para clonar un rol con algunos campos modificados
  Role copyWith({
    int? id,
    String? descripcion,
    String? fechaCreacion,
    String? fechaModificacion,
    int? creadoPor,
    int? modificadoPor,
    int? estatus,
  }) {
    return Role(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      creadoPor: creadoPor ?? this.creadoPor,
      modificadoPor: modificadoPor ?? this.modificadoPor,
      estatus: estatus ?? this.estatus,
    );
  }

  // Factory para construir un Role desde un mapa (JSON)
  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      descripcion: json['descripcion'],
      fechaCreacion: json['fechaCreacion'],
      fechaModificacion: json['fechaModificacion'],
      creadoPor: json['creadoPor'],
      modificadoPor: json['modificadoPor'],
      estatus: json['estatus'],
    );
  }

  // Convertir a un mapa (JSON) - para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
      'creadoPor': creadoPor,
      'modificadoPor': modificadoPor,
      'estatus': estatus,
    };
  }
}
