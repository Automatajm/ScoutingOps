import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/pm_plan_model.dart';
import '../models/unidad_cultivo_model.dart';
import '../services/unidad_cultivo_service.dart'; // ← NUEVA IMPORTACIÓN
import '../core/config/flavor_config.dart';

class PmPlanService {
  // Singleton para asegurar una única instancia
  static final PmPlanService _instance = PmPlanService._internal();
  factory PmPlanService() => _instance;
  PmPlanService._internal();

  // Getter para URL de pm_plan usando ApiConfig
  String get pmPlanUrl => '${ApiConfig().baseUrl}/api/pm-plan';

  // Getter para URL de unidades de cultivo (para modo planificar)
  String get unidadesCultivoUrl => ApiConfig().unidadesCultivoUrl;

  // ===============================================
  // 🆕 NUEVO: Obtener ubicaciones dinámicamente desde UnidadCultivo
  // ===============================================
  Future<List<String>> getUbicaciones() async {
    try {
      print('Obteniendo ubicaciones dinámicamente desde UnidadCultivoService');

      // Usar el servicio de UnidadCultivo para obtener ubicaciones
      final unidadCultivoService = UnidadCultivoService();
      final ubicaciones = await unidadCultivoService.getUbicaciones();

      print('Ubicaciones obtenidas dinámicamente: ${ubicaciones.length}');
      print('Ubicaciones: ${ubicaciones.join(', ')}');

      // Si no hay ubicaciones, devolver valores por defecto para evitar errores
      if (ubicaciones.isEmpty) {
        print('⚠️ No se encontraron ubicaciones, usando valores por defecto');
        return ['La Romana', 'Sabana de la mar'];
      }

      return ubicaciones;
    } catch (e) {
      print('❌ Error al obtener ubicaciones dinámicamente: $e');

      // En caso de error, devolver valores por defecto para que el sistema siga funcionando
      print('🔄 Usando ubicaciones por defecto debido al error');
      return ['La Romana', 'Sabana de la mar'];
    }
  }

  // ===============================================
  // 🆕 NUEVO: Actualizar estatus del INVERNADERO (unidad de cultivo) desde un plan
  // ===============================================
  Future<bool> updateUnidadEstatusFromPlan({
    required String unidadCodigo,
    required String ubicacion,
    int? nuevoEstatus, // Si es null, se togglea automáticamente
    int modificadoPor = 1,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Actualizando estatus del invernadero para unidad: $unidadCodigo (intento $attempt)');

        final Map<String, dynamic> bodyData = {
          'unidad_codigo': unidadCodigo,
          'ubicacion': ubicacion,
          'modificadopor': modificadoPor,
        };

        // Si se especifica el nuevo estatus, usarlo; si no, el backend decidirá (toggle)
        if (nuevoEstatus != null) {
          bodyData['nuevo_estatus'] = nuevoEstatus;
        }

        print('Parámetros de actualización de invernadero: $bodyData');

        final response = await http
            .put(
              Uri.parse('$pmPlanUrl/actualizar-invernadero'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(bodyData),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          if (jsonData is Map<String, dynamic>) {
            if (jsonData['success'] == true) {
              print('Estatus del invernadero actualizado exitosamente');
              return true;
            } else {
              throw Exception(jsonData['message'] ??
                  'Error al actualizar estatus del invernadero');
            }
          }

          return true;
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception(
              'Error al actualizar estatus del invernadero: ${errorData['message']}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en updateUnidadEstatusFromPlan()');
  }

  // ===============================================
  // FUNCIÓN ACTUALIZADA: Actualización masiva de estado de planificación con filtro de códigos
  // ===============================================
  Future<Map<String, dynamic>> updateEstadoPlanificacionMasivo({
    required String nuevoEstado,
    String? ubicacion,
    String? estadoPlanificacion,
    String? estatus,
    String? busqueda,
    List<String>?
        codigos, // ← NUEVO PARÁMETRO para filtrar por códigos específicos
    int modificadoPor = 1,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Actualizando estado masivo a: $nuevoEstado (intento $attempt)');
        if (codigos != null && codigos.isNotEmpty) {
          print('Filtros de códigos aplicados: ${codigos.join(', ')}');
        }

        final Map<String, dynamic> bodyData = {
          'nuevo_estado': nuevoEstado,
          'modificadopor': modificadoPor,
        };

        // Solo añadir filtros que tienen valor
        if (ubicacion != null && ubicacion.isNotEmpty) {
          bodyData['ubicacion'] = ubicacion;
        }
        if (estadoPlanificacion != null && estadoPlanificacion != 'Todos') {
          bodyData['estado_planificacion'] = estadoPlanificacion;
        }
        if (estatus != null && estatus != 'Todos') {
          bodyData['estatus'] = estatus;
        }
        if (busqueda != null && busqueda.isNotEmpty) {
          bodyData['busqueda'] = busqueda;
        }
        // NUEVO: Añadir filtro de códigos si está presente
        if (codigos != null && codigos.isNotEmpty) {
          bodyData['codigos'] = codigos;
        }

        print('Parámetros de actualización masiva: $bodyData');

        final response = await http
            .put(
              Uri.parse('$pmPlanUrl/actualizar-masivo'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(bodyData),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          if (jsonData is Map<String, dynamic>) {
            if (jsonData['success'] == true) {
              final planesActualizados =
                  jsonData['data']?['planes_actualizados'] ?? 0;
              print(
                  'Actualización masiva exitosa: $planesActualizados planes actualizados');

              return {
                'success': true,
                'message': jsonData['message'] ?? 'Actualización completada',
                'planes_actualizados': planesActualizados,
              };
            } else {
              throw Exception(
                  jsonData['message'] ?? 'Error en actualización masiva');
            }
          }

          return {
            'success': true,
            'message': 'Actualización completada',
            'planes_actualizados': 0
          };
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception(
              'Error al actualizar masivamente: ${errorData['message']}');
        }
      } on SocketException {
        print('Error de conexión (intento $attempt)');
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        print('Tiempo de espera agotado (intento $attempt)');
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        print('Error no manejado (intento $attempt): $e');
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en updateEstadoPlanificacionMasivo()');
  }

  // ===============================================
  // Obtener unidades de cultivo disponibles para planificar
  // ===============================================
  Future<List<UnidadCultivo>> getUnidadesDisponiblesParaPlanificar({
    required String ubicacion,
    String? busqueda,
    String? estatus,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final Map<String, String> queryParams = {
          'ubicacion': ubicacion,
        };

        if (busqueda != null && busqueda.isNotEmpty) {
          queryParams['busqueda'] = busqueda;
        }

        if (estatus != null && estatus != 'Todos') {
          queryParams['estatus'] = estatus;
        }

        final uri = Uri.parse('$pmPlanUrl/unidades-disponibles')
            .replace(queryParameters: queryParams);

        print('Obteniendo unidades disponibles desde: $uri (intento $attempt)');

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);
          List<dynamic> data;

          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('data')) {
            data = jsonData['data'];
          } else if (jsonData is List) {
            data = jsonData;
          } else {
            throw Exception('Formato de respuesta no reconocido');
          }

          print(
              'Unidades disponibles para planificar obtenidas: ${data.length}');
          return data.map((json) => UnidadCultivo.fromJson(json)).toList();
        } else {
          throw Exception(
              'Error al cargar unidades disponibles: ${response.statusCode}');
        }
      } on SocketException {
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception(
        'Error inesperado en getUnidadesDisponiblesParaPlanificar()');
  }

  // ===============================================
  // Obtener planes existentes
  // ===============================================
  Future<List<PmPlan>> getPlanes({
    String? ubicacion,
    String? estadoPlanificacion,
    String? estatus,
    String? busqueda,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final Map<String, String> queryParams = {};

        if (ubicacion != null && ubicacion.isNotEmpty) {
          queryParams['ubicacion'] = ubicacion;
        }

        if (estadoPlanificacion != null && estadoPlanificacion != 'Todos') {
          queryParams['estado_planificacion'] = estadoPlanificacion;
        }

        if (estatus != null && estatus != 'Todos') {
          queryParams['estatus'] = estatus;
        }

        if (busqueda != null && busqueda.isNotEmpty) {
          queryParams['busqueda'] = busqueda;
        }

        final uri = Uri.parse(pmPlanUrl).replace(queryParameters: queryParams);

        print('Obteniendo planes desde: $uri (intento $attempt)');

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);
          List<dynamic> data;

          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('data')) {
            data = jsonData['data'];
          } else if (jsonData is List) {
            data = jsonData;
          } else {
            throw Exception('Formato de respuesta no reconocido');
          }

          print('Planes obtenidos exitosamente: ${data.length}');
          return data.map((json) => PmPlan.fromJson(json)).toList();
        } else {
          throw Exception('Error al cargar planes: ${response.statusCode}');
        }
      } on SocketException {
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en getPlanes()');
  }

  // ===============================================
  // Crear planes múltiples desde unidades de cultivo seleccionadas
  // ===============================================
  Future<bool> createPlanesFromUnidades({
    required List<UnidadCultivo> unidades,
    required String ubicacion,
    int creadoPor = 1,
  }) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Creando ${unidades.length} planes para ubicación: $ubicacion (intento $attempt)');

        final Map<String, dynamic> bodyData = {
          'unidades': unidades
              .map((unidad) => {
                    'codigo': unidad.codigo,
                    'cantero': unidad.cantero,
                  })
              .toList(),
          'ubicacion': ubicacion,
          'creadopor': creadoPor,
        };

        final response = await http
            .post(
              Uri.parse('$pmPlanUrl/crear-multiples'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(bodyData),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          if (jsonData is Map<String, dynamic>) {
            if (jsonData.containsKey('success')) {
              if (jsonData['success'] == true) {
                print(
                    'Planes creados exitosamente: ${jsonData['data']?['planes_creados'] ?? unidades.length}');
                return true;
              } else {
                throw Exception(jsonData['message'] ?? 'Error al crear planes');
              }
            }
            return true;
          } else {
            return true;
          }
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception('Error al crear planes: ${errorData['message']}');
        }
      } on SocketException {
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en createPlanesFromUnidades()');
  }

  // ===============================================
  // Actualizar un plan existente
  // ===============================================
  Future<bool> updatePlan(PmPlan plan) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Actualizando plan secuencia: ${plan.secuencia} (intento $attempt)');

        final Map<String, dynamic> bodyData = {
          'estado_planificacion': plan.estadoPlanificacion,
          'estatus': plan.estatus,
          'modificadopor': plan.modificadoPor ?? 1,
        };

        final response = await http
            .put(
              Uri.parse('$pmPlanUrl/${plan.secuencia}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(bodyData),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final dynamic jsonData = json.decode(response.body);

          if (jsonData is Map<String, dynamic> &&
              jsonData.containsKey('success')) {
            if (jsonData['success'] == true) {
              return true;
            } else {
              throw Exception(
                  jsonData['message'] ?? 'Error al actualizar plan');
            }
          } else if (jsonData is bool) {
            return jsonData;
          } else {
            return true;
          }
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception('Error al actualizar plan: ${errorData['message']}');
        }
      } on SocketException {
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en updatePlan()');
  }

  // ===============================================
  // Eliminar un plan
  // ===============================================
  Future<bool> deletePlan(int secuencia) async {
    int maxRetries = 2;
    int retryDelay = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Eliminando plan secuencia: $secuencia (intento $attempt)');

        final response = await http
            .delete(Uri.parse('$pmPlanUrl/$secuencia'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          try {
            final dynamic jsonData = json.decode(response.body);

            if (jsonData is Map<String, dynamic> &&
                jsonData.containsKey('success')) {
              if (jsonData['success'] == true) {
                return true;
              } else {
                throw Exception(
                    jsonData['message'] ?? 'Error al eliminar plan');
              }
            } else if (jsonData is bool) {
              return jsonData;
            } else {
              return true;
            }
          } catch (e) {
            return true;
          }
        } else {
          final Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception('Error al eliminar plan: ${errorData['message']}');
        }
      } on SocketException {
        if (attempt == maxRetries) {
          throw Exception(
              'Error de conexión. Verifique su conexión a internet.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } on TimeoutException {
        if (attempt == maxRetries) {
          throw Exception('Tiempo de espera agotado.');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      } catch (e) {
        if (attempt == maxRetries) {
          throw Exception('Error inesperado: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelay));
        retryDelay *= 2;
      }
    }

    throw Exception('Error inesperado en deletePlan()');
  }

  // ===============================================
  // Validar si una unidad ya existe
  // ===============================================
  Future<bool> validateUnidadNotExists({
    required String codigo,
    required String ubicacion,
  }) async {
    try {
      final Map<String, dynamic> bodyData = {
        'unidad_codigo': codigo,
        'ubicacion': ubicacion,
      };

      final response = await http
          .post(
            Uri.parse('$pmPlanUrl/validate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(bodyData),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        if (jsonData is Map<String, dynamic>) {
          return jsonData['exists'] == false;
        }
        return true;
      }
      return true;
    } catch (e) {
      print('Error en validación: $e');
      return true;
    }
  }
}
