import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/config/flavor_config.dart';
import '../models/monitoreo_model.dart';
import '../data/datasources/auth_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio para manejar las operaciones de monitoreo de plagas con el backend
class MonitoreoService extends ChangeNotifier {
  final AuthService _authService;
  final Dio _dio;
  final ApiConfig _apiConfig;

  // Getters para URLs específicas
  String get monitoreoUrl => _apiConfig.monitoreoUrl;
  String get plagasUrl => _apiConfig.plagasUrl;
  String get unidadesCultivoUrl => _apiConfig.unidadesCultivoUrl;
  String get nivelesInfestacionUrl => _apiConfig.nivelesInfestacionUrl;
  String get variedadesUrl => _apiConfig.variedadesUrl;

  // Lista local de monitoreos para soporte offline
  List<Monitoreo> _offlineMonitoreos = [];
  bool _isInitialized = false;

  // Constructor y configuración
  MonitoreoService(this._authService, this._apiConfig)
      : _dio = Dio(BaseOptions(
          baseUrl: _apiConfig.apiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    // Configurar interceptor para manejar errores y sesiones
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      debugPrint('Solicitud: ${options.method} ${options.path}');

      // Cada vez que hacemos una solicitud, verificamos que el usuario esté autenticado
      if (_authService.isAuthenticated) {
        // Si estás usando token JWT, aquí lo añadirías
        // options.headers['Authorization'] = 'Bearer ${_authService.token}';
      }
      return handler.next(options);
    }, onError: (DioException e, handler) {
      debugPrint('Error en solicitud: ${e.message}');

      // Si recibimos un 401 Unauthorized, cerramos la sesión
      if (e.response?.statusCode == 401) {
        _authService.logout();
      }
      return handler.next(e);
    }, onResponse: (response, handler) {
      // Resetear el timer de inactividad en cada respuesta exitosa
      if (_authService.isAuthenticated) {
        // Solo si tienes contexto disponible
        // _authService.resetInactivityTimer(null);
      }
      return handler.next(response);
    }));

    // Suscribirse a los cambios en la configuración de la API
    _apiConfig.addListener(_updateDioBaseUrl);

    // Inicializar datos offline
    _initializeOfflineData();
  }

  // Inicializar datos guardados en localStorage para soporte offline
  Future<void> _initializeOfflineData() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? monitoreoJson = prefs.getString('offline_monitoreos');

      if (monitoreoJson != null) {
        final List<dynamic> decodedList = jsonDecode(monitoreoJson);
        _offlineMonitoreos =
            decodedList.map((json) => Monitoreo.fromJson(json)).toList();
        debugPrint('Cargados ${_offlineMonitoreos.length} monitoreos offline');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error al inicializar datos offline: $e');
    }
  }

  // Guardar monitoreos en localStorage para soporte offline
  Future<void> _saveOfflineMonitoreos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          _offlineMonitoreos.map((monitoreo) => monitoreo.toJson()).toList();
      await prefs.setString('offline_monitoreos', jsonEncode(jsonList));
      debugPrint('Guardados ${_offlineMonitoreos.length} monitoreos offline');
    } catch (e) {
      debugPrint('Error al guardar monitoreos offline: $e');
    }
  }

  // Método para actualizar la URL base cuando cambia la configuración
  void _updateDioBaseUrl() {
    _dio.options.baseUrl = _apiConfig.apiUrl;
    debugPrint('URL base de Dio actualizada: ${_dio.options.baseUrl}');
  }

  @override
  void dispose() {
    // Eliminar listener al destruir el servicio
    _apiConfig.removeListener(_updateDioBaseUrl);
    super.dispose();
  }

  /// Maneja los errores de Dio de manera centralizada
  void _handleDioError(DioException e) {
    debugPrint('Error DIO: ${e.type} - ${e.message}');

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        debugPrint('Timeout en la conexión');
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        debugPrint('Error de respuesta HTTP $statusCode: $responseData');
        break;
      case DioExceptionType.cancel:
        debugPrint('Solicitud cancelada');
        break;
      case DioExceptionType.connectionError:
        debugPrint('Error de conexión de red');
        break;
      default:
        debugPrint('Error inesperado de Dio');
        break;
    }
  }

  /// Evalúa si un valor dado representa éxito, independientemente de su tipo
  bool _isSuccessValue(dynamic value) {
    if (value == null) return false;

    if (value is bool) {
      return value;
    } else if (value is int) {
      return value == 1;
    } else if (value is String) {
      final lowerValue = value.toLowerCase();
      return lowerValue == 'true' ||
          value == '1' ||
          lowerValue == 'yes' ||
          lowerValue == 'success';
    }

    return false;
  }

  /// Exporta los datos de monitoreo a un archivo Excel simple
  Future<bool> exportarMonitoreosExcel(
    List<Monitoreo> monitoreos,
    String fileName,
    List<Map<String, dynamic>> columns,
  ) async {
    try {
      debugPrint(
          'Iniciando exportación a Excel de ${monitoreos.length} monitoreos');

      // Generar el timestamp para el nombre del archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fullFileName = '${fileName}_$timestamp.xlsx';

      // CREAR DOCUMENTO EXCEL
      var excel = Excel.createExcel();

      // ✅ CREAR LA HOJA QUE NECESITAMOS PRIMERO
      var sheet = excel['Monitoreos'];

      // ✅ LUEGO ELIMINAR TODAS LAS DEMÁS HOJAS (incluyendo Sheet1)
      final sheetsToDelete =
          excel.sheets.keys.where((name) => name != 'Monitoreos').toList();
      for (String sheetName in sheetsToDelete) {
        excel.delete(sheetName);
      }

      // ✅ AÑADIR ENCABEZADOS SIN FORMATO (sin azul, sin negrita)
      for (int i = 0; i < columns.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(columns[i]['title'] as String);
        // Sin CellStyle - encabezados simples
      }

      // Añadir datos por cada monitoreo
      for (int rowIndex = 0; rowIndex < monitoreos.length; rowIndex++) {
        final monitoreo = monitoreos[rowIndex];

        for (int colIndex = 0; colIndex < columns.length; colIndex++) {
          final column = columns[colIndex];

          // Verificar que el extractor de valores existe
          if (column.containsKey('valueExtractor') &&
              column['valueExtractor'] != null) {
            // Obtener el valor usando el extractor de valores
            final valueExtractor = column['valueExtractor'] as Function;
            var value = valueExtractor(monitoreo);

            // Asignar el valor como texto sin formato especial
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: colIndex, rowIndex: rowIndex + 1))
                .value = TextCellValue(value?.toString() ?? '-');
          } else {
            // Si no hay extractor para esta columna, añadir valor vacío
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: colIndex, rowIndex: rowIndex + 1))
                .value = TextCellValue('-');
          }
        }
      }

      // Procesar el archivo según la plataforma
      if (kIsWeb) {
        // Implementación para web
        return await _exportExcelWeb(excel, fullFileName);
      } else {
        // Implementación para móvil/desktop
        return await _exportExcelMobile(excel, fullFileName);
      }
    } catch (e) {
      debugPrint('Error general al exportar a Excel: $e');
      return false;
    }
  }

  /// Exporta Excel para plataforma web
  Future<bool> _exportExcelWeb(Excel excel, String fileName) async {
    try {
      // Limpiar el DOM de posibles descargas anteriores
      final nodeList = html.document.querySelectorAll('a[download]');
      for (int i = 0; i < nodeList.length; i++) {
        nodeList[i].remove();
      }

      // ✅ SOLUCIÓN DEFINITIVA: Usar encode() en lugar de save()
      // ❌ ANTES: excel.save() causaba descarga automática
      // ✅ AHORA: excel.encode() solo genera bytes
      final bytes = excel.encode();
      if (bytes == null) {
        debugPrint('Error: excel.encode() devolvió null');
        return false;
      }

      // Crear un blob con los bytes
      final blob = html.Blob([Uint8List.fromList(bytes)]);

      // Crear URL para descargar
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Simular click en enlace de descarga
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..setAttribute('style', 'display: none');

      // Añadir al DOM, hacer click y esperar antes de eliminar
      html.document.body?.append(anchor);

      // Pequeño retraso para asegurar que el navegador procese
      await Future.delayed(const Duration(milliseconds: 100));

      anchor.click();

      // Otro pequeño retraso antes de limpiar
      await Future.delayed(const Duration(milliseconds: 100));

      // Limpiar recursos
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      debugPrint('Archivo Excel descargado en el navegador: $fileName');
      return true;
    } catch (e) {
      debugPrint('Error al exportar Excel en web: $e');
      return false;
    }
  }

  /// Exporta Excel para plataformas móvil/desktop
  Future<bool> _exportExcelMobile(Excel excel, String fileName) async {
    try {
      // Obtener directorio para guardar el archivo
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);

      // Eliminar archivo existente si existe para evitar conflictos
      if (await file.exists()) {
        await file.delete();
      }

      // ✅ USAR encode() EN LUGAR DE save()
      final bytes = excel.encode();
      if (bytes == null) {
        debugPrint('Error: excel.encode() devolvió null');
        return false;
      }

      await file.writeAsBytes(bytes);

      // Aquí podrías añadir lógica para compartir el archivo
      // Por ejemplo usando el paquete share_plus:
      // await Share.shareFiles([path], text: 'Monitoreos exportados');

      debugPrint('Archivo Excel guardado localmente en: $path');
      return true;
    } catch (e) {
      debugPrint('Error al exportar Excel en móvil/desktop: $e');
      return false;
    }
  }

  /// Obtiene datos auxiliares como variedades o plagas
  Future<Map<String, dynamic>> getDatosAuxiliares(String tipo) async {
    try {
      late Response response;

      switch (tipo) {
        case 'variedades':
          response = await _dio.get(variedadesUrl);
          break;
        case 'nivelesinfestacion':
          response = await _dio.get(nivelesInfestacionUrl);
          break;
        case 'niveles': // Añadido para obtener niveles de límites
          response = await _dio.get('$nivelesInfestacionUrl/limites');
          break;
        case 'casas':
          response = await _dio
              .get(unidadesCultivoUrl); // Endpoint correcto para las casas
          break;
        case 'filtros':
          // Nuevo endpoint para obtener todas las opciones de filtros
          response = await _dio.get('$monitoreoUrl/filtros/casas-canteros');
          break;
        case 'variedades-activas':
          // Nuevo endpoint para obtener variedades activas con conteo
          response = await _dio.get('$monitoreoUrl/filtros/variedades');
          break;
        default:
          throw Exception('Tipo de datos auxiliares no válido');
      }

      if (response.statusCode == 200) {
        debugPrint('Respuesta para $tipo: ${response.data}');

        // Si la respuesta es directamente un array (como en el caso de variedades)
        if (response.data is List) {
          // Crear un formato de respuesta estándar
          return {'success': true, 'message': 'OK', 'data': response.data};
        }

        // Si la respuesta es un mapa y tiene la estructura esperada
        if (response.data is Map) {
          // Verificar si tiene el campo 'data'
          if (response.data.containsKey('data')) {
            return response.data as Map<String, dynamic>;
          }

          // Si no tiene el campo 'data', pero es un mapa, tal vez es directamente la data
          return {'success': true, 'message': 'OK', 'data': response.data};
        }

        // Si es algún otro tipo de respuesta, crear una estructura estándar
        return {'success': true, 'message': 'OK', 'data': []};
      } else {
        debugPrint('Error en status code: ${response.statusCode}');
        // Crear un resultado con estructura correcta en caso de error
        return {
          'success': false,
          'message': 'Error ${response.statusCode}',
          'data': []
        };
      }
    } on DioException catch (e) {
      _handleDioError(e);
      debugPrint('Error de conexión en $tipo: ${e.message}');
      // Crear un resultado con estructura correcta en caso de error
      return {
        'success': false,
        'message': 'Error de conexión: ${e.message}',
        'data': []
      };
    } catch (e) {
      debugPrint('Error inesperado en getDatosAuxiliares para $tipo: $e');
      // Crear un resultado con estructura correcta en caso de error
      return {'success': false, 'message': 'Error inesperado: $e', 'data': []};
    }
  }

  /// Obtiene la lista de monitoreos con filtros opcionales
  /// Modificado para aplicar filtrado por usuario de manera consistente
  /// y para incluir los nuevos filtros: casa, cantero y variedad
  Future<List<Monitoreo>> getMonitoreos({
    String? lote,
    String? plaga,
    String? casa, // Nuevo filtro: Casa
    String? cantero, // Nuevo filtro: Cantero
    String? variedad, // Nuevo filtro: Variedad
    int? estatus,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool includeOffline =
        true, // Nuevo parámetro para incluir monitoreos offline
  }) async {
    try {
      // Verificar conectividad
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline, retornar solo datos locales
      if (isOffline) {
        debugPrint('Sin conexión, retornando datos offline');
        await _initializeOfflineData(); // Asegurar que los datos están cargados

        List<Monitoreo> filteredMonitoreos = List.from(_offlineMonitoreos);

        // Aplicar filtros a los datos offline
        if (lote != null && lote.isNotEmpty) {
          filteredMonitoreos =
              filteredMonitoreos.where((m) => m.pmlt_codigo == lote).toList();
        }

        if (plaga != null && plaga != 'Todas') {
          filteredMonitoreos = filteredMonitoreos
              .where((m) => m.pmni_nombrecomun == plaga)
              .toList();
        }

        if (casa != null && casa != 'Todas') {
          filteredMonitoreos =
              filteredMonitoreos.where((m) => m.pmmo_casa == casa).toList();
        }

        if (cantero != null && cantero != 'Todos') {
          filteredMonitoreos = filteredMonitoreos
              .where((m) => m.pmmo_cantero == cantero)
              .toList();
        }

        if (variedad != null && variedad != 'Todas') {
          filteredMonitoreos = filteredMonitoreos
              .where((m) =>
                  m.pmmo_variedad == variedad || m.pmva_descripcion == variedad)
              .toList();
        }

        if (estatus != null) {
          filteredMonitoreos = filteredMonitoreos
              .where((m) => m.pmmo_estatus == estatus)
              .toList();
        }

        if (fechaInicio != null) {
          filteredMonitoreos = filteredMonitoreos
              .where((m) =>
                  m.pmmo_fecha != null && m.pmmo_fecha!.isAfter(fechaInicio))
              .toList();
        }

        if (fechaFin != null) {
          filteredMonitoreos = filteredMonitoreos
              .where((m) =>
                  m.pmmo_fecha != null && m.pmmo_fecha!.isBefore(fechaFin))
              .toList();
        }

        notifyListeners();
        return filteredMonitoreos;
      }

      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {};

      if (lote != null && lote.isNotEmpty) queryParams['lote'] = lote;
      if (plaga != null && plaga != 'Todas') queryParams['plaga'] = plaga;
      if (casa != null && casa != 'Todas')
        queryParams['casa'] = casa; // Nuevo parámetro
      if (cantero != null && cantero != 'Todos')
        queryParams['cantero'] = cantero; // Nuevo parámetro
      if (variedad != null && variedad != 'Todas')
        queryParams['variedad'] = variedad; // Nuevo parámetro
      if (estatus != null) queryParams['estatus'] = estatus.toString();
      if (fechaInicio != null)
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      if (fechaFin != null)
        queryParams['fechaFin'] = fechaFin.toIso8601String();

      // Si el usuario es monitor (no admin), filtrar por su ID
      if (_authService.mustFilterByUser) {
        queryParams['usuarioId'] = _authService.getCurrentUserId().toString();
      }

      debugPrint('Consultando monitoreos con parámetros: $queryParams');

      // Realizar petición
      final response = await _dio.get(
        monitoreoUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          final List<dynamic> dataList = response.data['data'];
          debugPrint('Monitoreos recibidos: ${dataList.length}');

          // Verificar el contenedor de cada monitoreo para depuración
          for (var item in dataList) {
            print(
                'Contenedor en monitoreo recibido: ${item['pmmo_contenedor']}');
          }

          List<Monitoreo> monitoreos =
              dataList.map((json) => Monitoreo.fromJson(json)).toList();

          // MODIFICADO: Filtrado adicional a nivel de cliente para garantizar que un usuario
          // con rol "monitoreador" solo vea sus propios registros
          if (_authService.isMonitoreador) {
            final userId = _authService.getCurrentUserId();
            monitoreos = monitoreos
                .where((monitoreo) => monitoreo.pmmo_creadopor == userId)
                .toList();
          }

          // MODIFICADO: Aplicar filtros adicionales en el lado del cliente si la API no lo maneja
          if (casa != null && casa != 'Todas') {
            monitoreos = monitoreos.where((m) => m.pmmo_casa == casa).toList();
          }

          if (cantero != null && cantero != 'Todos') {
            monitoreos =
                monitoreos.where((m) => m.pmmo_cantero == cantero).toList();
          }

          if (variedad != null && variedad != 'Todas') {
            monitoreos = monitoreos
                .where((m) =>
                    m.pmmo_variedad == variedad ||
                    m.pmva_descripcion == variedad)
                .toList();
          }

          // Si se solicita incluir datos offline, combinar con los datos del servidor
          if (includeOffline) {
            await _initializeOfflineData(); // Asegurar que los datos están cargados

            // Filtrar los monitoreos offline según los mismos criterios
            List<Monitoreo> filteredOfflineMonitoreos =
                List.from(_offlineMonitoreos);

            if (lote != null && lote.isNotEmpty) {
              filteredOfflineMonitoreos = filteredOfflineMonitoreos
                  .where((m) => m.pmlt_codigo == lote)
                  .toList();
            }

            // Aplicar el resto de filtros a los datos offline...

            // Combinar los resultados
            monitoreos = [...monitoreos, ...filteredOfflineMonitoreos];
          }

          notifyListeners(); // Notificar a los listeners cuando se actualiza la lista
          return monitoreos;
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al obtener monitoreos');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay un error de conexión, tratar de devolver datos offline
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        debugPrint('Error de conexión, retornando datos offline');
        await _initializeOfflineData();

        // Aplicar los mismos filtros que arriba...

        return _offlineMonitoreos;
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene un monitoreo por su ID
  Future<Monitoreo> getMonitoreoById(int id) async {
    try {
      // Si el ID es negativo, buscar en los monitoreos offline
      if (id < 0) {
        await _initializeOfflineData();
        final offlineMonitoreo = _offlineMonitoreos.firstWhere(
          (m) => m.pmmo_secuencia == id,
          orElse: () =>
              throw Exception('No se encontró el monitoreo offline con ID $id'),
        );
        return offlineMonitoreo;
      }

      debugPrint('Consultando monitoreo con ID: $id');
      final response = await _dio.get('$monitoreoUrl/$id');

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          debugPrint('Datos del monitoreo recibidos: ${response.data['data']}');

          // Verificar específicamente el contenedor
          print(
              'Contenedor en monitoreo recibido: ${response.data['data']['pmmo_contenedor']}');

          Monitoreo monitoreo = Monitoreo.fromJson(response.data['data']);

          // Verificar si el usuario actual tiene permiso para ver este monitoreo
          if (_authService.mustFilterByUser &&
              !_authService.isOwnerOfMonitoreo(monitoreo.pmmo_creadopor ?? 0)) {
            throw Exception('No tienes permiso para ver este monitoreo');
          }

          // IMPORTANTE: Verificar si el monitoreo tiene un contenedor y asignar uno por defecto si es necesario
          if (monitoreo.pmmo_contenedor == null ||
              monitoreo.pmmo_contenedor!.isEmpty) {
            print(
                'ADVERTENCIA: Monitoreo del servidor no tiene contenedor, asignando valor por defecto');
            monitoreo = monitoreo.copyWith(pmmo_contenedor: 'CONT_GENERAL');
          }

          return monitoreo;
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al obtener el monitoreo');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay un error de conexión y es un ID positivo, intentar buscar en la caché local
      if ((e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout) &&
          id > 0) {
        await _initializeOfflineData();
        final localMonitoreo = _offlineMonitoreos.firstWhere(
          (m) => m.pmmo_secuencia == id,
          orElse: () => throw Exception(
              'No se pudo conectar y no se encontró el monitoreo en caché local'),
        );
        return localMonitoreo;
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Crea un nuevo monitoreo
  Future<Monitoreo> crearMonitoreo(Monitoreo monitoreo) async {
    try {
      // Verificar conectividad
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline, guardar localmente
      if (isOffline) {
        await _initializeOfflineData();

        // Crear monitoreo offline con ID negativo temporal
        final offlineMonitoreo = Monitoreo.offline(monitoreo.toJson());

        // Añadir a la lista local
        _offlineMonitoreos.add(offlineMonitoreo);
        await _saveOfflineMonitoreos();

        notifyListeners();
        return offlineMonitoreo;
      }

      // IMPORTANTE: Verificar si el monitoreo tiene un contenedor antes de enviarlo
      if (monitoreo.pmmo_contenedor == null ||
          monitoreo.pmmo_contenedor!.isEmpty) {
        print(
            'ADVERTENCIA: Contenedor vacío en crearMonitoreo, asignando valor por defecto');
        monitoreo = monitoreo.copyWith(pmmo_contenedor: 'CONT_GENERAL');
      }

      // Asegurar que el ID del usuario actual se establezca como creador
      monitoreo =
          monitoreo.copyWith(pmmo_creadopor: _authService.getCurrentUserId());

      // Debug: Imprimir el JSON que enviaremos
      final jsonData = monitoreo.toJson();
      debugPrint('Enviando datos de nuevo monitoreo: ${jsonEncode(jsonData)}');
      print('Contenedor en monitoreo a crear: ${jsonData['pmmo_contenedor']}');

      final response = await _dio.post(
        monitoreoUrl,
        data: jsonData,
      );

      if (response.statusCode == 201) {
        if (_isSuccessValue(response.data['success'])) {
          // Debug: Imprimir la respuesta
          debugPrint('Respuesta del servidor: ${response.data.toString()}');
          print(
              'Contenedor en monitoreo creado: ${response.data['data']['pmmo_contenedor']}');

          final nuevoMonitoreo = Monitoreo.fromJson(response.data['data']);

          // Si es un monitoreo que estaba offline, marcarlo como sincronizado
          if (monitoreo.isOfflineCreated == true) {
            // Buscar y eliminar la versión offline si existe
            _offlineMonitoreos.removeWhere((m) =>
                m.isOfflineCreated == true &&
                m.pmlt_codigo == monitoreo.pmlt_codigo &&
                m.pmmo_fecha?.toIso8601String() ==
                    monitoreo.pmmo_fecha?.toIso8601String() &&
                m.pmni_nombrecomun == monitoreo.pmni_nombrecomun);

            await _saveOfflineMonitoreos();
          }

          notifyListeners(); // Notificar a los listeners sobre el nuevo monitoreo
          return nuevoMonitoreo;
        } else {
          debugPrint('Error en la respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al crear el monitoreo');
        }
      } else {
        debugPrint('Status code no esperado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      debugPrint('Error Dio al crear monitoreo: ${e.message}');

      // Si hay un error de conexión, guardar localmente
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();

        // Crear monitoreo offline con ID negativo temporal
        final offlineMonitoreo = Monitoreo.offline(monitoreo.toJson());

        // Añadir a la lista local
        _offlineMonitoreos.add(offlineMonitoreo);
        await _saveOfflineMonitoreos();

        notifyListeners();
        return offlineMonitoreo;
      }

      // Imprimir más detalles sobre la respuesta si está disponible
      if (e.response != null) {
        debugPrint('Datos de respuesta en error: ${e.response?.data}');
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado al crear monitoreo: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Actualiza un monitoreo existente
  Future<Monitoreo> actualizarMonitoreo(Monitoreo monitoreo) async {
    if (monitoreo.pmmo_secuencia == null) {
      throw Exception('ID de monitoreo no válido');
    }

    // Si es un monitoreo offline (ID negativo), actualizar localmente
    if (monitoreo.pmmo_secuencia! < 0) {
      await _initializeOfflineData();

      int index = _offlineMonitoreos
          .indexWhere((m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
      if (index >= 0) {
        // Actualizar con marca de tiempo de modificación
        _offlineMonitoreos[index] = monitoreo.copyWith(
            offlineModifiedAt: DateTime.now(), isSynchronized: false);
        await _saveOfflineMonitoreos();
        notifyListeners();
        return _offlineMonitoreos[index];
      } else {
        throw Exception('No se encontró el monitoreo offline para actualizar');
      }
    }

    // Verificar si el usuario tiene permiso para actualizar este monitoreo
    if (_authService.mustFilterByUser &&
        !_authService.isOwnerOfMonitoreo(monitoreo.pmmo_creadopor ?? 0)) {
      throw Exception(
          'No tienes permiso para actualizar este monitoreo. Solo puedes modificar monitoreos creados por ti.');
    }

    try {
      // Verificar conectividad
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline, guardar localmente para sincronizar después
      if (isOffline) {
        await _initializeOfflineData();

        // Añadir a la lista de pendientes offline con marca de tiempo
        final offlineMonitoreo = monitoreo.copyWith(
            offlineModifiedAt: DateTime.now(), isSynchronized: false);

        // Buscar si ya existe una copia local
        int index = _offlineMonitoreos
            .indexWhere((m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
        if (index >= 0) {
          _offlineMonitoreos[index] = offlineMonitoreo;
        } else {
          _offlineMonitoreos.add(offlineMonitoreo);
        }

        await _saveOfflineMonitoreos();
        notifyListeners();
        return offlineMonitoreo;
      }

      // IMPORTANTE: Verificar si el monitoreo tiene un contenedor antes de enviarlo
      if (monitoreo.pmmo_contenedor == null ||
          monitoreo.pmmo_contenedor!.isEmpty) {
        print(
            'ADVERTENCIA: Contenedor vacío en actualizarMonitoreo, asignando valor por defecto');
        monitoreo = monitoreo.copyWith(pmmo_contenedor: 'CONT_GENERAL');
      }

      // Asegurar que el ID del usuario actual se establezca como modificador
      monitoreo = monitoreo.copyWith(
          pmmo_modificadopor: _authService.getCurrentUserId());

      // Debug: Imprimir el JSON que enviaremos
      final jsonData = monitoreo.toJson();
      debugPrint(
          'Enviando datos para actualizar monitoreo ID ${monitoreo.pmmo_secuencia}: ${jsonEncode(jsonData)}');
      print(
          'Contenedor en monitoreo a actualizar: ${jsonData['pmmo_contenedor']}');

      final response = await _dio.put(
        '$monitoreoUrl/${monitoreo.pmmo_secuencia}',
        data: jsonData,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          // Debug: Imprimir la respuesta
          debugPrint('Respuesta del servidor: ${response.data.toString()}');
          print(
              'Contenedor en monitoreo actualizado: ${response.data['data']['pmmo_contenedor']}');

          final monitoreoActualizado =
              Monitoreo.fromJson(response.data['data']);

          // Eliminar cualquier versión offline si existiera
          _offlineMonitoreos
              .removeWhere((m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
          await _saveOfflineMonitoreos();

          notifyListeners(); // Notificar a los listeners sobre la actualización
          return monitoreoActualizado;
        } else {
          debugPrint('Error en la respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al actualizar el monitoreo');
        }
      } else {
        debugPrint('Status code no esperado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      debugPrint('Error Dio al actualizar monitoreo: ${e.message}');

      // Si hay un error de conexión, guardar localmente para sincronizar después
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();

        // Añadir a la lista de pendientes offline con marca de tiempo
        final offlineMonitoreo = monitoreo.copyWith(
            offlineModifiedAt: DateTime.now(), isSynchronized: false);

        // Buscar si ya existe una copia local
        int index = _offlineMonitoreos
            .indexWhere((m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
        if (index >= 0) {
          _offlineMonitoreos[index] = offlineMonitoreo;
        } else {
          _offlineMonitoreos.add(offlineMonitoreo);
        }

        await _saveOfflineMonitoreos();
        notifyListeners();
        return offlineMonitoreo;
      }

      // Imprimir más detalles sobre la respuesta si está disponible
      if (e.response != null) {
        debugPrint('Datos de respuesta en error: ${e.response?.data}');
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado al actualizar monitoreo: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Elimina un monitoreo (eliminación lógica)
  Future<bool> eliminarMonitoreo(int id) async {
    try {
      // Si es un monitoreo offline (ID negativo), eliminar directamente de la lista local
      if (id < 0) {
        await _initializeOfflineData();
        _offlineMonitoreos
            .removeWhere((monitoreo) => monitoreo.pmmo_secuencia == id);
        await _saveOfflineMonitoreos();
        notifyListeners();
        return true;
      }

      // Verificar conectividad para monitoreos en servidor
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline pero es un monitoreo del servidor, marcar para eliminación
      if (isOffline) {
        await _initializeOfflineData();

        // Obtener una copia del monitoreo para marcarlo como eliminado
        Monitoreo? monitoreo;
        try {
          // Primero buscar en la caché local
          monitoreo = _offlineMonitoreos.firstWhere(
            (m) => m.pmmo_secuencia == id,
            orElse: () => throw Exception('No encontrado en caché'),
          );
        } catch (e) {
          // Si no está en la caché, crear un monitoreo "fantasma" para marcar eliminación
          monitoreo = Monitoreo(
            pmmo_secuencia: id,
            pmmo_estatus: 0, // Marcar como inactivo
            offlineModifiedAt: DateTime.now(),
            isSynchronized: false,
          );
          _offlineMonitoreos.add(monitoreo);
        }

        // Actualizar el monitoreo marcándolo como eliminado
        int index =
            _offlineMonitoreos.indexWhere((m) => m.pmmo_secuencia == id);
        if (index >= 0) {
          _offlineMonitoreos[index] = monitoreo.copyWith(
              pmmo_estatus: 0, // Marcar como inactivo
              offlineModifiedAt: DateTime.now(),
              isSynchronized: false);
        }

        await _saveOfflineMonitoreos();
        notifyListeners();
        return true;
      }

      // Primero obtener el monitoreo para verificar permisos
      final monitoreo = await getMonitoreoById(id);

      // Verificar si el usuario actual tiene permiso para eliminar este monitoreo
      if (_authService.mustFilterByUser &&
          !_authService.isOwnerOfMonitoreo(monitoreo.pmmo_creadopor ?? 0)) {
        throw Exception(
            'No tienes permiso para eliminar este monitoreo. Solo puedes eliminar monitoreos creados por ti.');
      }

      debugPrint('Eliminando monitoreo con ID: $id');
      final response = await _dio.delete('$monitoreoUrl/$id');

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          debugPrint('Monitoreo eliminado correctamente');

          // Remover de la caché local si existe
          _offlineMonitoreos.removeWhere((m) => m.pmmo_secuencia == id);
          await _saveOfflineMonitoreos();

          notifyListeners(); // Notificar a los listeners sobre la eliminación
          return true;
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al eliminar el monitoreo');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay error de conexión, marcar para eliminación posterior
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();

        // Buscar si ya existe una copia local
        int index =
            _offlineMonitoreos.indexWhere((m) => m.pmmo_secuencia == id);
        if (index >= 0) {
          // Actualizar estado a eliminado
          _offlineMonitoreos[index] = _offlineMonitoreos[index].copyWith(
              pmmo_estatus: 0,
              offlineModifiedAt: DateTime.now(),
              isSynchronized: false);
        } else {
          // Crear entrada "fantasma" para marcar eliminación
          _offlineMonitoreos.add(Monitoreo(
              pmmo_secuencia: id,
              pmmo_estatus: 0,
              offlineModifiedAt: DateTime.now(),
              isSynchronized: false));
        }

        await _saveOfflineMonitoreos();
        notifyListeners();
        return true;
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene la información de un lote por su código
  Future<Map<String, dynamic>> getLoteInfo(String codigo) async {
    try {
      debugPrint('Solicitando información para lote: $codigo');

      final response = await _dio.get('$monitoreoUrl/info-lote/$codigo');

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          // Debug: Imprimir la respuesta
          debugPrint('Datos del lote recibidos: ${response.data['data']}');

          // IMPORTANTE: Verificar si el lote tiene un contenedor y asignar uno por defecto si es necesario
          Map<String, dynamic> loteInfo = response.data['data'];
          if (loteInfo['pmlt_contenedor'] == null ||
              loteInfo['pmlt_contenedor'].toString().isEmpty) {
            print(
                'ADVERTENCIA: Lote del servidor no tiene contenedor, asignando valor por defecto');
            loteInfo['pmlt_contenedor'] = 'CONT_GENERAL';
          }

          print('Contenedor del lote: ${loteInfo['pmlt_contenedor']}');

          return loteInfo;
        } else {
          debugPrint('Error en la respuesta: ${response.data['message']}');
          throw Exception(response.data['message'] ??
              'Error al obtener información del lote');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene las estadísticas resumidas para el dashboard
  Future<Map<String, dynamic>> getEstadisticasResumen() async {
    try {
      debugPrint('Consultando estadísticas de resumen');

      // Si el usuario es monitor, añadir su ID como parámetro
      final Map<String, dynamic> queryParams = {};
      if (_authService.mustFilterByUser) {
        queryParams['usuarioId'] = _authService.getCurrentUserId().toString();
      }

      final response = await _dio.get(
        '$monitoreoUrl/estadisticas/resumen',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          debugPrint('Estadísticas recibidas: ${response.data['data']}');
          return response.data['data'];
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al obtener estadísticas');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene monitoreos por código de lote
  Future<List<Monitoreo>> getMonitoreosByLote(String codigo) async {
    try {
      debugPrint('Consultando monitoreos para lote: $codigo');

      // Si el usuario es monitor, añadir su ID como parámetro
      final Map<String, dynamic> queryParams = {};
      if (_authService.mustFilterByUser) {
        queryParams['usuarioId'] = _authService.getCurrentUserId().toString();
      }

      final response = await _dio.get(
        '$monitoreoUrl/lote/$codigo',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          final List<dynamic> dataList = response.data['data'];
          debugPrint('Monitoreos del lote recibidos: ${dataList.length}');

          List<Monitoreo> monitoreos =
              dataList.map((json) => Monitoreo.fromJson(json)).toList();

          // MODIFICADO: Aplicar filtrado adicional para usuarios monitoreadores
          if (_authService.isMonitoreador) {
            final userId = _authService.getCurrentUserId();
            monitoreos = monitoreos
                .where((monitoreo) => monitoreo.pmmo_creadopor == userId)
                .toList();
          }

          // Añadir monitoreos offline para este lote
          await _initializeOfflineData();
          final offlineMonitoreosForLote =
              _offlineMonitoreos.where((m) => m.pmlt_codigo == codigo).toList();

          // Combinar resultados
          monitoreos = [...monitoreos, ...offlineMonitoreosForLote];

          return monitoreos;
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(response.data['message'] ??
              'Error al obtener monitoreos del lote');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay error de conexión, intentar retornar datos offline para este lote
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();
        return _offlineMonitoreos
            .where((m) => m.pmlt_codigo == codigo)
            .toList();
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene todas las plagas activas
  Future<List<Map<String, dynamic>>> getPlagasActivas() async {
    try {
      debugPrint('Consultando plagas activas');
      final response = await _dio.get('$monitoreoUrl/plagas/activas');

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          final List<dynamic> dataList = response.data['data'];
          debugPrint('Plagas activas recibidas: ${dataList.length}');
          return dataList.cast<Map<String, dynamic>>();
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(
              response.data['message'] ?? 'Error al obtener plagas activas');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene los nombres de todas las plagas activas
  Future<List<String>> getPlagasActivasNombres() async {
    try {
      // Obtener las plagas activas directamente del servidor
      debugPrint('Consultando nombres de plagas activas');
      final response = await _dio.get('$monitoreoUrl/plagas/activas');

      if (response.statusCode == 200) {
        debugPrint('Respuesta plagas activas: ${response.data}');

        List<dynamic> dataList;

        // Determinar dónde están los datos dependiendo del formato de respuesta
        if (response.data is List) {
          // Si la respuesta es directamente una lista
          dataList = response.data;
        } else if (response.data is Map && response.data.containsKey('data')) {
          // Si la respuesta es un mapa con un campo 'data'
          var data = response.data['data'];
          if (data is List) {
            dataList = data;
          } else {
            debugPrint('El campo data no es una lista: $data');
            return ['Plaga genérica'];
          }
        } else {
          // Si no podemos identificar el formato, devolver plaga genérica
          debugPrint('Formato de respuesta no reconocido: ${response.data}');
          return ['Plaga genérica'];
        }

        final List<String> nombres = [];

        // Extraer solo los nombres de las plagas
        for (var plaga in dataList) {
          debugPrint('Analizando plaga: $plaga');

          // Verificar que plaga sea un Map
          if (plaga is Map) {
            // Intentar obtener el nombre común de varias formas posibles
            if (plaga.containsKey('pmni_nombrecomun')) {
              String? nombre = plaga['pmni_nombrecomun'];
              if (nombre != null &&
                  nombre.isNotEmpty &&
                  !nombres.contains(nombre)) {
                nombres.add(nombre);
                debugPrint('Añadido nombre por pmni_nombrecomun: $nombre');
              }
            } else if (plaga.containsKey('pmpl_nombrecomun')) {
              // <-- AQUÍ ESTÁ LA CORRECCIÓN: Usar pmpl_nombrecomun
              String? nombre = plaga['pmpl_nombrecomun'];
              if (nombre != null &&
                  nombre.isNotEmpty &&
                  !nombres.contains(nombre)) {
                nombres.add(nombre);
                debugPrint('Añadido nombre por pmpl_nombrecomun: $nombre');
              }
            } else if (plaga.containsKey('nombrecomun')) {
              String? nombre = plaga['nombrecomun'];
              if (nombre != null &&
                  nombre.isNotEmpty &&
                  !nombres.contains(nombre)) {
                nombres.add(nombre);
                debugPrint('Añadido nombre por nombrecomun: $nombre');
              }
            } else if (plaga.containsKey('nombre')) {
              String? nombre = plaga['nombre'];
              if (nombre != null &&
                  nombre.isNotEmpty &&
                  !nombres.contains(nombre)) {
                nombres.add(nombre);
                debugPrint('Añadido nombre por nombre: $nombre');
              }
            } else if (plaga.containsKey('descripcion')) {
              String? nombre = plaga['descripcion'];
              if (nombre != null &&
                  nombre.isNotEmpty &&
                  !nombres.contains(nombre)) {
                nombres.add(nombre);
                debugPrint('Añadido nombre por descripcion: $nombre');
              }
            } else {
              debugPrint('No se encontró campo de nombre en plaga: $plaga');
            }
          }
        }

        // Si no hay nombres, devolver una plaga genérica
        if (nombres.isEmpty) {
          debugPrint('No se encontraron nombres de plagas válidos');
          return ['Plaga genérica'];
        }

        debugPrint('Nombres de plagas encontrados: $nombres');
        return nombres;
      } else {
        debugPrint('Error en código HTTP: ${response.statusCode}');
        return ['Plaga genérica'];
      }
    } on DioException catch (e) {
      _handleDioError(e);
      debugPrint('Error al obtener nombres de plagas activas: ${e.message}');
      return ['Plaga genérica'];
    } catch (e) {
      debugPrint('Error al obtener nombres de plagas activas: $e');
      return ['Plaga genérica'];
    }
  }

  /// Crea un monitoreo con cálculo automático de niveles
  Future<Monitoreo> crearMonitoreoConNivelesAutomaticos(
      Monitoreo monitoreo, List<int> muestras) async {
    try {
      // Verificar conectividad
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline, guardar localmente
      if (isOffline) {
        await _initializeOfflineData();

        // Crear monitoreo con muestras
        final monitoreoConMuestras = monitoreo.copyWith(
          pmmo_muestra1: muestras[0],
          pmmo_muestra2: muestras.length > 1 ? muestras[1] : 0,
          pmmo_muestra3: muestras.length > 2 ? muestras[2] : 0,
          // Asignar niveles temporales basados en las muestras (lógica simplificada)
          pmmo_nivmuestram1:
              1 + (muestras[0] > 10 ? 1 : 0) + (muestras[0] > 20 ? 1 : 0),
          pmmo_nivmuestram2: muestras.length > 1
              ? 1 + (muestras[1] > 10 ? 1 : 0) + (muestras[1] > 20 ? 1 : 0)
              : 1,
          pmmo_nivmuestram3: muestras.length > 2
              ? 1 + (muestras[2] > 10 ? 1 : 0) + (muestras[2] > 20 ? 1 : 0)
              : 1,
          pmmo_nivmuestraa1:
              1 + (muestras[0] > 10 ? 1 : 0) + (muestras[0] > 20 ? 1 : 0),
          pmmo_nivmuestraa2: muestras.length > 1
              ? 1 + (muestras[1] > 10 ? 1 : 0) + (muestras[1] > 20 ? 1 : 0)
              : 1,
          pmmo_nivmuestraa3: muestras.length > 2
              ? 1 + (muestras[2] > 10 ? 1 : 0) + (muestras[2] > 20 ? 1 : 0)
              : 1,
        );

        // Crear monitoreo offline con ID negativo temporal
        final offlineMonitoreo =
            Monitoreo.offline(monitoreoConMuestras.toJson());

        // Añadir a la lista local
        _offlineMonitoreos.add(offlineMonitoreo);
        await _saveOfflineMonitoreos();

        notifyListeners();
        return offlineMonitoreo;
      }

      // IMPORTANTE: Verificar si el monitoreo tiene un contenedor antes de enviarlo
      if (monitoreo.pmmo_contenedor == null ||
          monitoreo.pmmo_contenedor!.isEmpty) {
        print(
            'ADVERTENCIA: Contenedor vacío en crearMonitoreoConNivelesAutomaticos, asignando valor por defecto');
        monitoreo = monitoreo.copyWith(pmmo_contenedor: 'CONT_GENERAL');
      }

      // Asegurar que el ID del usuario actual se establezca como creador
      monitoreo =
          monitoreo.copyWith(pmmo_creadopor: _authService.getCurrentUserId());

      // Preparar datos para enviar
      final Map<String, dynamic> data = monitoreo.toJson();
      data['pmmo_muestra1'] = muestras[0];
      data['pmmo_muestra2'] = muestras.length > 1 ? muestras[1] : 0;
      data['pmmo_muestra3'] = muestras.length > 2 ? muestras[2] : 0;

      // Imprimir para depuración
      print(
          'Contenedor en monitoreo con niveles automáticos: ${data['pmmo_contenedor']}');

      debugPrint('Creando monitoreo con niveles automáticos: $data');
      final response = await _dio.post(
        '$monitoreoUrl/auto-niveles',
        data: data,
      );

      if (response.statusCode == 201) {
        if (_isSuccessValue(response.data['success'])) {
          debugPrint(
              'Monitoreo con niveles automáticos creado: ${response.data['data']}');
          final nuevoMonitoreo = Monitoreo.fromJson(response.data['data']);
          notifyListeners();
          return nuevoMonitoreo;
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(response.data['message'] ??
              'Error al crear monitoreo con niveles automáticos');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay error de conexión, guardar localmente
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();

        // Crear monitoreo con muestras
        final monitoreoConMuestras = monitoreo.copyWith(
          pmmo_muestra1: muestras[0],
          pmmo_muestra2: muestras.length > 1 ? muestras[1] : 0,
          pmmo_muestra3: muestras.length > 2 ? muestras[2] : 0,
          // Asignar niveles temporales basados en las muestras (lógica simplificada)
          pmmo_nivmuestram1:
              1 + (muestras[0] > 10 ? 1 : 0) + (muestras[0] > 20 ? 1 : 0),
          pmmo_nivmuestram2: muestras.length > 1
              ? 1 + (muestras[1] > 10 ? 1 : 0) + (muestras[1] > 20 ? 1 : 0)
              : 1,
          pmmo_nivmuestram3: muestras.length > 2
              ? 1 + (muestras[2] > 10 ? 1 : 0) + (muestras[2] > 20 ? 1 : 0)
              : 1,
          pmmo_nivmuestraa1:
              1 + (muestras[0] > 10 ? 1 : 0) + (muestras[0] > 20 ? 1 : 0),
          pmmo_nivmuestraa2: muestras.length > 1
              ? 1 + (muestras[1] > 10 ? 1 : 0) + (muestras[1] > 20 ? 1 : 0)
              : 1,
          pmmo_nivmuestraa3: muestras.length > 2
              ? 1 + (muestras[2] > 10 ? 1 : 0) + (muestras[2] > 20 ? 1 : 0)
              : 1,
        );

        // Crear monitoreo offline
        final offlineMonitoreo =
            Monitoreo.offline(monitoreoConMuestras.toJson());

        // Añadir a la lista local
        _offlineMonitoreos.add(offlineMonitoreo);
        await _saveOfflineMonitoreos();

        notifyListeners();
        return offlineMonitoreo;
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene las configuraciones de niveles de plagas
  Future<Map<String, dynamic>> getNivelesPlaga(String plagaNombre) async {
    try {
      debugPrint('Consultando niveles para plaga: $plagaNombre');
      final url = '$monitoreoUrl/niveles/$plagaNombre';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          debugPrint('Niveles de plaga recibidos: ${response.data['data']}');
          return response.data['data'];
        } else {
          debugPrint('Error en respuesta: ${response.data['message']}');
          throw Exception(
              'Error al obtener niveles de plaga: ${response.statusCode}');
        }
      } else {
        debugPrint('Error en código de estado: ${response.statusCode}');
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Comprueba si un usuario tiene permiso para editar un monitoreo específico
  bool canEditMonitoreo(Monitoreo monitoreo) {
    // Si es admin, siempre puede editar
    if (_authService.isAdmin) return true;

    // Si es monitoreador, solo puede editar sus propios monitoreos
    if (_authService.isMonitoreador) {
      return _authService.isOwnerOfMonitoreo(monitoreo.pmmo_creadopor ?? 0);
    }

    // Para cualquier otro rol, seguir reglas específicas o denegar por defecto
    return false;
  }

  /// Comprueba si un usuario tiene permiso para eliminar un monitoreo específico
  bool canDeleteMonitoreo(Monitoreo monitoreo) {
    // Si es admin, siempre puede eliminar
    if (_authService.isAdmin) return true;

    // Si es monitoreador, solo puede eliminar sus propios monitoreos
    if (_authService.isMonitoreador) {
      return _authService.isOwnerOfMonitoreo(monitoreo.pmmo_creadopor ?? 0);
    }

    // Para cualquier otro rol, seguir reglas específicas o denegar por defecto
    return false;
  }

  /// Obtiene monitoreos por período reciente (días)
  Future<List<Monitoreo>> getMonitoreosRecientes(int dias,
      {int? usuarioId}) async {
    try {
      debugPrint('Consultando monitoreos recientes (últimos $dias días)');

      final Map<String, dynamic> queryParams = {};
      if (usuarioId != null) {
        queryParams['usuarioId'] = usuarioId.toString();
      }

      final response = await _dio.get(
        '$monitoreoUrl/recientes/$dias',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          final List<dynamic> dataList = response.data['data'];
          final monitoreos =
              dataList.map((json) => Monitoreo.fromJson(json)).toList();

          return monitoreos;
        } else {
          throw Exception(response.data['message'] ??
              'Error al obtener monitoreos recientes');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay error de conexión, intentar retornar datos offline recientes
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();

        // Filtrar por días
        final DateTime limitDate =
            DateTime.now().subtract(Duration(days: dias));
        return _offlineMonitoreos
            .where(
                (m) => m.pmmo_fecha != null && m.pmmo_fecha!.isAfter(limitDate))
            .toList();
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene datos para mapa de calor de plagas
  Future<List<Map<String, dynamic>>> getMapaCalor(
      {DateTime? fechaInicio, DateTime? fechaFin, String? plaga}) async {
    try {
      final Map<String, dynamic> queryParams = {};

      if (fechaInicio != null) {
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      }

      if (fechaFin != null) {
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      }

      if (plaga != null && plaga != 'Todas') {
        queryParams['plaga'] = plaga;
      }

      final response = await _dio.get(
        '$monitoreoUrl/mapa-calor',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          return List<Map<String, dynamic>>.from(response.data['data']);
        } else {
          throw Exception(
              response.data['message'] ?? 'Error al obtener mapa de calor');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Compara monitoreos entre lotes
  Future<Map<String, dynamic>> compararLotes(List<String> lotes,
      {int dias = 30}) async {
    try {
      final Map<String, dynamic> queryParams = {
        'lotes': lotes,
        'dias': dias.toString()
      };

      debugPrint(
          'Comparando lotes: ${lotes.join(", ")} en los últimos $dias días');

      final response = await _dio.get(
        '$monitoreoUrl/comparar-lotes',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          return response.data['data'];
        } else {
          throw Exception(
              response.data['message'] ?? 'Error al comparar lotes');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene tendencias de plagas por periodo
  Future<List<Map<String, dynamic>>> getTendenciasPlagas(String periodo,
      {int? usuarioId}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (usuarioId != null) {
        queryParams['usuarioId'] = usuarioId.toString();
      }

      final response = await _dio.get(
        '$monitoreoUrl/tendencias/$periodo',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          return List<Map<String, dynamic>>.from(response.data['data']);
        } else {
          throw Exception(
              response.data['message'] ?? 'Error al obtener tendencias');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Importa múltiples monitoreos en una sola operación
  Future<Map<String, dynamic>> importarMonitoreos(
      List<Monitoreo> monitoreos) async {
    try {
      // Verificar conectividad
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline, guardar todos localmente
      if (isOffline) {
        await _initializeOfflineData();

        // Convertir todos los monitoreos a formato offline
        final listaOffline =
            monitoreos.map((m) => Monitoreo.offline(m.toJson())).toList();

        // Añadir a la lista local
        _offlineMonitoreos.addAll(listaOffline);
        await _saveOfflineMonitoreos();

        notifyListeners();

        return {
          'success': true,
          'message':
              'Monitoreos guardados localmente para sincronización posterior',
          'data': {
            'total': monitoreos.length,
            'exitosos': monitoreos.length,
            'fallidos': 0,
            'resultados': listaOffline
                .map((m) => {
                      'success': true,
                      'message': 'Guardado para sincronización',
                      'id': m.pmmo_secuencia
                    })
                .toList()
          }
        };
      }

      final List<Map<String, dynamic>> monitoreosJson =
          monitoreos.map((m) => m.toJson()).toList();

      final response = await _dio.post(
        '$monitoreoUrl/importar',
        data: {'monitoreos': monitoreosJson},
      );

      if (response.statusCode == 200) {
        if (_isSuccessValue(response.data['success'])) {
          debugPrint('Importación completada: ${response.data['data']}');

          // Actualizar datos offline si aplica
          if (response.data['data']['exitosos'] > 0) {
            // Implementar lógica para actualizar estado de monitoreos importados
            notifyListeners();
          }

          return response.data;
        } else {
          throw Exception(
              response.data['message'] ?? 'Error al importar monitoreos');
        }
      } else {
        throw Exception('Error en la solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);

      // Si hay error de conexión, guardar todos localmente
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _initializeOfflineData();

        // Convertir todos los monitoreos a formato offline
        final listaOffline =
            monitoreos.map((m) => Monitoreo.offline(m.toJson())).toList();

        // Añadir a la lista local
        _offlineMonitoreos.addAll(listaOffline);
        await _saveOfflineMonitoreos();

        notifyListeners();

        return {
          'success': true,
          'message':
              'Monitoreos guardados localmente para sincronización posterior',
          'data': {
            'total': monitoreos.length,
            'exitosos': monitoreos.length,
            'fallidos': 0,
            'resultados': listaOffline
                .map((m) => {
                      'success': true,
                      'message': 'Guardado para sincronización',
                      'id': m.pmmo_secuencia
                    })
                .toList()
          }
        };
      }

      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Sincroniza monitoreos offline con el servidor
  Future<Map<String, dynamic>> sincronizarMonitoreosOffline() async {
    try {
      await _initializeOfflineData();

      // Verificar conectividad
      final connectivityResult = await (Connectivity().checkConnectivity());
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Si estamos offline, no podemos sincronizar
      if (isOffline) {
        return {
          'success': false,
          'message': 'No hay conexión a internet disponible para sincronizar',
          'data': {
            'pendientes':
                _offlineMonitoreos.where((m) => m.needsSynchronization()).length
          }
        };
      }

      // Filtrar monitoreos que necesitan sincronización
      final monitoreosPendientes =
          _offlineMonitoreos.where((m) => m.needsSynchronization()).toList();

      if (monitoreosPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay monitoreos pendientes de sincronización',
          'data': {'sincronizados': 0, 'pendientes': 0}
        };
      }

      // Resultados de la sincronización
      final Map<String, dynamic> resultados = {
        'total': monitoreosPendientes.length,
        'exitosos': 0,
        'fallidos': 0,
        'detalles': <Map<String, dynamic>>[]
      };

      // Procesar cada monitoreo pendiente
      for (final monitoreo in monitoreosPendientes) {
        try {
          // Si tiene ID negativo, es un monitoreo creado offline
          if (monitoreo.isTemporary()) {
            // Remover el ID temporal para crearlo en el servidor
            final nuevoMonitoreo = monitoreo.copyWith(
                pmmo_secuencia: null,
                isOfflineCreated: false,
                isSynchronized: true);

            // Crear en el servidor
            final creadoMonitoreo = await crearMonitoreo(nuevoMonitoreo);

            resultados['exitosos'] = resultados['exitosos'] + 1;
            resultados['detalles'].add({
              'id': monitoreo.pmmo_secuencia,
              'nuevoId': creadoMonitoreo.pmmo_secuencia,
              'tipo': 'creación',
              'success': true
            });

            // Remover de la lista offline
            _offlineMonitoreos.removeWhere(
                (m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
          }
          // Si tiene estatus = 0, es una eliminación pendiente
          else if (monitoreo.pmmo_estatus == 0) {
            // Eliminar en el servidor
            await _dio.delete('$monitoreoUrl/${monitoreo.pmmo_secuencia}');

            resultados['exitosos'] = resultados['exitosos'] + 1;
            resultados['detalles'].add({
              'id': monitoreo.pmmo_secuencia,
              'tipo': 'eliminación',
              'success': true
            });

            // Remover de la lista offline
            _offlineMonitoreos.removeWhere(
                (m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
          }
          // De lo contrario, es una actualización pendiente
          else {
            // Marcar como sincronizado
            final actualizadoMonitoreo =
                monitoreo.copyWith(isSynchronized: true);

            // Actualizar en el servidor
            await actualizarMonitoreo(actualizadoMonitoreo);

            resultados['exitosos'] = resultados['exitosos'] + 1;
            resultados['detalles'].add({
              'id': monitoreo.pmmo_secuencia,
              'tipo': 'actualización',
              'success': true
            });

            // Actualizar estado en la lista offline o remover
            int index = _offlineMonitoreos.indexWhere(
                (m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
            if (index >= 0) {
              _offlineMonitoreos[index] = actualizadoMonitoreo;
            }
          }
        } catch (e) {
          debugPrint(
              'Error al sincronizar monitoreo ${monitoreo.pmmo_secuencia}: $e');
          resultados['fallidos'] = resultados['fallidos'] + 1;
          resultados['detalles'].add({
            'id': monitoreo.pmmo_secuencia,
            'tipo': monitoreo.isTemporary()
                ? 'creación'
                : (monitoreo.pmmo_estatus == 0
                    ? 'eliminación'
                    : 'actualización'),
            'success': false,
            'error': e.toString()
          });
        }
      }

      // Guardar cambios en la lista offline
      await _saveOfflineMonitoreos();
      notifyListeners();

      return {
        'success': true,
        'message':
            'Sincronización completada: ${resultados['exitosos']} exitosos, ${resultados['fallidos']} fallidos',
        'data': resultados
      };
    } catch (e) {
      debugPrint('Error en sincronización: $e');
      return {
        'success': false,
        'message': 'Error durante la sincronización: $e',
        'data': null
      };
    }
  }

  /// Obtiene la lista de monitoreos offline pendientes de sincronización
  List<Monitoreo> getMonitoreosOfflinePendientes() {
    return _offlineMonitoreos.where((m) => m.needsSynchronization()).toList();
  }

  /// Obtiene el conteo de monitoreos pendientes de sincronización
  int getConteoMonitoreosOfflinePendientes() {
    return _offlineMonitoreos.where((m) => m.needsSynchronization()).length;
  }

  /// Limpia todos los datos offline
  Future<void> limpiarDatosOffline() async {
    _offlineMonitoreos.clear();
    await _saveOfflineMonitoreos();
    notifyListeners();
  }
}
