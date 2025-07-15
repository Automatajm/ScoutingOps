class NivelInfestacion {
  final int? pmni_secuencia;
  final int? pmni_nivel;
  final int? pmni_plaga;
  final String? pmni_nombrecomun;
  final String? pmni_rango;
  final int? pmni_lminferior;
  final int? pmni_lmsuperior;
  final String? pmni_tipoobservacion;
  final String? pmni_observacion;
  final String? pmni_cintaidentificadora;
  final int? pmni_estatus;
  final int? pmni_creadopor;
  final DateTime? pmni_fechacreacion;
  final int? pmni_modificadopor;
  final DateTime? pmni_fechamodificacion;

  const NivelInfestacion({
    this.pmni_secuencia,
    this.pmni_nivel,
    this.pmni_plaga,
    this.pmni_nombrecomun,
    this.pmni_rango,
    this.pmni_lminferior,
    this.pmni_lmsuperior,
    this.pmni_tipoobservacion,
    this.pmni_observacion,
    this.pmni_cintaidentificadora,
    this.pmni_estatus,
    this.pmni_creadopor,
    this.pmni_fechacreacion,
    this.pmni_modificadopor,
    this.pmni_fechamodificacion,
  });

  // Método para crear una copia del nivel con algunos campos modificados
  NivelInfestacion copyWith({
    int? pmni_secuencia,
    int? pmni_nivel,
    int? pmni_plaga,
    String? pmni_nombrecomun,
    String? pmni_rango,
    int? pmni_lminferior,
    int? pmni_lmsuperior,
    String? pmni_tipoobservacion,
    String? pmni_observacion,
    String? pmni_cintaidentificadora,
    int? pmni_estatus,
    int? pmni_creadopor,
    DateTime? pmni_fechacreacion,
    int? pmni_modificadopor,
    DateTime? pmni_fechamodificacion,
  }) {
    return NivelInfestacion(
      pmni_secuencia: pmni_secuencia ?? this.pmni_secuencia,
      pmni_nivel: pmni_nivel ?? this.pmni_nivel,
      pmni_plaga: pmni_plaga ?? this.pmni_plaga,
      pmni_nombrecomun: pmni_nombrecomun ?? this.pmni_nombrecomun,
      pmni_rango: pmni_rango ?? this.pmni_rango,
      pmni_lminferior: pmni_lminferior ?? this.pmni_lminferior,
      pmni_lmsuperior: pmni_lmsuperior ?? this.pmni_lmsuperior,
      pmni_tipoobservacion: pmni_tipoobservacion ?? this.pmni_tipoobservacion,
      pmni_observacion: pmni_observacion ?? this.pmni_observacion,
      pmni_cintaidentificadora:
          pmni_cintaidentificadora ?? this.pmni_cintaidentificadora,
      pmni_estatus: pmni_estatus ?? this.pmni_estatus,
      pmni_creadopor: pmni_creadopor ?? this.pmni_creadopor,
      pmni_fechacreacion: pmni_fechacreacion ?? this.pmni_fechacreacion,
      pmni_modificadopor: pmni_modificadopor ?? this.pmni_modificadopor,
      pmni_fechamodificacion:
          pmni_fechamodificacion ?? this.pmni_fechamodificacion,
    );
  }

  // Convertir JSON a objeto NivelInfestacion
  factory NivelInfestacion.fromJson(Map<String, dynamic> json) {
    return NivelInfestacion(
      pmni_secuencia: json['pmni_secuencia'],
      pmni_nivel: json['pmni_nivel'],
      pmni_plaga: json['pmni_plaga'],
      pmni_nombrecomun: json['pmni_nombrecomun'],
      pmni_rango: json['pmni_rango'],
      pmni_lminferior: json['pmni_lminferior'],
      pmni_lmsuperior: json['pmni_lmsuperior'],
      pmni_tipoobservacion: json['pmni_tipoobservacion'],
      pmni_observacion: json['pmni_observacion'],
      pmni_cintaidentificadora: json['pmni_cintaidentificadora'],
      pmni_estatus: json['pmni_estatus'],
      pmni_creadopor: json['pmni_creadopor'],
      pmni_fechacreacion: json['pmni_fechacreacion'] != null
          ? DateTime.parse(json['pmni_fechacreacion'])
          : null,
      pmni_modificadopor: json['pmni_modificadopor'],
      pmni_fechamodificacion: json['pmni_fechamodificacion'] != null
          ? DateTime.parse(json['pmni_fechamodificacion'])
          : null,
    );
  }

  // Convertir objeto NivelInfestacion a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'pmni_nivel': pmni_nivel,
      'pmni_plaga': pmni_plaga,
      'pmni_nombrecomun': pmni_nombrecomun,
      'pmni_rango': pmni_rango,
      'pmni_lminferior': pmni_lminferior,
      'pmni_lmsuperior': pmni_lmsuperior,
      'pmni_tipoobservacion': pmni_tipoobservacion,
      'pmni_observacion': pmni_observacion,
      'pmni_cintaidentificadora': pmni_cintaidentificadora,
      'pmni_estatus': pmni_estatus,
    };

    // Solo incluir estos campos si no son nulos
    if (pmni_secuencia != null) data['pmni_secuencia'] = pmni_secuencia;
    if (pmni_creadopor != null) data['pmni_creadopor'] = pmni_creadopor;
    if (pmni_fechacreacion != null)
      data['pmni_fechacreacion'] = pmni_fechacreacion!.toIso8601String();
    if (pmni_modificadopor != null)
      data['pmni_modificadopor'] = pmni_modificadopor;
    if (pmni_fechamodificacion != null)
      data['pmni_fechamodificacion'] =
          pmni_fechamodificacion!.toIso8601String();

    return data;
  }
}
