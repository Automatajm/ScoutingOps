class UnidadCultivo {
  // secuencia es el ID principal (clave primaria) en la base de datos
  final int secuencia;
  // código de la unidad de cultivo
  final String codigo;
  // cantero asociado
  final String cantero;
  // id es un identificador externo/referencia
  final int id;
  // estado de la unidad (activo/inactivo)
  final int estatus;
  // campos de auditoría
  final int? creadoPor;
  final String? fechaCreacion;
  final int? modificadoPor;
  final String? fechaModificacion;

  UnidadCultivo({
    required this.secuencia,
    required this.codigo,
    required this.cantero,
    required this.id,
    required this.estatus,
    this.creadoPor,
    this.fechaCreacion,
    this.modificadoPor,
    this.fechaModificacion,
  });

  // Método para crear una copia de la unidad con algunos campos modificados
  UnidadCultivo copyWith({
    int? secuencia,
    String? codigo,
    String? cantero,
    int? id,
    int? estatus,
    int? creadoPor,
    String? fechaCreacion,
    int? modificadoPor,
    String? fechaModificacion,
  }) {
    return UnidadCultivo(
      secuencia: secuencia ?? this.secuencia,
      codigo: codigo ?? this.codigo,
      cantero: cantero ?? this.cantero,
      id: id ?? this.id,
      estatus: estatus ?? this.estatus,
      creadoPor: creadoPor ?? this.creadoPor,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      modificadoPor: modificadoPor ?? this.modificadoPor,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
    );
  }

  // Convertir JSON a objeto UnidadCultivo
  factory UnidadCultivo.fromJson(Map<String, dynamic> json) {
    return UnidadCultivo(
      secuencia: json['secuencia'] ?? 0,
      codigo: json['codigo'] ?? '',
      cantero: json['cantero'] ?? '',
      id: json['id'] ?? 0,
      estatus: json['estatus'] ?? 1,
      creadoPor: json['creadopor'],
      fechaCreacion: json['fechacreacion'],
      modificadoPor: json['modificadopor'],
      fechaModificacion: json['fechamodificacion'],
    );
  }

  // Convertir objeto UnidadCultivo a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'codigo': codigo,
      'cantero': cantero,
      'id': id,
      'estatus': estatus,
    };

    // Solo incluir estos campos si no son nulos o tienen valores específicos
    if (secuencia > 0) data['secuencia'] = secuencia;
    if (creadoPor != null) data['creadopor'] = creadoPor;
    if (modificadoPor != null) data['modificadopor'] = modificadoPor;

    return data;
  }

  // Constructor para unidades nuevas (sin secuencia/ID de BD)
  factory UnidadCultivo.nueva({
    required String codigo,
    required String cantero,
    required int id, // ID externo
    int estatus = 1,
    int creadoPor = 1,
  }) {
    return UnidadCultivo(
      secuencia: 0, // Secuencia temporal hasta que se asigne en la BD
      codigo: codigo,
      cantero: cantero,
      id: id,
      estatus: estatus,
      creadoPor: creadoPor,
    );
  }
}
