class PmPlan {
  // secuencia es el ID principal (clave primaria) en la base de datos
  final int secuencia;
  // código de la unidad de cultivo (del pm_unidadescultivo)
  final String unidadCodigo;
  // cantero de la unidad de cultivo (del pm_unidadescultivo)
  final String unidadCantero;
  // ubicación donde se planifica ('Sabana de la mar' / 'La Romana')
  final String ubicacion;
  // estado de planificación ('Planificado' / 'En proceso' / 'Ejecutado')
  final String estadoPlanificacion;
  // estado del registro (activo/inactivo para habilitar/deshabilitar)
  final int estatus;
  // fecha que se actualiza automáticamente al cambiar a 'Ejecutado'
  final String? fechaEjecucion;
  // campos de auditoría
  final int? creadoPor;
  final String? fechaCreacion;
  final int? modificadoPor;
  final String? fechaModificacion;

  PmPlan({
    required this.secuencia,
    required this.unidadCodigo,
    required this.unidadCantero,
    required this.ubicacion,
    required this.estadoPlanificacion,
    required this.estatus,
    this.fechaEjecucion,
    this.creadoPor,
    this.fechaCreacion,
    this.modificadoPor,
    this.fechaModificacion,
  });

  // Método para crear una copia del plan con algunos campos modificados
  PmPlan copyWith({
    int? secuencia,
    String? unidadCodigo,
    String? unidadCantero,
    String? ubicacion,
    String? estadoPlanificacion,
    int? estatus,
    String? fechaEjecucion,
    int? creadoPor,
    String? fechaCreacion,
    int? modificadoPor,
    String? fechaModificacion,
  }) {
    return PmPlan(
      secuencia: secuencia ?? this.secuencia,
      unidadCodigo: unidadCodigo ?? this.unidadCodigo,
      unidadCantero: unidadCantero ?? this.unidadCantero,
      ubicacion: ubicacion ?? this.ubicacion,
      estadoPlanificacion: estadoPlanificacion ?? this.estadoPlanificacion,
      estatus: estatus ?? this.estatus,
      fechaEjecucion: fechaEjecucion ?? this.fechaEjecucion,
      creadoPor: creadoPor ?? this.creadoPor,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      modificadoPor: modificadoPor ?? this.modificadoPor,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
    );
  }

  // Convertir JSON a objeto PmPlan
  factory PmPlan.fromJson(Map<String, dynamic> json) {
    return PmPlan(
      secuencia: json['secuencia'] ?? 0,
      unidadCodigo: json['unidad_codigo'] ?? '',
      unidadCantero: json['unidad_cantero'] ?? '',
      ubicacion: json['ubicacion'] ?? '',
      estadoPlanificacion: json['estado_planificacion'] ?? 'Planificado',
      estatus: json['estatus'] ?? 1,
      fechaEjecucion: json['fecha_ejecucion'],
      creadoPor: json['creadopor'],
      fechaCreacion: json['fechacreacion'],
      modificadoPor: json['modificadopor'],
      fechaModificacion: json['fechamodificacion'],
    );
  }

  // Convertir objeto PmPlan a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'unidad_codigo': unidadCodigo,
      'unidad_cantero': unidadCantero,
      'ubicacion': ubicacion,
      'estado_planificacion': estadoPlanificacion,
      'estatus': estatus,
    };

    // Solo incluir estos campos si no son nulos o tienen valores específicos
    if (secuencia > 0) data['secuencia'] = secuencia;
    if (fechaEjecucion != null) data['fecha_ejecucion'] = fechaEjecucion;
    if (creadoPor != null) data['creadopor'] = creadoPor;
    if (modificadoPor != null) data['modificadopor'] = modificadoPor;

    return data;
  }

  // Constructor para planes nuevos (sin secuencia/ID de BD)
  factory PmPlan.nuevo({
    required String unidadCodigo,
    required String unidadCantero,
    required String ubicacion,
    String estadoPlanificacion = 'Planificado',
    int estatus = 1,
    int creadoPor = 1,
  }) {
    return PmPlan(
      secuencia: 0, // Secuencia temporal hasta que se asigne en la BD
      unidadCodigo: unidadCodigo,
      unidadCantero: unidadCantero,
      ubicacion: ubicacion,
      estadoPlanificacion: estadoPlanificacion,
      estatus: estatus,
      creadoPor: creadoPor,
    );
  }

  // Constructor para crear plan desde UnidadCultivo
  factory PmPlan.fromUnidadCultivo({
    required String codigo,
    required String cantero,
    required String ubicacion,
    int creadoPor = 1,
  }) {
    return PmPlan(
      secuencia: 0,
      unidadCodigo: codigo,
      unidadCantero: cantero,
      ubicacion: ubicacion,
      estadoPlanificacion: 'Planificado',
      estatus: 1,
      creadoPor: creadoPor,
    );
  }

  // Método para verificar si el plan está ejecutado
  bool get isEjecutado => estadoPlanificacion == 'Ejecutado';

  // Método para verificar si el plan está activo
  bool get isActivo => estatus == 1;

  // Método para obtener el color según el estado de planificación
  String get colorEstado {
    switch (estadoPlanificacion) {
      case 'Planificado':
        return '#FFA726'; // Naranja
      case 'En proceso':
        return '#42A5F5'; // Azul
      case 'Ejecutado':
        return '#66BB6A'; // Verde
      default:
        return '#9E9E9E'; // Gris
    }
  }

  @override
  String toString() {
    return 'PmPlan{secuencia: $secuencia, unidadCodigo: $unidadCodigo, '
        'unidadCantero: $unidadCantero, ubicacion: $ubicacion, '
        'estadoPlanificacion: $estadoPlanificacion, estatus: $estatus}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PmPlan &&
          runtimeType == other.runtimeType &&
          secuencia == other.secuencia;

  @override
  int get hashCode => secuencia.hashCode;
}
