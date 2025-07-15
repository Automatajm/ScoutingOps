/// Modelo que representa un monitoreo de plagas
class Monitoreo {
  // Cambiado de final a no-final para permitir asignación de IDs temporales
  int? pmmo_secuencia; // ID autoincremental
  final String? pmlt_codigo; // Código del lote
  final String? pmlt_descripcion; // Descripción del lote (de la tabla pm_lotes)
  final String? pmmo_casa; // Casa o sector
  final String? pmmo_cantero; // Cantero (ingresado por el usuario)
  final String? pmmo_canteros; // Canteros (original del lote, mantener intacto)
  final String? pmmo_variedad; // Variedad del cultivo
  final String? pmmo_grower; // Responsable o cultivador
  final int? pmni_id; // ID de nivel de infestación (plaga)
  final String? pmni_nombrecomun; // Nombre común de la plaga
  final int? pmmo_cantidad; // Cantidad observada
  final int? pmmo_cant_botada; // Cantidad eliminada
  final String? pmmo_comentarios; // Comentarios adicionales
  final DateTime? pmmo_fecha; // Fecha del monitoreo
  final bool?
      pmmo_automatico; // Si fue ingresado por código de barras o manualmente
  final int? pmmo_estatus; // Estado (1=activo, 0=inactivo)
  final int? pmmo_creadopor; // Usuario que creó el registro
  final DateTime? pmmo_fechacreacion; // Fecha de creación
  final int? pmmo_modificadopor; // Usuario que modificó por última vez
  final DateTime? pmmo_fechamodificacion; // Fecha de última modificación
  final String?
      pmva_descripcion; // Descripción de la variedad (de la tabla pm_variedades)
  String?
      pmmo_contenedor; // Contenedor - Cambiado a non-final para permitir modificación
  final String? pmmo_idvariedad; // ID de la variedad

  // Nuevos campos para muestras y niveles
  final int? pmmo_muestra1; // Valor de la muestra 1
  final int? pmmo_muestra2; // Valor de la muestra 2
  final int? pmmo_muestra3; // Valor de la muestra 3
  final int? pmmo_nivmuestraa1; // Nivel automático de la muestra 1
  final int? pmmo_nivmuestraa2; // Nivel automático de la muestra 2
  final int? pmmo_nivmuestraa3; // Nivel automático de la muestra 3
  final int? pmmo_nivmuestram1; // Nivel manual de la muestra 1
  final int? pmmo_nivmuestram2; // Nivel manual de la muestra 2
  final int? pmmo_nivmuestram3; // Nivel manual de la muestra 3
  final int? lmsupniv1; // Límite superior del nivel 1
  final int? lmsupniv2; // Límite superior del nivel 2
  final int? lmsupniv3; // Límite superior del nivel 3

  // Nuevo campo para rastrear si el monitoreo es temporal (creado offline)
  final bool? isOfflineCreated;

  // Añadido campo para almacenar timestamp de la última modificación offline
  final DateTime? offlineModifiedAt;

  // Nuevo campo para tracking de sincronización
  final bool? isSynchronized;

  Monitoreo({
    this.pmmo_secuencia,
    this.pmlt_codigo,
    this.pmlt_descripcion,
    this.pmmo_casa,
    this.pmmo_cantero,
    this.pmmo_canteros,
    this.pmmo_variedad,
    this.pmmo_grower,
    this.pmni_id,
    this.pmni_nombrecomun,
    this.pmmo_cantidad,
    this.pmmo_cant_botada,
    this.pmmo_comentarios,
    this.pmmo_fecha,
    this.pmmo_automatico,
    this.pmmo_estatus,
    this.pmmo_creadopor,
    this.pmmo_fechacreacion,
    this.pmmo_modificadopor,
    this.pmmo_fechamodificacion,
    this.pmva_descripcion,
    this.pmmo_contenedor,
    this.pmmo_idvariedad,
    // Nuevos campos
    this.pmmo_muestra1,
    this.pmmo_muestra2,
    this.pmmo_muestra3,
    this.pmmo_nivmuestraa1,
    this.pmmo_nivmuestraa2,
    this.pmmo_nivmuestraa3,
    this.pmmo_nivmuestram1,
    this.pmmo_nivmuestram2,
    this.pmmo_nivmuestram3,
    this.lmsupniv1,
    this.lmsupniv2,
    this.lmsupniv3,
    // Nuevos campos para soporte offline
    this.isOfflineCreated,
    this.offlineModifiedAt,
    this.isSynchronized,
  });

  /// Crea una copia de este Monitoreo con valores modificados
  Monitoreo copyWith({
    int? pmmo_secuencia,
    String? pmlt_codigo,
    String? pmlt_descripcion,
    String? pmmo_casa,
    String? pmmo_cantero,
    String? pmmo_canteros,
    String? pmmo_variedad,
    String? pmmo_grower,
    int? pmni_id,
    String? pmni_nombrecomun,
    int? pmmo_cantidad,
    int? pmmo_cant_botada,
    String? pmmo_comentarios,
    DateTime? pmmo_fecha,
    bool? pmmo_automatico,
    int? pmmo_estatus,
    int? pmmo_creadopor,
    DateTime? pmmo_fechacreacion,
    int? pmmo_modificadopor,
    DateTime? pmmo_fechamodificacion,
    String? pmva_descripcion,
    String? pmmo_contenedor,
    String? pmmo_idvariedad,
    // Nuevos campos
    int? pmmo_muestra1,
    int? pmmo_muestra2,
    int? pmmo_muestra3,
    int? pmmo_nivmuestraa1,
    int? pmmo_nivmuestraa2,
    int? pmmo_nivmuestraa3,
    int? pmmo_nivmuestram1,
    int? pmmo_nivmuestram2,
    int? pmmo_nivmuestram3,
    int? lmsupniv1,
    int? lmsupniv2,
    int? lmsupniv3,
    // Nuevos campos para soporte offline
    bool? isOfflineCreated,
    DateTime? offlineModifiedAt,
    bool? isSynchronized,
  }) {
    return Monitoreo(
      pmmo_secuencia: pmmo_secuencia ?? this.pmmo_secuencia,
      pmlt_codigo: pmlt_codigo ?? this.pmlt_codigo,
      pmlt_descripcion: pmlt_descripcion ?? this.pmlt_descripcion,
      pmmo_casa: pmmo_casa ?? this.pmmo_casa,
      pmmo_cantero: pmmo_cantero ?? this.pmmo_cantero,
      pmmo_canteros: pmmo_canteros ?? this.pmmo_canteros,
      pmmo_variedad: pmmo_variedad ?? this.pmmo_variedad,
      pmmo_grower: pmmo_grower ?? this.pmmo_grower,
      pmni_id: pmni_id ?? this.pmni_id,
      pmni_nombrecomun: pmni_nombrecomun ?? this.pmni_nombrecomun,
      pmmo_cantidad: pmmo_cantidad ?? this.pmmo_cantidad,
      pmmo_cant_botada: pmmo_cant_botada ?? this.pmmo_cant_botada,
      pmmo_comentarios: pmmo_comentarios ?? this.pmmo_comentarios,
      pmmo_fecha: pmmo_fecha ?? this.pmmo_fecha,
      pmmo_automatico: pmmo_automatico ?? this.pmmo_automatico,
      pmmo_estatus: pmmo_estatus ?? this.pmmo_estatus,
      pmmo_creadopor: pmmo_creadopor ?? this.pmmo_creadopor,
      pmmo_fechacreacion: pmmo_fechacreacion ?? this.pmmo_fechacreacion,
      pmmo_modificadopor: pmmo_modificadopor ?? this.pmmo_modificadopor,
      pmmo_fechamodificacion:
          pmmo_fechamodificacion ?? this.pmmo_fechamodificacion,
      pmva_descripcion: pmva_descripcion ?? this.pmva_descripcion,
      // IMPORTANTE: Asegurarse de preservar el contenedor actual
      // usando un valor por defecto si es null
      pmmo_contenedor:
          pmmo_contenedor ?? this.pmmo_contenedor ?? 'CONT_GENERAL',
      pmmo_idvariedad: pmmo_idvariedad ?? this.pmmo_idvariedad,
      // Nuevos campos
      pmmo_muestra1: pmmo_muestra1 ?? this.pmmo_muestra1,
      pmmo_muestra2: pmmo_muestra2 ?? this.pmmo_muestra2,
      pmmo_muestra3: pmmo_muestra3 ?? this.pmmo_muestra3,
      pmmo_nivmuestraa1: pmmo_nivmuestraa1 ?? this.pmmo_nivmuestraa1,
      pmmo_nivmuestraa2: pmmo_nivmuestraa2 ?? this.pmmo_nivmuestraa2,
      pmmo_nivmuestraa3: pmmo_nivmuestraa3 ?? this.pmmo_nivmuestraa3,
      pmmo_nivmuestram1: pmmo_nivmuestram1 ?? this.pmmo_nivmuestram1,
      pmmo_nivmuestram2: pmmo_nivmuestram2 ?? this.pmmo_nivmuestram2,
      pmmo_nivmuestram3: pmmo_nivmuestram3 ?? this.pmmo_nivmuestram3,
      lmsupniv1: lmsupniv1 ?? this.lmsupniv1,
      lmsupniv2: lmsupniv2 ?? this.lmsupniv2,
      lmsupniv3: lmsupniv3 ?? this.lmsupniv3,
      // Campos para soporte offline
      isOfflineCreated: isOfflineCreated ?? this.isOfflineCreated,
      offlineModifiedAt: offlineModifiedAt ?? this.offlineModifiedAt,
      isSynchronized: isSynchronized ?? this.isSynchronized,
    );
  }

  /// Convierte un JSON a Monitoreo - Adaptado para PostgreSQL
  factory Monitoreo.fromJson(Map<String, dynamic> json) {
    // Imprimir contenedor recibido para depuración
    print('Contenedor recibido en fromJson: ${json['pmmo_contenedor']}');

    return Monitoreo(
      pmmo_secuencia: json['pmmo_secuencia'],
      pmlt_codigo: json['pmlt_codigo'],
      pmlt_descripcion: json['pmlt_descripcion'],
      pmmo_casa: json['pmmo_casa'],
      pmmo_cantero: json['pmmo_cantero'],
      pmmo_canteros: json['pmmo_canteros'],
      pmmo_variedad: json['pmmo_variedad'],
      pmmo_grower: json['pmmo_grower'],
      pmni_id: json['pmni_id'],
      pmni_nombrecomun: json['pmni_nombrecomun'],
      pmmo_cantidad: json['pmmo_cantidad'],
      pmmo_cant_botada: json['pmmo_cant_botada'],
      pmmo_comentarios: json['pmmo_comentarios'],
      pmmo_fecha: json['pmmo_fecha'] != null
          ? DateTime.parse(json['pmmo_fecha'])
          : null,
      // PostgreSQL devuelve boolean como 't' o 'f', o directamente como un booleano
      pmmo_automatico: json['pmmo_automatico'] == true ||
          json['pmmo_automatico'] == 't' ||
          json['pmmo_automatico'] == 1 ||
          json['pmmo_automatico'] == '1',
      pmmo_estatus: json['pmmo_estatus'],
      pmmo_creadopor: json['pmmo_creadopor'],
      pmmo_fechacreacion: json['pmmo_fechacreacion'] != null
          ? DateTime.parse(json['pmmo_fechacreacion'])
          : null,
      pmmo_modificadopor: json['pmmo_modificadopor'],
      pmmo_fechamodificacion: json['pmmo_fechamodificacion'] != null
          ? DateTime.parse(json['pmmo_fechamodificacion'])
          : null,
      pmva_descripcion: json['pmva_descripcion'],
      // IMPORTANTE: Verificar que el contenedor nunca sea null
      pmmo_contenedor: json['pmmo_contenedor'] != null &&
              json['pmmo_contenedor'].toString().isNotEmpty
          ? json['pmmo_contenedor']
          : 'CONT_GENERAL',
      pmmo_idvariedad: json['pmmo_idvariedad'],
      // Nuevos campos
      pmmo_muestra1: json['pmmo_muestra1'],
      pmmo_muestra2: json['pmmo_muestra2'],
      pmmo_muestra3: json['pmmo_muestra3'],
      pmmo_nivmuestraa1: json['pmmo_nivmuestraa1'],
      pmmo_nivmuestraa2: json['pmmo_nivmuestraa2'],
      pmmo_nivmuestraa3: json['pmmo_nivmuestraa3'],
      pmmo_nivmuestram1: json['pmmo_nivmuestram1'],
      pmmo_nivmuestram2: json['pmmo_nivmuestram2'],
      pmmo_nivmuestram3: json['pmmo_nivmuestram3'],
      lmsupniv1: json['lmsupniv1'],
      lmsupniv2: json['lmsupniv2'],
      lmsupniv3: json['lmsupniv3'],
      // Campos para soporte offline
      isOfflineCreated: json['isOfflineCreated'] == true ||
          json['isOfflineCreated'] == 't' ||
          json['isOfflineCreated'] == 1 ||
          json['isOfflineCreated'] == '1',
      offlineModifiedAt: json['offlineModifiedAt'] != null
          ? DateTime.parse(json['offlineModifiedAt'])
          : null,
      isSynchronized: json['isSynchronized'] == true ||
          json['isSynchronized'] == 't' ||
          json['isSynchronized'] == 1 ||
          json['isSynchronized'] == '1',
    );
  }

  /// Crea un monitoreo temporal (offline) con un ID negativo
  factory Monitoreo.offline(Map<String, dynamic> json) {
    // Generar un ID negativo único basado en timestamp para identificarlo como temporal
    final tempId = -(DateTime.now().millisecondsSinceEpoch);

    final monitoreo = Monitoreo.fromJson(json);
    return monitoreo.copyWith(
      pmmo_secuencia: tempId,
      isOfflineCreated: true,
      offlineModifiedAt: DateTime.now(),
      isSynchronized: false,
    );
  }

  /// Convierte un Monitoreo a JSON - Adaptado para PostgreSQL
  Map<String, dynamic> toJson() {
    // Imprimir contenedor antes de serializar para depuración
    print('Contenedor antes de serializar en toJson: $pmmo_contenedor');

    final Map<String, dynamic> data = <String, dynamic>{};

    // Para forzar que SIEMPRE se envíen ciertos campos críticos, incluso si son null
    // Esto garantizará que estos campos aparezcan en la solicitud JSON
    data['pmmo_canteros'] = pmmo_canteros; // Mantener intacto el campo original
    data['pmmo_idvariedad'] = pmmo_idvariedad;
    // IMPORTANTE: Asegurar que el contenedor siempre tenga un valor
    data['pmmo_contenedor'] = pmmo_contenedor ?? 'CONT_GENERAL';
    data['pmni_nombrecomun'] = pmni_nombrecomun;
    data['pmmo_automatico'] = pmmo_automatico;

    // Asegurar que los límites SIEMPRE tengan un valor (no null)
    data['lmsupniv1'] = lmsupniv1 ?? 0; // Valor por defecto si es null
    data['lmsupniv2'] = lmsupniv2 ?? 0;
    data['lmsupniv3'] = lmsupniv3 ?? 0;

    // Valores de muestras
    data['pmmo_muestra1'] = pmmo_muestra1;
    data['pmmo_muestra2'] = pmmo_muestra2;
    data['pmmo_muestra3'] = pmmo_muestra3;

    // Niveles automáticos
    data['pmmo_nivmuestraa1'] = pmmo_nivmuestraa1;
    data['pmmo_nivmuestraa2'] = pmmo_nivmuestraa2;
    data['pmmo_nivmuestraa3'] = pmmo_nivmuestraa3;

    // Niveles manuales
    data['pmmo_nivmuestram1'] = pmmo_nivmuestram1;
    data['pmmo_nivmuestram2'] = pmmo_nivmuestram2;
    data['pmmo_nivmuestram3'] = pmmo_nivmuestram3;

    // Campos adicionales solo si no son null
    if (pmmo_secuencia != null) data['pmmo_secuencia'] = pmmo_secuencia;
    if (pmlt_codigo != null) data['pmlt_codigo'] = pmlt_codigo;
    if (pmlt_descripcion != null) data['pmlt_descripcion'] = pmlt_descripcion;
    if (pmmo_casa != null) data['pmmo_casa'] = pmmo_casa;
    if (pmmo_cantero != null) data['pmmo_cantero'] = pmmo_cantero;
    if (pmmo_variedad != null) data['pmmo_variedad'] = pmmo_variedad;
    if (pmmo_grower != null) data['pmmo_grower'] = pmmo_grower;
    if (pmni_id != null) data['pmni_id'] = pmni_id;
    if (pmmo_cantidad != null) data['pmmo_cantidad'] = pmmo_cantidad;
    if (pmmo_cant_botada != null) data['pmmo_cant_botada'] = pmmo_cant_botada;
    if (pmmo_comentarios != null) data['pmmo_comentarios'] = pmmo_comentarios;
    if (pmmo_fecha != null) data['pmmo_fecha'] = pmmo_fecha!.toIso8601String();
    if (pmmo_estatus != null) data['pmmo_estatus'] = pmmo_estatus;
    if (pmmo_creadopor != null) data['pmmo_creadopor'] = pmmo_creadopor;
    if (pmmo_fechacreacion != null)
      data['pmmo_fechacreacion'] = pmmo_fechacreacion!.toIso8601String();
    if (pmmo_modificadopor != null)
      data['pmmo_modificadopor'] = pmmo_modificadopor;
    if (pmmo_fechamodificacion != null)
      data['pmmo_fechamodificacion'] =
          pmmo_fechamodificacion!.toIso8601String();
    if (pmva_descripcion != null) data['pmva_descripcion'] = pmva_descripcion;

    // Campos para soporte offline
    if (isOfflineCreated != null) data['isOfflineCreated'] = isOfflineCreated;
    if (offlineModifiedAt != null)
      data['offlineModifiedAt'] = offlineModifiedAt!.toIso8601String();
    if (isSynchronized != null) data['isSynchronized'] = isSynchronized;

    return data;
  }

  /// Método para verificar si este monitoreo es temporal (creado offline)
  bool isTemporary() {
    return pmmo_secuencia != null && pmmo_secuencia! < 0;
  }

  /// Método para verificar si el monitoreo necesita sincronización
  bool needsSynchronization() {
    return isOfflineCreated == true || (isSynchronized == false);
  }

  @override
  String toString() {
    return 'Monitoreo(ID: $pmmo_secuencia, Lote: $pmlt_codigo, Casa: $pmmo_casa, Cantero: $pmmo_cantero, Plaga: $pmni_nombrecomun, Contenedor: $pmmo_contenedor, Offline: ${isOfflineCreated ?? false}, Sincronizado: ${isSynchronized ?? true})';
  }
}
