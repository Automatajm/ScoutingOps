class Variety {
  final int id;
  final String codigo;
  final String descripcion;
  final String? responsable;
  final int? estatus;
  final String? fechaCreacion;
  final String? fechaModificacion;
  final int? creadoPor;
  final int? modificadoPor;

  Variety({
    required this.id,
    required this.codigo,
    required this.descripcion,
    this.responsable,
    this.estatus = 1,
    this.fechaCreacion,
    this.fechaModificacion,
    this.creadoPor,
    this.modificadoPor,
  });

  // Constructor de fábrica para crear una nueva instancia
  factory Variety.newVariety({
    required String codigo,
    required String descripcion,
    String? responsable,
    int? creadoPor,
  }) {
    return Variety(
      id: 0, // ID temporal, será asignado por la base de datos
      codigo: codigo,
      descripcion: descripcion,
      responsable: responsable,
      estatus: 1, // Por defecto activo
      creadoPor: creadoPor ?? 1, // Default creador
    );
  }

  // Método para clonar una variedad con algunos campos modificados
  Variety copyWith({
    int? id,
    String? codigo,
    String? descripcion,
    String? responsable,
    int? estatus,
    String? fechaCreacion,
    String? fechaModificacion,
    int? creadoPor,
    int? modificadoPor,
  }) {
    return Variety(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      responsable: responsable ?? this.responsable,
      estatus: estatus ?? this.estatus,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      creadoPor: creadoPor ?? this.creadoPor,
      modificadoPor: modificadoPor ?? this.modificadoPor,
    );
  }

  // Factory para construir una Variedad desde un mapa (JSON)
  factory Variety.fromJson(Map<String, dynamic> json) {
    return Variety(
      id: json['id'],
      codigo: json['codigo'],
      descripcion: json['descripcion'],
      responsable: json['responsable'],
      estatus: json['estatus'],
      fechaCreacion: json['fechaCreacion'],
      fechaModificacion: json['fechaModificacion'],
      creadoPor: json['creadoPor'],
      modificadoPor: json['modificadoPor'],
    );
  }

  // Convertir a un mapa (JSON) - para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'descripcion': descripcion,
      'responsable': responsable,
      'estatus': estatus,
      'creadoPor': creadoPor,
      'modificadoPor': modificadoPor,
    };
  }
}
