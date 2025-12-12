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
  // ubicación de la unidad de cultivo (CAMPO PARA FILTRADO)
  final String? ubicacion;
  // campos de auditoría
  final int? creadoPor;
  final String? fechaCreacion;
  final int? modificadoPor;
  final String? fechaModificacion;

  // ⭐ CAMPO PARA SELECCIÓN EN FILTROS Y UI
  bool? selected;

  UnidadCultivo({
    required this.secuencia,
    required this.codigo,
    required this.cantero,
    required this.id,
    required this.estatus,
    this.ubicacion,
    this.creadoPor,
    this.fechaCreacion,
    this.modificadoPor,
    this.fechaModificacion,
    this.selected, // ⭐ PARÁMETRO PARA SELECCIÓN
  });

  // Método para crear una copia de la unidad con algunos campos modificados
  UnidadCultivo copyWith({
    int? secuencia,
    String? codigo,
    String? cantero,
    int? id,
    int? estatus,
    String? ubicacion,
    int? creadoPor,
    String? fechaCreacion,
    int? modificadoPor,
    String? fechaModificacion,
    bool? selected, // ⭐ PARÁMETRO PARA SELECCIÓN
  }) {
    return UnidadCultivo(
      secuencia: secuencia ?? this.secuencia,
      codigo: codigo ?? this.codigo,
      cantero: cantero ?? this.cantero,
      id: id ?? this.id,
      estatus: estatus ?? this.estatus,
      ubicacion: ubicacion ?? this.ubicacion,
      creadoPor: creadoPor ?? this.creadoPor,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      modificadoPor: modificadoPor ?? this.modificadoPor,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
      selected: selected ?? this.selected, // ⭐ MANTENER SELECCIÓN
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
      ubicacion: json['ubicacion'], // Campo de ubicación
      creadoPor: json['creadopor'],
      fechaCreacion: json['fechacreacion'],
      modificadoPor: json['modificadopor'],
      fechaModificacion: json['fechamodificacion'],
      selected: json['selected'], // ⭐ CAMPO DE SELECCIÓN
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
    if (ubicacion != null && ubicacion!.isNotEmpty) {
      data['ubicacion'] = ubicacion;
    }
    if (creadoPor != null) data['creadopor'] = creadoPor;
    if (modificadoPor != null) data['modificadopor'] = modificadoPor;
    if (selected != null) data['selected'] = selected; // ⭐ INCLUIR SELECCIÓN

    return data;
  }

  // Constructor para unidades nuevas (sin secuencia/ID de BD)
  factory UnidadCultivo.nueva({
    required String codigo,
    required String cantero,
    required int id, // ID externo
    int estatus = 1,
    String? ubicacion, // Campo de ubicación
    int creadoPor = 1,
    bool? selected, // ⭐ CAMPO DE SELECCIÓN
  }) {
    return UnidadCultivo(
      secuencia: 0, // Secuencia temporal hasta que se asigne en la BD
      codigo: codigo,
      cantero: cantero,
      id: id,
      estatus: estatus,
      ubicacion: ubicacion,
      creadoPor: creadoPor,
      selected: selected, // ⭐ INICIALIZAR SELECCIÓN
    );
  }

  // ⭐ MÉTODO PARA VALIDAR SI LA UNIDAD ESTÁ EN UNA UBICACIÓN ESPECÍFICA
  bool isInUbicacion(String? targetUbicacion) {
    if (targetUbicacion == null || targetUbicacion.isEmpty) {
      return ubicacion == null || ubicacion!.isEmpty;
    }
    return ubicacion?.toLowerCase() == targetUbicacion.toLowerCase();
  }

  // ⭐ MÉTODO PARA OBTENER DESCRIPCIÓN COMPLETA
  String get descripcionCompleta {
    final ubicacionText = ubicacion?.isNotEmpty == true ? ' - $ubicacion' : '';
    return '$codigo - $cantero$ubicacionText';
  }

  // ⭐ MÉTODO PARA VERIFICAR SI ESTÁ ACTIVO
  bool get isActivo => estatus == 1;

  // ⭐ MÉTODO PARA OBTENER TEXTO DE ESTADO
  String get estadoTexto => isActivo ? 'Activo' : 'Inactivo';

  @override
  String toString() {
    return 'UnidadCultivo{secuencia: $secuencia, codigo: $codigo, cantero: $cantero, ubicacion: $ubicacion, selected: $selected}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnidadCultivo && other.secuencia == secuencia;
  }

  @override
  int get hashCode => secuencia.hashCode;

  // ⭐ MÉTODOS ESTÁTICOS PARA OPERACIONES COMUNES

  // Filtrar unidades por ubicación
  static List<UnidadCultivo> filtrarPorUbicacion(
      List<UnidadCultivo> unidades, String? ubicacion) {
    if (ubicacion == null || ubicacion.isEmpty || ubicacion == 'Todos') {
      return unidades;
    }
    return unidades.where((unidad) => unidad.isInUbicacion(ubicacion)).toList();
  }

  // Filtrar unidades por códigos seleccionados
  static List<UnidadCultivo> filtrarPorCodigos(
      List<UnidadCultivo> unidades, List<String> codigos) {
    if (codigos.isEmpty) {
      return unidades;
    }
    return unidades.where((unidad) => codigos.contains(unidad.codigo)).toList();
  }

  // Obtener códigos únicos de una lista de unidades
  static List<String> extraerCodigosUnicos(List<UnidadCultivo> unidades) {
    return unidades.map((unidad) => unidad.codigo).toSet().toList()..sort();
  }

  // Obtener ubicaciones únicas de una lista de unidades
  static List<String> extraerUbicacionesUnicas(List<UnidadCultivo> unidades) {
    return unidades
        .where((unidad) => unidad.ubicacion?.isNotEmpty == true)
        .map((unidad) => unidad.ubicacion!)
        .toSet()
        .toList()
      ..sort();
  }

  // Marcar todas las unidades como seleccionadas
  static List<UnidadCultivo> marcarTodasSeleccionadas(
      List<UnidadCultivo> unidades, bool seleccionadas) {
    return unidades
        .map((unidad) => unidad.copyWith(selected: seleccionadas))
        .toList();
  }

  // Obtener solo las unidades seleccionadas
  static List<UnidadCultivo> obtenerSeleccionadas(
      List<UnidadCultivo> unidades) {
    return unidades.where((unidad) => unidad.selected == true).toList();
  }

  // Contar unidades por ubicación
  static Map<String, int> contarPorUbicacion(List<UnidadCultivo> unidades) {
    final Map<String, int> conteo = {};
    for (final unidad in unidades) {
      final ubicacion = unidad.ubicacion ?? 'Sin ubicación';
      conteo[ubicacion] = (conteo[ubicacion] ?? 0) + 1;
    }
    return conteo;
  }

  // Agrupar unidades por ubicación
  static Map<String, List<UnidadCultivo>> agruparPorUbicacion(
      List<UnidadCultivo> unidades) {
    final Map<String, List<UnidadCultivo>> grupos = {};
    for (final unidad in unidades) {
      final ubicacion = unidad.ubicacion ?? 'Sin ubicación';
      grupos[ubicacion] ??= [];
      grupos[ubicacion]!.add(unidad);
    }
    return grupos;
  }

  // Buscar unidades por texto en código o cantero
  static List<UnidadCultivo> buscarPorTexto(
      List<UnidadCultivo> unidades, String texto) {
    if (texto.isEmpty) {
      return unidades;
    }
    final textoLower = texto.toLowerCase();
    return unidades.where((unidad) {
      return unidad.codigo.toLowerCase().contains(textoLower) ||
          unidad.cantero.toLowerCase().contains(textoLower) ||
          (unidad.ubicacion?.toLowerCase().contains(textoLower) ?? false);
    }).toList();
  }

  // Validar si una unidad es válida para creación
  static String? validarParaCreacion(UnidadCultivo unidad) {
    if (unidad.codigo.trim().isEmpty) {
      return 'El código es obligatorio';
    }
    if (unidad.cantero.trim().isEmpty) {
      return 'El cantero es obligatorio';
    }
    if (unidad.id <= 0) {
      return 'El ID externo debe ser mayor a cero';
    }
    return null; // Sin errores
  }

  // Crear unidad desde formulario
  static UnidadCultivo? crearDesdeFormulario({
    required String codigo,
    required String cantero,
    required String idExterno,
    required String estado,
    String? ubicacion,
    int creadoPor = 1,
  }) {
    // Validaciones básicas
    if (codigo.trim().isEmpty ||
        cantero.trim().isEmpty ||
        idExterno.trim().isEmpty) {
      return null;
    }

    final id = int.tryParse(idExterno);
    if (id == null || id <= 0) {
      return null;
    }

    final estatus = estado == 'Activo' ? 1 : 0;

    return UnidadCultivo.nueva(
      codigo: codigo.trim(),
      cantero: cantero.trim(),
      id: id,
      estatus: estatus,
      ubicacion:
          ubicacion?.trim().isNotEmpty == true ? ubicacion!.trim() : null,
      creadoPor: creadoPor,
    );
  }

  // Crear lista de prueba para desarrollo
  static List<UnidadCultivo> crearListaDePrueba() {
    return [
      UnidadCultivo.nueva(
        codigo: 'UC001',
        cantero: 'Cantero A1',
        id: 1,
        ubicacion: 'La Romana',
      ),
      UnidadCultivo.nueva(
        codigo: 'UC002',
        cantero: 'Cantero A2',
        id: 2,
        ubicacion: 'La Romana',
      ),
      UnidadCultivo.nueva(
        codigo: 'UC001',
        cantero: 'Cantero B1',
        id: 3,
        ubicacion: 'Sabana de la Mar',
      ),
      UnidadCultivo.nueva(
        codigo: 'UC003',
        cantero: 'Cantero C1',
        id: 4,
        ubicacion: 'Sabana de la Mar',
      ),
    ];
  }
}
