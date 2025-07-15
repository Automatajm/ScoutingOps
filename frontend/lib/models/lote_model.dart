class Lote {
  final int? pmlt_secuencia;
  String? pmlt_codigo;
  String? pmlt_canteros;
  int? pmlt_cantidad;
  int? pmlt_estatus;
  int? pmlt_idvariedad;
  DateTime? pmlt_fechacreacion;
  String? pmlt_contenedor;
  DateTime? pmlt_fechamodificacion;
  int? pmlt_creadopor;
  String? pmlt_grower;
  String? pmlt_variedad;
  String? pmlt_casa;
  int? pmlt_modificadopor;

  Lote({
    this.pmlt_secuencia,
    this.pmlt_codigo,
    this.pmlt_canteros,
    this.pmlt_cantidad,
    this.pmlt_estatus,
    this.pmlt_idvariedad,
    this.pmlt_fechacreacion,
    this.pmlt_contenedor,
    this.pmlt_fechamodificacion,
    this.pmlt_creadopor,
    this.pmlt_grower,
    this.pmlt_variedad,
    this.pmlt_casa,
    this.pmlt_modificadopor,
  });

  // Método para crear una copia del lote con algunos campos modificados
  Lote copyWith({
    int? pmlt_secuencia,
    String? pmlt_codigo,
    String? pmlt_canteros,
    int? pmlt_cantidad,
    int? pmlt_estatus,
    int? pmlt_idvariedad,
    DateTime? pmlt_fechacreacion,
    String? pmlt_contenedor,
    DateTime? pmlt_fechamodificacion,
    int? pmlt_creadopor,
    String? pmlt_grower,
    String? pmlt_variedad,
    String? pmlt_casa,
    int? pmlt_modificadopor,
  }) {
    return Lote(
      pmlt_secuencia: pmlt_secuencia ?? this.pmlt_secuencia,
      pmlt_codigo: pmlt_codigo ?? this.pmlt_codigo,
      pmlt_canteros: pmlt_canteros ?? this.pmlt_canteros,
      pmlt_cantidad: pmlt_cantidad ?? this.pmlt_cantidad,
      pmlt_estatus: pmlt_estatus ?? this.pmlt_estatus,
      pmlt_idvariedad: pmlt_idvariedad ?? this.pmlt_idvariedad,
      pmlt_fechacreacion: pmlt_fechacreacion ?? this.pmlt_fechacreacion,
      pmlt_contenedor: pmlt_contenedor ?? this.pmlt_contenedor,
      pmlt_fechamodificacion:
          pmlt_fechamodificacion ?? this.pmlt_fechamodificacion,
      pmlt_creadopor: pmlt_creadopor ?? this.pmlt_creadopor,
      pmlt_grower: pmlt_grower ?? this.pmlt_grower,
      pmlt_variedad: pmlt_variedad ?? this.pmlt_variedad,
      pmlt_casa: pmlt_casa ?? this.pmlt_casa,
      pmlt_modificadopor: pmlt_modificadopor ?? this.pmlt_modificadopor,
    );
  }

  // Convertir JSON a objeto Lote
  factory Lote.fromJson(Map<String, dynamic> json) {
    return Lote(
      pmlt_secuencia: json['pmlt_secuencia'],
      pmlt_codigo: json['pmlt_codigo'],
      pmlt_canteros: json['pmlt_canteros'],
      pmlt_cantidad: json['pmlt_cantidad'],
      pmlt_estatus: json['pmlt_estatus'],
      pmlt_idvariedad: json['pmlt_idvariedad'],
      pmlt_fechacreacion: json['pmlt_fechacreacion'] != null
          ? DateTime.parse(json['pmlt_fechacreacion'])
          : null,
      pmlt_contenedor: json['pmlt_contenedor'],
      pmlt_fechamodificacion: json['pmlt_fechamodificacion'] != null
          ? DateTime.parse(json['pmlt_fechamodificacion'])
          : null,
      pmlt_creadopor: json['pmlt_creadopor'],
      pmlt_grower: json['pmlt_grower'],
      pmlt_variedad: json['pmlt_variedad'],
      pmlt_casa: json['pmlt_casa'],
      pmlt_modificadopor: json['pmlt_modificadopor'],
    );
  }

  // Convertir objeto Lote a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'pmlt_codigo': pmlt_codigo,
      'pmlt_canteros': pmlt_canteros,
      'pmlt_cantidad': pmlt_cantidad,
      'pmlt_estatus': pmlt_estatus,
      'pmlt_idvariedad': pmlt_idvariedad,
      'pmlt_contenedor': pmlt_contenedor,
      'pmlt_grower': pmlt_grower,
      'pmlt_variedad': pmlt_variedad,
      'pmlt_casa': pmlt_casa,
    };

    // Solo incluir estos campos si no son nulos
    if (pmlt_secuencia != null) data['pmlt_secuencia'] = pmlt_secuencia;
    if (pmlt_creadopor != null) data['pmlt_creadopor'] = pmlt_creadopor;
    if (pmlt_fechacreacion != null)
      data['pmlt_fechacreacion'] = pmlt_fechacreacion!.toIso8601String();
    if (pmlt_modificadopor != null)
      data['pmlt_modificadopor'] = pmlt_modificadopor;
    if (pmlt_fechamodificacion != null)
      data['pmlt_fechamodificacion'] =
          pmlt_fechamodificacion!.toIso8601String();

    return data;
  }
}
