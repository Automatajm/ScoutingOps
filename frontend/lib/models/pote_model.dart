class Pote {
  final int id;
  final String codigo;
  final String? contenedor;
  final int? estatus;
  final String? fechaCreacion;
  final String? fechaModificacion;
  final int? creadoPor;
  final int? modificadoPor;

  Pote({
    required this.id,
    required this.codigo,
    this.contenedor,
    this.estatus = 1,
    this.fechaCreacion,
    this.fechaModificacion,
    this.creadoPor,
    this.modificadoPor,
  });

  // Constructor de fábrica para crear un nuevo pote
  factory Pote.newPote({
    required String codigo,
    String? contenedor,
    int? creadoPor,
  }) {
    return Pote(
      id: 0, // ID temporal, será asignado por la base de datos
      codigo: codigo,
      contenedor: contenedor,
      estatus: 1, // Por defecto activo
      creadoPor: creadoPor ?? 1, // Default creador
    );
  }

  // Método para clonar un pote con algunos campos modificados
  Pote copyWith({
    int? id,
    String? codigo,
    String? contenedor,
    int? estatus,
    String? fechaCreacion,
    String? fechaModificacion,
    int? creadoPor,
    int? modificadoPor,
  }) {
    return Pote(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      contenedor: contenedor ?? this.contenedor,
      estatus: estatus ?? this.estatus,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      creadoPor: creadoPor ?? this.creadoPor,
      modificadoPor: modificadoPor ?? this.modificadoPor,
    );
  }

  // Factory para construir un Pote desde un mapa (JSON)
  factory Pote.fromJson(Map<String, dynamic> json) {
    return Pote(
      id: json['id'] ?? json['pmpo_id'],
      codigo: json['codigo'] ?? json['pmpo_codigo'],
      contenedor: json['contenedor'] ?? json['pmpo_contenedor'],
      estatus: json['estatus'] ?? json['pmpo_estatus'] ?? 1,
      fechaCreacion: json['fechaCreacion'] ?? json['pmpo_fechacreacion'],
      fechaModificacion:
          json['fechaModificacion'] ?? json['pmpo_fechamodificacion'],
      creadoPor: json['creadoPor'] ?? json['pmpo_creadopor'],
      modificadoPor: json['modificadoPor'] ?? json['pmpo_modificadopor'],
    );
  }

  // Convertir a un mapa (JSON) - para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      'pmpo_codigo': codigo,
      'pmpo_contenedor': contenedor,
      'pmpo_estatus': estatus,
      'pmpo_creadopor': creadoPor,
      'pmpo_modificadopor': modificadoPor,
    };
  }
}
