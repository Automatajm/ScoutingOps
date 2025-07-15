class Plaga {
  final int? pmpl_id;
  String? pmpl_nombrecomun;
  String? pmpl_genero;
  String? pmpl_familia;
  String? pmpl_tipo;
  int? pmpl_estatus;
  int? pmpl_creadopor;
  DateTime? pmpl_fechacreacion;
  int? pmpl_modificadopor;
  DateTime? pmpl_fechamodificacion;

  Plaga({
    this.pmpl_id,
    this.pmpl_nombrecomun,
    this.pmpl_genero,
    this.pmpl_familia,
    this.pmpl_tipo,
    this.pmpl_estatus,
    this.pmpl_creadopor,
    this.pmpl_fechacreacion,
    this.pmpl_modificadopor,
    this.pmpl_fechamodificacion,
  });

  // Método para crear una copia de la plaga con algunos campos modificados
  Plaga copyWith({
    int? pmpl_id,
    String? pmpl_nombrecomun,
    String? pmpl_genero,
    String? pmpl_familia,
    String? pmpl_tipo,
    int? pmpl_estatus,
    int? pmpl_creadopor,
    DateTime? pmpl_fechacreacion,
    int? pmpl_modificadopor,
    DateTime? pmpl_fechamodificacion,
  }) {
    return Plaga(
      pmpl_id: pmpl_id ?? this.pmpl_id,
      pmpl_nombrecomun: pmpl_nombrecomun ?? this.pmpl_nombrecomun,
      pmpl_genero: pmpl_genero ?? this.pmpl_genero,
      pmpl_familia: pmpl_familia ?? this.pmpl_familia,
      pmpl_tipo: pmpl_tipo ?? this.pmpl_tipo,
      pmpl_estatus: pmpl_estatus ?? this.pmpl_estatus,
      pmpl_creadopor: pmpl_creadopor ?? this.pmpl_creadopor,
      pmpl_fechacreacion: pmpl_fechacreacion ?? this.pmpl_fechacreacion,
      pmpl_modificadopor: pmpl_modificadopor ?? this.pmpl_modificadopor,
      pmpl_fechamodificacion:
          pmpl_fechamodificacion ?? this.pmpl_fechamodificacion,
    );
  }

  // Convertir JSON a objeto Plaga
  factory Plaga.fromJson(Map<String, dynamic> json) {
    return Plaga(
      pmpl_id: json['pmpl_id'],
      pmpl_nombrecomun: json['pmpl_nombrecomun'],
      pmpl_genero: json['pmpl_genero'],
      pmpl_familia: json['pmpl_familia'],
      pmpl_tipo: json['pmpl_tipo'],
      pmpl_estatus: json['pmpl_estatus'],
      pmpl_creadopor: json['pmpl_creadopor'],
      pmpl_fechacreacion: json['pmpl_fechacreacion'] != null
          ? DateTime.parse(json['pmpl_fechacreacion'])
          : null,
      pmpl_modificadopor: json['pmpl_modificadopor'],
      pmpl_fechamodificacion: json['pmpl_fechamodificacion'] != null
          ? DateTime.parse(json['pmpl_fechamodificacion'])
          : null,
    );
  }

  // Convertir objeto Plaga a JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'pmpl_nombrecomun': pmpl_nombrecomun,
      'pmpl_genero': pmpl_genero,
      'pmpl_familia': pmpl_familia,
      'pmpl_tipo': pmpl_tipo,
      'pmpl_estatus': pmpl_estatus,
    };

    // Solo incluir estos campos si no son nulos
    if (pmpl_id != null) data['pmpl_id'] = pmpl_id;
    if (pmpl_creadopor != null) data['pmpl_creadopor'] = pmpl_creadopor;
    if (pmpl_fechacreacion != null)
      data['pmpl_fechacreacion'] = pmpl_fechacreacion!.toIso8601String();
    if (pmpl_modificadopor != null)
      data['pmpl_modificadopor'] = pmpl_modificadopor;
    if (pmpl_fechamodificacion != null)
      data['pmpl_fechamodificacion'] =
          pmpl_fechamodificacion!.toIso8601String();

    return data;
  }
}
