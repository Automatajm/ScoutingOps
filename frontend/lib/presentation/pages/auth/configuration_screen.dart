import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/config/flavor_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:js' as js; // Para comunicación con JavaScript

class ConfigurationScreen extends StatefulWidget {
  final ApiConfig apiConfig;
  final VoidCallback onConfigSuccess;

  const ConfigurationScreen({
    Key? key,
    required this.apiConfig,
    required this.onConfigSuccess,
  }) : super(key: key);

  @override
  _ConfigurationScreenState createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isResetting = false;
  bool _isAutoDetecting = false; // ✅ NUEVO: Estado de detección automática
  String _errorMessage = '';
  String _successMessage = '';
  final _dio = Dio();
  List<String> _suggestedUrls = [];
  Map<String, dynamic> _connectionInfo = {};
  String _detectedConnectionType = '';

  // ✅ NUEVO: Variables para detección automática
  Map<String, dynamic>? _autoDetectedConfig;
  bool _autoDetectionCompleted = false;
  String _autoDetectionStatus = '';

  @override
  void initState() {
    super.initState();
    _initializeWithAutoDetection(); // ✅ NUEVO: Inicialización híbrida
    _setupDioInterceptors();
  }

  // ✅ NUEVO: Inicialización híbrida que integra detección automática
  Future<void> _initializeWithAutoDetection() async {
    if (kDebugMode) {
      print('🔄 Iniciando ConfigurationScreen con detección automática...');
    }

    // Paso 1: Verificar si ya hay configuración manual guardada
    if (widget.apiConfig.isConfigured && widget.apiConfig.baseUrl.isNotEmpty) {
      // Ya está configurado - usar configuración existente
      _urlController.text = widget.apiConfig.baseUrl
          .replaceAll('http://', '')
          .replaceAll('https://', '');

      if (kDebugMode) {
        print('✅ Usando configuración existente: ${_urlController.text}');
      }

      _finalizarInicializacion();
      return;
    }

    // Paso 2: Intentar detección automática
    await _intentarDeteccionAutomatica();
  }

  // ✅ NUEVO: Intenta detección automática de red
  Future<void> _intentarDeteccionAutomatica() async {
    if (!kIsWeb) {
      // Para móvil, usar configuración por defecto
      _urlController.text = _getDefaultUrl().replaceAll('https://', '');
      _finalizarInicializacion();
      return;
    }

    setState(() {
      _isAutoDetecting = true;
      _autoDetectionStatus = 'Detectando red automáticamente...';
    });

    try {
      if (kDebugMode) {
        print('🔍 Iniciando detección automática para web...');
      }

      // Intentar obtener configuración del NetworkBridge
      final config = await _obtenerConfiguracionWeb();

      if (config != null && config['detected'] == true) {
        // ✅ Detección exitosa
        _autoDetectedConfig = config;
        _autoDetectionCompleted = true;

        // Pre-completar campo con IP detectada
        final recommendedUrl = config['recommendedUrl']?.toString() ?? '';
        _urlController.text =
            recommendedUrl.replaceAll('https://', '').replaceAll('http://', '');

        // Actualizar URLs sugeridas con las detectadas
        if (config['suggestedUrls'] is List) {
          _suggestedUrls = List<String>.from(config['suggestedUrls']);
        }

        setState(() {
          _autoDetectionStatus =
              '✅ Red detectada automáticamente: ${config['detectedIP']}';
        });

        if (kDebugMode) {
          print('✅ Detección automática exitosa: ${config['detectedIP']}');
          print('   URL recomendada: ${config['recommendedUrl']}');
          print('   Protocolo: ${config['detectedProtocol']}');
        }
      } else {
        // ⚠️ Detección falló - usar valores por defecto
        _urlController.text = _getDefaultUrl().replaceAll('https://', '');
        setState(() {
          _autoDetectionStatus =
              '⚠️ Detección automática falló - usando valores por defecto';
        });
      }
    } catch (e) {
      // Error en detección - usar valores por defecto
      if (kDebugMode) {
        print('❌ Error en detección automática: $e');
      }

      _urlController.text = _getDefaultUrl().replaceAll('https://', '');
      setState(() {
        _autoDetectionStatus =
            '❌ Error en detección - usando valores por defecto';
      });
    } finally {
      setState(() {
        _isAutoDetecting = false;
      });

      _finalizarInicializacion();
    }
  }

  // ✅ NUEVO: Obtiene configuración del NetworkBridge JavaScript
  Future<Map<String, dynamic>?> _obtenerConfiguracionWeb() async {
    if (!kIsWeb) return null;

    try {
      // Intentar obtener configuración inmediatamente
      final config = js.context.callMethod('getFlutterNetworkConfig');

      if (config != null) {
        return Map<String, dynamic>.from(config);
      }

      // Si no está disponible, esperar un poco y reintentar
      await Future.delayed(const Duration(milliseconds: 3000));

      final configRetry = js.context.callMethod('getFlutterNetworkConfig');
      if (configRetry != null) {
        return Map<String, dynamic>.from(configRetry);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo configuración web: $e');
      }
      return null;
    }
  }

  // ✅ NUEVO: Finaliza la inicialización con datos cargados
  void _finalizarInicializacion() {
    // Generar URLs sugeridas si no las tenemos
    if (_suggestedUrls.isEmpty) {
      _suggestedUrls = widget.apiConfig.suggestedUrls.isNotEmpty
          ? widget.apiConfig.suggestedUrls
          : _generateHttpsSuggestedUrls();
    }

    // Detectar tipo de conexión
    _detectedConnectionType = _detectConnectionType(_urlController.text);

    if (kDebugMode) {
      print('=== ✅ INICIALIZACIÓN COMPLETADA ===');
      print('URL inicial: ${_urlController.text}');
      print('URLs sugeridas: ${_suggestedUrls.length}');
      print('Tipo detectado: $_detectedConnectionType');
      print('Detección automática: $_autoDetectionCompleted');
      print('Configurado: ${widget.apiConfig.isConfigured}');
      print('====================================');
    }
  }

  // ✅ NUEVO: Botón para re-detectar red
  Future<void> _redetectarRed() async {
    if (!kIsWeb) return;

    setState(() {
      _isAutoDetecting = true;
      _autoDetectionStatus = 'Re-detectando red...';
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      if (kDebugMode) {
        print('🔄 Re-detectando red por solicitud del usuario...');
      }

      // Llamar función JavaScript para re-detectar
      final config = await js.context.callMethod('redetectNetworkForFlutter');

      if (config != null) {
        final configMap = Map<String, dynamic>.from(config);

        if (configMap['detected'] == true) {
          _autoDetectedConfig = configMap;

          // Actualizar campo con nueva IP detectada
          final recommendedUrl = configMap['recommendedUrl']?.toString() ?? '';
          _urlController.text = recommendedUrl
              .replaceAll('https://', '')
              .replaceAll('http://', '');

          // Actualizar URLs sugeridas
          if (configMap['suggestedUrls'] is List) {
            _suggestedUrls = List<String>.from(configMap['suggestedUrls']);
          }

          setState(() {
            _autoDetectionStatus =
                '✅ Red re-detectada: ${configMap['detectedIP']}';
            _detectedConnectionType =
                _detectConnectionType(_urlController.text);
          });

          if (kDebugMode) {
            print('✅ Re-detección exitosa: ${configMap['detectedIP']}');
          }
        } else {
          setState(() {
            _autoDetectionStatus = '⚠️ No se detectó servidor activo';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en re-detección: $e');
      }

      setState(() {
        _autoDetectionStatus = '❌ Error en re-detección';
      });
    } finally {
      setState(() {
        _isAutoDetecting = false;
      });
    }
  }

  // TU CÓDIGO EXISTENTE - Sin cambios
  void _setupDioInterceptors() {
    // Configurar timeouts globales para Dio
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 25);
    _dio.options.sendTimeout = const Duration(seconds: 20);

    // Interceptores para debugging y compatibilidad
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Headers especiales para ngrok
        if (options.baseUrl.contains('ngrok') ||
            options.path.contains('ngrok')) {
          options.headers['ngrok-skip-browser-warning'] = 'true';
        }

        // Headers estándar
        options.headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'PestControl-Flutter-App/1.0',
        });

        developer.log(
            '🌐 REQUEST: ${options.method} ${options.baseUrl}${options.path}',
            name: 'API_CONFIG');
        handler.next(options);
      },
      onResponse: (response, handler) {
        developer.log(
            '✅ RESPONSE: ${response.statusCode} from ${response.requestOptions.path}',
            name: 'API_CONFIG');
        handler.next(response);
      },
      onError: (error, handler) {
        developer.log('❌ ERROR: ${error.type} - ${error.message}',
            name: 'API_CONFIG');
        handler.next(error);
      },
    ));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // TU CÓDIGO EXISTENTE - Sin cambios
  String _formatUrl(String url) {
    url = url.trim();

    // Detección inteligente de protocolo - PRIORIZAR HTTPS
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // ✅ Siempre usar HTTPS por defecto
      url = 'https://$url';
    }

    // Limpiar URL
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }

    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  // TU CÓDIGO EXISTENTE - Sin cambios
  String _getDefaultUrl() {
    if (kIsWeb) {
      return 'https://localhost:8000'; // Fallback seguro para web
    }
    if (!kIsWeb && Platform.isAndroid) {
      return kDebugMode ? 'https://10.0.2.2:8000' : 'https://localhost:8000';
    }
    if (!kIsWeb && Platform.isIOS) {
      return kDebugMode ? 'https://localhost:8000' : 'https://localhost:8000';
    }
    return 'https://localhost:8000';
  }

  // TU CÓDIGO EXISTENTE - Sin cambios
  List<String> _generateHttpsSuggestedUrls() {
    List<String> suggestions = [];

    // ✅ URLs HTTPS locales PRIMERO
    suggestions.addAll([
      'https://localhost:8000', // Fallback seguro
      'https://127.0.0.1:8000',
    ]);

    // URLs HTTPS de red común
    suggestions.addAll([
      'https://192.168.1.100:8000',
      'https://192.168.0.100:8000',
      'https://10.0.0.19:8000',
    ]);

    // Emulador Android HTTPS
    if (!kIsWeb && Platform.isAndroid && kDebugMode) {
      suggestions.add('https://10.0.2.2:8000');
    }

    // Servicios externos HTTPS
    suggestions.addAll([
      'https://xxx.ngrok-free.app',
      'https://xxx.ngrok.io',
      'https://xxx.loca.lt',
    ]);

    // ⚠️ URLs HTTP como fallback (al final)
    suggestions.addAll([
      'http://localhost:8000',
      'http://127.0.0.1:8000',
    ]);

    return suggestions;
  }

  // TU CÓDIGO EXISTENTE - Sin cambios (todo el resto de métodos)
  Future<void> _resetConfiguration() async {
    final confirmed = await _showResetDialog();
    if (!confirmed) return;

    setState(() {
      _isResetting = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      if (kDebugMode) {
        print('🔄 Reseteando configuración...');
      }

      // Reset en ApiConfig
      await widget.apiConfig.reset();

      // Re-ejecutar detección automática
      _autoDetectedConfig = null;
      _autoDetectionCompleted = false;
      await _intentarDeteccionAutomatica();

      _mostrarMensajeExito('🔄 Configuración reseteada exitosamente\n\n'
          '✅ Valores por defecto restaurados\n'
          '🔍 Detección automática re-ejecutada\n'
          '🔧 Ready para nueva configuración');

      if (kDebugMode) {
        print('✅ Reset completado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en reset: $e');
      }
      _mostrarMensajeError('❌ Error al resetear configuración: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  Future<bool> _showResetDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text('Resetear Configuración'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Está seguro que desea resetear la configuración?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Esto eliminará:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('• Configuración actual guardada'),
                        const Text('• URLs personalizadas'),
                        const Text('• Información de conexión'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ Y restaurará:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('• Valores por defecto HTTPS'),
                        const Text('• URLs sugeridas actualizadas'),
                        const Text('• Nueva detección automática'),
                        const Text('• Configuración limpia'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Resetear'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // TU CÓDIGO EXISTENTE DE CONEXIÓN - Sin cambios importantes
  Future<void> _probarConexion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
      _connectionInfo = {};
    });

    try {
      final baseUrl = _formatUrl(_urlController.text);
      final apiUrl = '$baseUrl/api';

      if (kDebugMode) {
        print('🔍 Probando conexión:');
        print('   Base URL: $baseUrl');
        print('   API URL: $apiUrl');
      }

      // Endpoints a probar en orden de preferencia
      final endpoints = [
        '$apiUrl/config', // Endpoint preferido
        '$apiUrl/system/status', // Status del sistema
        '$apiUrl/health', // Health check
        baseUrl, // URL base
        '$apiUrl/diagnostico', // Diagnóstico
      ];

      Response? successResponse;
      String workingEndpoint = '';
      Map<String, dynamic> serverConfig = {};

      // Probar cada endpoint
      for (var endpoint in endpoints) {
        try {
          developer.log('🌐 Probando: $endpoint', name: 'API_CONFIG');

          final response = await _dio.get(
            endpoint,
            options: Options(
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: true,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
            ),
          );

          if (response.statusCode == 200) {
            bool isValidResponse = false;

            if (endpoint.contains('/api/')) {
              if (response.data is Map) {
                final data = response.data as Map;
                if (data['success'] == true ||
                    data.containsKey('message') ||
                    data.containsKey('apiUrl') ||
                    data.containsKey('status')) {
                  isValidResponse = true;
                  serverConfig = Map<String, dynamic>.from(data);
                }
              }
            } else {
              isValidResponse = true;
              if (response.data is Map) {
                serverConfig = Map<String, dynamic>.from(response.data);
              }
            }

            if (isValidResponse) {
              successResponse = response;
              workingEndpoint = endpoint;
              developer.log('✅ Endpoint exitoso: $endpoint',
                  name: 'API_CONFIG');
              break;
            }
          }
        } catch (e) {
          developer.log('❌ Error en $endpoint: $e', name: 'API_CONFIG');
          continue;
        }
      }

      if (successResponse != null) {
        await _procesarRespuestaExitosa(
            baseUrl, apiUrl, serverConfig, workingEndpoint);
      } else {
        _mostrarMensajeError('❌ No se pudo conectar al servidor\n\n'
            '🔍 Endpoints probados: ${endpoints.length}\n'
            '💡 Verifique que el servidor esté ejecutándose en la URL especificada\n'
            '🔒 Para HTTPS, asegúrese que el certificado esté configurado');
      }
    } catch (e) {
      _manejarErrorConexion(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _procesarRespuestaExitosa(String baseUrl, String apiUrl,
      Map<String, dynamic> serverConfig, String workingEndpoint) async {
    if (kDebugMode) {
      print('🎉 Procesando respuesta exitosa:');
      print('   Base URL: $baseUrl');
      print('   API URL: $apiUrl');
      print('   Endpoint: $workingEndpoint');
    }

    // CRÍTICO: Esto marca la configuración como MANUAL
    await widget.apiConfig.updateBaseUrl(baseUrl);

    // Actualizar información de conexión
    _connectionInfo = {
      'baseUrl': baseUrl,
      'workingEndpoint': workingEndpoint,
      'connectionType': _detectConnectionType(baseUrl),
      'timestamp': DateTime.now().toIso8601String(),
      'detectionMethod':
          _autoDetectedConfig != null ? 'auto-detected' : 'manual',
    };

    if (serverConfig.containsKey('systemInfo')) {
      _connectionInfo['systemInfo'] = serverConfig['systemInfo'];
    }

    if (serverConfig.containsKey('connectionInfo')) {
      _connectionInfo['connectionInfo'] = serverConfig['connectionInfo'];
    }

    _detectedConnectionType = widget.apiConfig.getConnectionType();

    if (widget.apiConfig.suggestedUrls.isNotEmpty) {
      setState(() {
        _suggestedUrls = widget.apiConfig.suggestedUrls;
      });
    }

    // Construir mensaje de éxito
    final version = serverConfig['version'] ?? 'N/A';
    final environment = serverConfig['environment'] ?? 'Desarrollo';
    final connectionType = _detectedConnectionType.toUpperCase();
    final protocol = baseUrl.startsWith('https://') ? 'HTTPS ✅' : 'HTTP ⚠️';
    final detectionInfo = _autoDetectedConfig != null
        ? '\n🤖 Detectado automáticamente'
        : '\n👤 Configurado manualmente';

    String successMsg = '✅ Configuración guardada exitosamente\n\n'
        '🌐 Servidor: $baseUrl\n'
        '🔒 Protocolo: $protocol\n'
        '📋 Versión: $version\n'
        '🏷️ Entorno: $environment\n'
        '🔗 Tipo: $connectionType$detectionInfo';

    if (serverConfig.containsKey('systemInfo')) {
      final systemInfo = serverConfig['systemInfo'] as Map;
      if (systemInfo.containsKey('allLocalIPs')) {
        final ips = systemInfo['allLocalIPs'] as List;
        if (ips.isNotEmpty) {
          successMsg += '\n📍 IPs del servidor: ${ips.take(2).join(', ')}';
        }
      }
    }

    _mostrarMensajeExito(successMsg);

    if (kDebugMode) {
      print('🔍 Verificando persistencia:');
      print('   isConfigured: ${widget.apiConfig.isConfigured}');
      print('   baseUrl: ${widget.apiConfig.baseUrl}');
      print('   apiUrl: ${widget.apiConfig.apiUrl}');
    }

    if (widget.apiConfig.isConfigured &&
        widget.apiConfig.baseUrl.isNotEmpty &&
        widget.apiConfig.apiUrl.isNotEmpty) {
      if (kDebugMode) {
        print('✅ Configuración verificada y persistida');
        print('   Ejecutando callback en 2 segundos...');
      }

      await Future.delayed(const Duration(milliseconds: 2000));

      if (mounted) {
        widget.onConfigSuccess();
      }
    } else {
      if (kDebugMode) {
        print('❌ ERROR: Configuración no persistió correctamente');
      }
      _mostrarMensajeError('❌ Error al guardar la configuración\n'
          'La configuración no se persistió correctamente. Inténtelo nuevamente.');
    }
  }

  String _detectConnectionType(String url) {
    if (url.contains('ngrok')) return 'ngrok';
    if (url.contains('loca.lt')) return 'localtunnel';
    if (url.contains('github.')) return 'github';
    if (url.contains('localhost') || url.contains('127.0.0.1'))
      return 'localhost';
    if (RegExp(r'192\.168\.\d+\.\d+').hasMatch(url) ||
        RegExp(r'10\.\d+\.\d+\.\d+').hasMatch(url)) return 'local network';
    return 'external';
  }

  void _manejarErrorConexion(dynamic e) {
    String mensajeError = 'Error de conexión desconocido';
    String sugerencia = '';

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          mensajeError = '⏰ Tiempo de espera agotado';
          sugerencia = '• Verifique que el servidor esté ejecutándose\n'
              '• Para HTTPS local, confirme certificados SSL\n'
              '• Para ngrok, confirme que el túnel esté activo\n'
              '• Intente con una URL diferente';
          break;

        case DioExceptionType.connectionError:
          mensajeError = '🔌 No se pudo conectar al servidor';
          sugerencia = '• Verifique la URL del servidor\n'
              '• Asegúrese de estar en la misma WiFi\n'
              '• Para HTTPS local, acepte certificados auto-firmados';
          break;

        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          mensajeError = '📋 Error del servidor ($statusCode)';
          sugerencia = '• Verifique que la URL del API sea correcta\n'
              '• El servidor puede estar configurado incorrectamente\n'
              '• Para HTTPS, verifique configuración SSL';
          break;

        case DioExceptionType.unknown:
          if (e.message?.contains('CERTIFICATE_VERIFY_FAILED') == true) {
            mensajeError = '🔒 Error de certificado SSL';
            sugerencia =
                '• Para desarrollo local: acepte certificado auto-firmado\n'
                '• Para ngrok: use URL HTTPS proporcionada\n'
                '• Verifique configuración de certificados';
          } else {
            mensajeError = '❓ Error de conexión';
            sugerencia = e.message ?? 'Error sin descripción';
          }
          break;

        default:
          mensajeError = '⚠️ Error de conexión';
          sugerencia = e.message ?? 'Error desconocido';
      }
    }

    final mensajeCompleto = '$mensajeError\n\n💡 Sugerencias:\n$sugerencia';
    developer.log('❌ Error detallado: $mensajeCompleto',
        name: 'API_CONFIG_ERROR', error: e);
    _mostrarMensajeError(mensajeCompleto);
  }

  void _mostrarMensajeError(String mensaje) {
    if (mounted) {
      setState(() {
        _errorMessage = mensaje;
        _successMessage = '';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Cerrar',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  void _mostrarMensajeExito(String mensaje) {
    if (mounted) {
      setState(() {
        _successMessage = mensaje;
        _errorMessage = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '🎉',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  // ✅ NUEVO: Widget de estado de detección automática
  Widget _construirEstadoDeteccionAutomatica() {
    if (!kIsWeb || (!_isAutoDetecting && _autoDetectionStatus.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isAutoDetecting
            ? Colors.blue.shade50
            : (_autoDetectionStatus.startsWith('✅')
                ? Colors.green.shade50
                : Colors.orange.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAutoDetecting
              ? Colors.blue.shade200
              : (_autoDetectionStatus.startsWith('✅')
                  ? Colors.green.shade200
                  : Colors.orange.shade200),
        ),
      ),
      child: Row(
        children: [
          if (_isAutoDetecting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue.shade600,
              ),
            )
          else
            Icon(
              _autoDetectionStatus.startsWith('✅')
                  ? Icons.check_circle
                  : (_autoDetectionStatus.startsWith('❌')
                      ? Icons.error
                      : Icons.warning),
              color: _autoDetectionStatus.startsWith('✅')
                  ? Colors.green.shade600
                  : (_autoDetectionStatus.startsWith('❌')
                      ? Colors.red.shade600
                      : Colors.orange.shade600),
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _autoDetectionStatus,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isAutoDetecting
                    ? Colors.blue.shade800
                    : (_autoDetectionStatus.startsWith('✅')
                        ? Colors.green.shade800
                        : Colors.orange.shade800),
              ),
            ),
          ),
          if (kIsWeb && !_isAutoDetecting && _autoDetectionCompleted)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _redetectarRed,
              tooltip: 'Re-detectar red',
              color: Colors.blue.shade600,
            ),
        ],
      ),
    );
  }

  Widget _construirSugerenciasUrl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                color: Color(0xFF49B8E2), size: 20),
            const SizedBox(width: 8),
            const Text(
              'URLs Sugeridas (HTTPS Recomendado):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (_autoDetectedConfig != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'AUTO',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold),
                ),
              ),
            if (_suggestedUrls.length > 5)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_suggestedUrls.length} opciones',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _suggestedUrls.take(8).map((url) {
            final cleanUrl =
                url.replaceAll('https://', '').replaceAll('http://', '');
            final isCurrentUrl = _urlController.text.contains(cleanUrl);
            final isHttps = url.startsWith('https://');
            final isRecommended = _autoDetectedConfig != null &&
                url == _autoDetectedConfig!['recommendedUrl'];

            return ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRecommended)
                    Icon(Icons.star, size: 12, color: Colors.amber.shade700)
                  else if (isHttps)
                    Icon(Icons.lock, size: 12, color: Colors.green.shade700)
                  else
                    Icon(Icons.lock_open,
                        size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    cleanUrl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isCurrentUrl ? FontWeight.bold : FontWeight.normal,
                      color: isRecommended
                          ? Colors.amber.shade800
                          : (isHttps
                              ? Colors.green.shade800
                              : Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
              onPressed: () {
                _urlController.text = cleanUrl;
                setState(() {
                  _detectedConnectionType = _detectConnectionType(cleanUrl);
                });
              },
              backgroundColor: isCurrentUrl
                  ? (isRecommended
                      ? Colors.amber.shade100
                      : (isHttps
                          ? Colors.green.shade100
                          : Colors.orange.shade100))
                  : (isRecommended
                      ? Colors.amber.shade50
                      : (isHttps
                          ? Colors.green.shade50
                          : Colors.orange.shade50)),
              side: BorderSide(
                color: isCurrentUrl
                    ? (isRecommended
                        ? Colors.amber.shade400
                        : (isHttps
                            ? Colors.green.shade400
                            : Colors.orange.shade400))
                    : (isRecommended
                        ? Colors.amber.shade200
                        : (isHttps
                            ? Colors.green.shade200
                            : Colors.orange.shade200)),
              ),
              avatar: _getConnectionTypeIcon(url),
            );
          }).toList(),
        ),
        if (_suggestedUrls.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Y ${_suggestedUrls.length - 8} opciones más...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget? _getConnectionTypeIcon(String url) {
    if (url.contains('ngrok')) {
      return const Icon(Icons.public, size: 16, color: Colors.orange);
    }
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      return const Icon(Icons.computer, size: 16, color: Colors.green);
    }
    if (RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(url)) {
      return const Icon(Icons.router, size: 16, color: Colors.blue);
    }
    return const Icon(Icons.language, size: 16, color: Colors.purple);
  }

  Widget _construirInfoDebug() {
    final debugInfo = widget.apiConfig.getDebugInfo();

    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.bug_report, color: Color(0xFF49B8E2)),
          const SizedBox(width: 8),
          const Text('Información de Depuración'),
          if (_detectedConnectionType.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _detectedConnectionType.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      children: [
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('URL Base Configurada'),
          subtitle: Text(debugInfo['baseUrl']?.isNotEmpty == true
              ? debugInfo['baseUrl']
              : 'No configurada'),
          trailing: debugInfo['baseUrl']?.isNotEmpty == true
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.error, color: Colors.red),
        ),
        ListTile(
          leading: const Icon(Icons.api),
          title: const Text('URL API'),
          subtitle: Text(debugInfo['apiUrl']?.isNotEmpty == true
              ? debugInfo['apiUrl']
              : 'No configurada'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Estado de Configuración'),
          subtitle: Text(debugInfo['isConfigured'] == true
              ? '✅ CONFIGURADO MANUALMENTE'
              : '⚠️ NO CONFIGURADO'),
          trailing: debugInfo['isConfigured'] == true
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.warning, color: Colors.orange),
        ),
        if (_autoDetectedConfig != null)
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Detección Automática'),
            subtitle: Text('IP: ${_autoDetectedConfig!['detectedIP']}\n'
                'Protocolo: ${_autoDetectedConfig!['detectedProtocol']?.toString().toUpperCase()}'),
            trailing: const Icon(Icons.check_circle, color: Colors.blue),
          ),
        ListTile(
          leading: const Icon(Icons.devices),
          title: const Text('Plataforma'),
          subtitle: Text(
              '${debugInfo['platform'] ?? 'Desconocida'}${kIsWeb ? ' (Web)' : ''}'),
        ),
        ListTile(
          leading: const Icon(Icons.router),
          title: const Text('Tipo de Conexión'),
          subtitle: Text(debugInfo['connectionType'] ?? 'No detectado'),
        ),
        if (_connectionInfo.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Última Conexión Exitosa'),
            subtitle: Text(_connectionInfo['timestamp'] ?? 'Nunca'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Servidor'),
        backgroundColor: const Color(0xFF49B8E2),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (kIsWeb && _autoDetectionCompleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isAutoDetecting ? null : _redetectarRed,
              tooltip: 'Re-detectar red',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isResetting ? null : _resetConfiguration,
            tooltip: 'Resetear configuración',
          ),
          if (widget.apiConfig.isConfigured)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: () {
                final currentUrl = widget.apiConfig.baseUrl
                    .replaceAll('http://', '')
                    .replaceAll('https://', '');
                _urlController.text = currentUrl;
                _probarConexion();
              },
              tooltip: 'Probar configuración actual',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                _construirLogo(),
                const SizedBox(height: 24),

                // Título con estado
                _construirTituloConEstado(),
                const SizedBox(height: 8),

                // Descripción
                Text(
                  widget.apiConfig.isConfigured
                      ? 'Configuración actual guardada. Puede modificarla si es necesario.'
                      : 'Configure la dirección del servidor para conectar la aplicación',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.apiConfig.isConfigured
                        ? Colors.green.shade700
                        : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ✅ NUEVO: Estado de detección automática
                _construirEstadoDeteccionAutomatica(),

                // Campo de URL
                _construirCampoUrl(),
                const SizedBox(height: 16),

                // Sugerencias (mejoradas con detección automática)
                _construirSugerenciasUrl(),
                const SizedBox(height: 16),

                // Mensajes
                if (_errorMessage.isNotEmpty) _construirMensajeError(),
                if (_successMessage.isNotEmpty) _construirMensajeExito(),
                const SizedBox(height: 16),

                // Botones principales
                _construirBotones(),
                const SizedBox(height: 24),

                // Instrucciones HTTPS
                _construirInstruccionesHttps(),
                const SizedBox(height: 16),

                // Debug info (mejorado con info de detección automática)
                _construirInfoDebug(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Resto de widgets de UI - mantener tu código existente
  Widget _construirTituloConEstado() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Configuración de Conexión',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (widget.apiConfig.isConfigured)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'CONFIGURADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_detectedConnectionType.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tipo: ${_detectedConnectionType.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                if (_urlController.text.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          _formatUrl(_urlController.text).startsWith('https://')
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _formatUrl(_urlController.text).startsWith('https://')
                              ? Icons.lock
                              : Icons.lock_open,
                          size: 12,
                          color: _formatUrl(_urlController.text)
                                  .startsWith('https://')
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatUrl(_urlController.text).startsWith('https://')
                              ? 'HTTPS'
                              : 'HTTP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _formatUrl(_urlController.text)
                                    .startsWith('https://')
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Mantener todos tus widgets existentes: _construirLogo, _construirCampoUrl,
  // _construirMensajeError, _construirMensajeExito, _construirBotones,
  // _construirInstruccionesHttps, etc.

  Widget _construirLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF49B8E2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.pest_control, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pest Control',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF49B8E2),
          ),
        ),
        const Text(
          'Costa Analytics',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _construirCampoUrl() {
    return TextFormField(
      controller: _urlController,
      onChanged: (value) {
        setState(() {
          _detectedConnectionType = _detectConnectionType(value);
        });
      },
      decoration: InputDecoration(
        labelText: 'URL del Servidor',
        hintText: 'localhost:8000 o IP detectada automáticamente',
        helperText: 'Ingrese la dirección donde se ejecuta el servidor',
        prefixIcon: const Icon(Icons.link, color: Color(0xFF49B8E2)),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_detectedConnectionType.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    _detectedConnectionType.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor:
                      _getConnectionTypeColor(_detectedConnectionType),
                  side: BorderSide.none,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _urlController.clear(),
            ),
          ],
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF49B8E2), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingrese una URL';
        }

        try {
          final cleanValue = value.trim().toLowerCase();
          final urlRegex = RegExp(
            r'^(https?://)?' // Protocolo opcional
            r'('
            r'localhost|' // localhost
            r'127\.0\.0\.1|' // 127.0.0.1
            r'10\.0\.2\.2|' // Android emulator
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|' // IPv4
            r'[\w\-]+\.ngrok\.io|' // ngrok viejo
            r'[\w\-]+\.ngrok-free\.app|' // ngrok nuevo
            r'[\w\-]+\.ngrok\.app|' // ngrok alternativo
            r'[\w\-]+\.loca\.lt|' // LocalTunnel
            r'[\w\-]+\.serveo\.net|' // Serveo
            r'[\w\-]+\.localhost\.run|' // localhost.run
            r'[\w\-]+(\.[\w\-]+)*\.(dev|com|net|org|app|io|co|me|lt)' // Dominios
            r')'
            r'(:\d+)?' // Puerto opcional
            r'(/.*)?', // Path opcional
            caseSensitive: false,
          );

          bool isValid = urlRegex.hasMatch(cleanValue) ||
              cleanValue.contains('localhost') ||
              cleanValue.contains('127.0.0.1') ||
              cleanValue.contains('10.0.2.2') ||
              cleanValue.contains('ngrok') ||
              cleanValue.contains('loca.lt') ||
              RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(cleanValue);

          if (isValid) {
            return null;
          }

          return '❌ URL inválida\n💡 Use: localhost, IP local, ngrok, o dominio válido';
        } catch (e) {
          return 'Formato de URL inválido';
        }
      },
    );
  }

  Color _getConnectionTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'ngrok':
        return Colors.orange.shade100;
      case 'localhost':
        return Colors.green.shade100;
      case 'local network':
        return Colors.blue.shade100;
      case 'localtunnel':
        return Colors.purple.shade100;
      case 'github':
        return Colors.grey.shade200;
      default:
        return Colors.grey.shade100;
    }
  }

  Widget _construirMensajeError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error de Conexión',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.red.shade800),
          ),
          const SizedBox(height: 12),
          _construirSugerenciasRapidas(),
        ],
      ),
    );
  }

  Widget _construirSugerenciasRapidas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔧 Soluciones rápidas:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        _construirSugerenciaRapida(
            '• Verifique que el servidor esté ejecutándose'),
        if (_autoDetectedConfig != null)
          _construirSugerenciaRapida(
              '• Pruebe con la IP detectada automáticamente'),
        _construirSugerenciaRapida('• Para ngrok: use URL HTTPS proporcionada'),
        _construirSugerenciaRapida(
            '• Para desarrollo local: acepte certificado SSL'),
        _construirSugerenciaRapida(
            '• Pruebe con las URLs HTTPS sugeridas arriba'),
      ],
    );
  }

  Widget _construirSugerenciaRapida(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
      ),
    );
  }

  Widget _construirMensajeExito() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Configuración Guardada',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _successMessage,
            style: TextStyle(color: Colors.green.shade800),
          ),
          if (_connectionInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '⚡ Endpoint usado: ${_connectionInfo['workingEndpoint'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirBotones() {
    return Column(
      children: [
        // Botón principal de conexión
        ElevatedButton(
          onPressed: _isLoading ? null : _probarConexion,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF49B8E2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Probando${_detectedConnectionType.isNotEmpty ? ' ($_detectedConnectionType)' : ''}...',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.apiConfig.isConfigured
                          ? 'Actualizar Configuración'
                          : 'Guardar Configuración',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 12),

        // Botón de reset
        OutlinedButton(
          onPressed: (_isLoading || _isResetting) ? null : _resetConfiguration,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade700,
            side: BorderSide(color: Colors.orange.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isResetting
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.orange.shade700, strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    const Text('Reseteando...', style: TextStyle(fontSize: 14)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Resetear a Valores por Defecto',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _construirInstruccionesHttps() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Guía de Configuración HTTPS:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // DETECCIÓN AUTOMÁTICA (NUEVO)
          if (kIsWeb)
            _construirSeccionInstruccion(
              '🤖 Detección Automática (NUEVO)',
              [
                'La app detecta automáticamente tu servidor local',
                'Pre-completa el campo con la IP correcta',
                'Funciona sin configuración manual',
                'Usa el botón "Re-detectar" si cambia tu red',
              ],
              color: Colors.purple.shade700,
              backgroundColor: Colors.purple.shade50,
            ),
          const SizedBox(height: 12),

          // HTTPS LOCAL (RECOMENDADO)
          _construirSeccionInstruccion(
            '🔒 HTTPS Local (RECOMENDADO)',
            [
              'Detección automática prioriza HTTPS',
              'Funciona con certificados SSL auto-firmados',
              'Permite escáner de códigos de barras en móviles',
              'Acepta el certificado cuando el navegador lo pida',
            ],
            color: Colors.green.shade700,
            backgroundColor: Colors.green.shade50,
          ),
          const SizedBox(height: 12),

          // NGROK HTTPS
          _construirSeccionInstruccion(
            '🌐 Acceso Remoto HTTPS',
            [
              'ngrok: https://abc123.ngrok-free.app',
              'Siempre use la URL HTTPS que proporciona ngrok',
              'Ideal para pruebas desde internet',
              'No requiere configuración de certificados',
            ],
            color: Colors.orange.shade700,
            backgroundColor: Colors.orange.shade50,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade800,
                      ),
                      children: [
                        const TextSpan(
                          text: '💡 Nuevo: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text:
                              'La detección automática encuentra y configura su servidor automáticamente. ',
                        ),
                        if (_autoDetectedConfig != null)
                          TextSpan(
                            text:
                                'IP detectada: ${_autoDetectedConfig!['detectedIP']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionInstruccion(
    String titulo,
    List<String> instrucciones, {
    Color? color,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color?.withOpacity(0.3) ?? Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color ?? Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 4),
          ...instrucciones.map((instruccion) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  '• $instruccion',
                  style: TextStyle(
                    fontSize: 13,
                    color: color?.withOpacity(0.8) ?? Colors.blue.shade700,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
