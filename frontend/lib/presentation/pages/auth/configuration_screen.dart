import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../../../core/config/flavor_config.dart';

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
  bool _showManualConfig = false;
  bool _autoConfigInProgress = true;
  String _errorMessage = '';
  String _successMessage = '';
  final _dio = Dio();
  Map<String, dynamic> _connectionInfo = {};
  String _detectedConnectionType = 'drpestcontrol';

  // ✅ CORREGIDO: Detectar si la página actual usa HTTPS
  bool get _paginaEnHttps {
    if (kIsWeb) {
      try {
        return Uri.base.scheme == 'https';
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  // ✅ CORREGIDO: URLs siempre HTTPS cuando la página está en HTTPS
  // Esto evita el error "Mixed Content" del navegador
  List<String> get _clientUrls {
    if (_paginaEnHttps) {
      // Si la página está en HTTPS, FORZAR HTTPS para el API (evitar Mixed Content)
      return [
        'https://drpestcontrol:8000', // Principal
        'https://drpestcontrol:8080', // Alternativo
        'https://192.168.137.177:8000', // IP directa producción
      ];
    }

    // Solo usar HTTP si la página también está en HTTP (desarrollo local puro)
    if (FlavorConfig.isDevelopment && !_paginaEnHttps) {
      return [
        'http://localhost:8000', // Development local
        'http://drpestcontrol:8000', // Development red local
        'http://localhost:8080', // Development puerto alt
      ];
    }

    // Default: HTTPS
    return [
      'https://drpestcontrol:8000', // Production principal
      'https://drpestcontrol:8080', // Production alternativo
      'https://192.168.137.177:8000', // Production IP directa
    ];
  }

  // ✅ CORREGIDO: Protocolo basado en el contexto de la página
  String get _protocoloActual {
    if (_paginaEnHttps) {
      return 'HTTPS'; // Forzar HTTPS si la página está en HTTPS
    }
    return FlavorConfig.isDevelopment ? 'HTTP' : 'HTTPS';
  }

  // ✅ Color del protocolo
  Color get _protocoloColor {
    if (_paginaEnHttps) {
      return Colors.green; // HTTPS siempre verde
    }
    return FlavorConfig.isDevelopment ? Colors.orange : Colors.green;
  }

  // ✅ Descripción del entorno
  String get _descripcionEntorno {
    if (_paginaEnHttps) {
      return 'HTTPS REQUERIDO (Página en HTTPS)';
    }
    return FlavorConfig.isDevelopment
        ? 'DEVELOPMENT (HTTP - Sin SSL)'
        : 'PRODUCTION (HTTPS - SSL Requerido)';
  }

  @override
  void initState() {
    super.initState();
    _setupDioInterceptors();
    _iniciarAutoConfiguracion();
  }

  void _iniciarAutoConfiguracion() async {
    if (kDebugMode) {
      print(
          '🤖 Iniciando auto-configuración transparente para drpestcontrol...');
      print('   Flavor: ${FlavorConfig.currentFlavor}');
      print('   Protocolo: $_protocoloActual');
      print('   Página en HTTPS: $_paginaEnHttps');
      print('   URLs a probar: ${_clientUrls.length}');
      for (var url in _clientUrls) {
        print('     - $url');
      }
    }

    setState(() {
      _autoConfigInProgress = true;
      _showManualConfig = false;
    });

    try {
      if (widget.apiConfig.isConfigured &&
          widget.apiConfig.baseUrl.isNotEmpty) {
        if (kDebugMode) {
          print(
              '🔍 Verificando configuración existente: ${widget.apiConfig.baseUrl}');
        }

        final configExistenteFunciona =
            await _verificarConfiguracionExistente();
        if (configExistenteFunciona) {
          if (kDebugMode) {
            print('✅ Configuración existente funciona, continuando...');
          }
          _continuarAApp();
          return;
        }

        if (kDebugMode) {
          print(
              '❌ Configuración existente falló, intentando auto-configuración...');
        }
      }

      final autoConfigExitosa = await _intentarAutoConfiguracion();

      if (autoConfigExitosa) {
        if (kDebugMode) {
          print('✅ Auto-configuración exitosa, continuando a la app...');
        }
        _continuarAApp();
      } else {
        if (kDebugMode) {
          print(
              '❌ Auto-configuración falló, mostrando UI manual de emergencia...');
        }
        _mostrarConfiguracionManual();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en auto-configuración: $e');
      }
      _mostrarConfiguracionManual();
    }
  }

  Future<bool> _verificarConfiguracionExistente() async {
    try {
      final baseUrl = widget.apiConfig.baseUrl;
      if (baseUrl.isEmpty) return false;

      // ✅ CORREGIDO: Verificar que la URL use el protocolo correcto
      String urlToTest = baseUrl;
      if (_paginaEnHttps && urlToTest.startsWith('http://')) {
        urlToTest = urlToTest.replaceFirst('http://', 'https://');
        if (kDebugMode) {
          print('⚠️ Convirtiendo URL a HTTPS para evitar Mixed Content');
        }
      }

      final response = await _dio.get(
        '$urlToTest/api/config',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Verificación de configuración existente falló: $e');
      }
      return false;
    }
  }

  Future<bool> _intentarAutoConfiguracion() async {
    if (kDebugMode) {
      print('🤖 Intentando auto-configuración silenciosa...');
      print('   URLs a probar: $_clientUrls');
    }

    for (String url in _clientUrls) {
      try {
        if (kDebugMode) {
          print('🔍 Probando auto-configuración con: $url');
        }

        final response = await _dio.get(
          '$url/api/config',
          options: Options(
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 6),
          ),
        );

        if (response.statusCode == 200) {
          await widget.apiConfig.updateBaseUrl(url);

          if (kDebugMode) {
            print('✅ Auto-configuración exitosa con: $url');
          }

          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Auto-configuración falló para $url: $e');
        }
        continue;
      }
    }

    return false;
  }

  void _continuarAApp() {
    setState(() {
      _autoConfigInProgress = false;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onConfigSuccess();
      }
    });
  }

  void _mostrarConfiguracionManual() {
    setState(() {
      _autoConfigInProgress = false;
      _showManualConfig = true;
      _errorMessage =
          '🚨 No se pudo conectar automáticamente a drpestcontrol\n\n'
          'Entorno: $_descripcionEntorno\n'
          'Protocolo requerido: $_protocoloActual\n'
          'Página en HTTPS: $_paginaEnHttps\n\n'
          'Esta pantalla solo aparece cuando hay problemas graves de conectividad.\n'
          'Por favor configure manualmente o contacte soporte técnico.';
    });

    // ✅ CORREGIDO: Pre-completar según el contexto
    if (_paginaEnHttps) {
      _urlController.text = 'drpestcontrol:8000';
    } else if (FlavorConfig.isDevelopment) {
      _urlController.text = 'localhost:8000';
    } else {
      _urlController.text = 'drpestcontrol:8000';
    }
    _detectedConnectionType = 'drpestcontrol';
  }

  Future<void> _reintentarAutoConfiguracion() async {
    setState(() {
      _showManualConfig = false;
      _autoConfigInProgress = true;
      _errorMessage = '';
      _successMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    _iniciarAutoConfiguracion();
  }

  void _setupDioInterceptors() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.sendTimeout = const Duration(seconds: 10);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        });

        if (kDebugMode) {
          developer.log(
              '🌐 REQUEST: ${options.method} ${options.baseUrl}${options.path}',
              name: 'API_CONFIG');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          developer.log(
              '✅ RESPONSE: ${response.statusCode} from ${response.requestOptions.path}',
              name: 'API_CONFIG');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          developer.log('❌ ERROR: ${error.type} - ${error.message}',
              name: 'API_CONFIG');
        }
        handler.next(error);
      },
    ));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ✅ CORREGIDO: Formatear URL respetando el protocolo de la página
  String _formatUrl(String url) {
    url = url.trim();

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Si la página está en HTTPS, forzar HTTPS para evitar Mixed Content
      if (_paginaEnHttps) {
        url = 'https://$url';
      } else if (FlavorConfig.isDevelopment) {
        url = 'http://$url';
      } else {
        url = 'https://$url';
      }
    }

    // ✅ CRÍTICO: Si estamos en HTTPS y la URL es HTTP, convertir a HTTPS
    if (_paginaEnHttps && url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
      if (kDebugMode) {
        print('⚠️ URL convertida a HTTPS para evitar Mixed Content: $url');
      }
    }

    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }

    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  String _getDefaultUrl() {
    if (_paginaEnHttps) {
      return 'https://drpestcontrol:8000';
    }
    if (FlavorConfig.isDevelopment) {
      return 'http://localhost:8000';
    } else {
      return 'https://drpestcontrol:8000';
    }
  }

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
        print('🔄 Reseteando configuración del cliente...');
      }

      await widget.apiConfig.reset();

      // ✅ CORREGIDO: Reset según contexto
      if (_paginaEnHttps) {
        _urlController.text = 'drpestcontrol:8000';
      } else if (FlavorConfig.isDevelopment) {
        _urlController.text = 'localhost:8000';
      } else {
        _urlController.text = 'drpestcontrol:8000';
      }
      _detectedConnectionType = 'drpestcontrol';

      _mostrarMensajeExito('🔄 Configuración reseteada exitosamente\n\n'
          '✅ Restaurado a ${_urlController.text}\n'
          '🔧 Protocolo: $_protocoloActual\n'
          '🏷️ Entorno: ${FlavorConfig.currentFlavor}\n'
          '🔧 Listo para nueva configuración');

      if (kDebugMode) {
        print('✅ Reset completado para cliente drpestcontrol');
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
    final defaultUrl = _paginaEnHttps
        ? 'drpestcontrol:8000'
        : (FlavorConfig.isDevelopment
            ? 'localhost:8000'
            : 'drpestcontrol:8000');
    final protocolo = _protocoloActual;

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
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ Se restaurará:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('• URL: $defaultUrl'),
                        Text('• Protocolo: $protocolo'),
                        Text('• Entorno: ${FlavorConfig.currentFlavor}'),
                        if (_paginaEnHttps)
                          const Text(
                              '• Nota: HTTPS requerido (página en HTTPS)'),
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

  Widget _construirSugerenciasUrl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, color: _protocoloColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Opciones de Servidor drpestcontrol ($_protocoloActual):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ✅ Advertencia si página está en HTTPS
        if (_paginaEnHttps)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta página usa HTTPS, todas las conexiones deben ser HTTPS',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _clientUrls.map((url) {
            final cleanUrl =
                url.replaceAll('https://', '').replaceAll('http://', '');
            final isCurrentUrl = _urlController.text == cleanUrl;
            final port = cleanUrl.contains(':8000') ? '8000' : '8080';
            final isPrimary = port == '8000';
            final isLocalhost = cleanUrl.contains('localhost');
            final isHttps = url.startsWith('https://');

            return ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPrimary ? Icons.star : Icons.star_border,
                    size: 12,
                    color: isPrimary
                        ? Colors.amber.shade700
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isHttps ? Icons.lock : Icons.lock_open,
                    size: 12,
                    color: isHttps ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cleanUrl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isCurrentUrl ? FontWeight.bold : FontWeight.normal,
                      color: isPrimary
                          ? Colors.amber.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPrimary
                        ? (isLocalhost ? '(Local)' : '(Principal)')
                        : '(Alt)',
                    style: TextStyle(
                      fontSize: 10,
                      color: isPrimary
                          ? Colors.amber.shade600
                          : Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                _urlController.text = cleanUrl;
                setState(() {
                  _detectedConnectionType = 'drpestcontrol';
                });
              },
              backgroundColor: isCurrentUrl
                  ? (isPrimary ? Colors.amber.shade100 : Colors.blue.shade100)
                  : (isPrimary ? Colors.amber.shade50 : Colors.blue.shade50),
              side: BorderSide(
                color: isCurrentUrl
                    ? (isPrimary ? Colors.amber.shade400 : Colors.blue.shade400)
                    : (isPrimary
                        ? Colors.amber.shade200
                        : Colors.blue.shade200),
              ),
              avatar: Icon(
                isLocalhost ? Icons.computer : Icons.business,
                size: 16,
                color: isPrimary ? Colors.amber.shade700 : Colors.blue.shade700,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Badge del entorno actual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _protocoloColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _protocoloColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _paginaEnHttps
                    ? Icons.lock
                    : (FlavorConfig.isDevelopment
                        ? Icons.developer_mode
                        : Icons.lock),
                size: 16,
                color: _protocoloColor,
              ),
              const SizedBox(width: 6),
              Text(
                _descripcionEntorno,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _protocoloColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirCampoUrl() {
    return TextFormField(
      controller: _urlController,
      decoration: InputDecoration(
        labelText: 'Servidor drpestcontrol',
        hintText: _paginaEnHttps
            ? 'drpestcontrol:8000'
            : (FlavorConfig.isDevelopment
                ? 'localhost:8000'
                : 'drpestcontrol:8000'),
        helperText:
            'Puerto 8000 (principal) o 8080 (alternativo) - $_protocoloActual${_paginaEnHttps ? " (requerido)" : ""}',
        prefixIcon: Icon(
          _paginaEnHttps
              ? Icons.lock
              : (FlavorConfig.isDevelopment ? Icons.computer : Icons.business),
          color: _protocoloColor,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _protocoloColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _paginaEnHttps
                        ? Icons.lock
                        : (FlavorConfig.isDevelopment
                            ? Icons.developer_mode
                            : Icons.lock),
                    size: 12,
                    color: _protocoloColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _protocoloActual,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _protocoloColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
          borderSide: BorderSide(color: _protocoloColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingrese la URL de drpestcontrol';
        }

        final cleanValue = value.trim().toLowerCase();

        // Validación flexible que acepta hosts válidos
        final drpestcontrolRegex = RegExp(
          r'^(https?://)?' // Protocolo opcional
          r'(drpestcontrol|localhost|127\.0\.0\.1|192\.168\.\d+\.\d+)' // Hosts válidos
          r'(:\d+)?' // Puerto opcional
          r'(/.*)?$', // Path opcional
          caseSensitive: false,
        );

        if (drpestcontrolRegex.hasMatch(cleanValue)) {
          return null;
        }

        return '❌ Use formato: ${_paginaEnHttps ? "drpestcontrol" : (FlavorConfig.isDevelopment ? "localhost" : "drpestcontrol")}:8000';
      },
    );
  }

  Widget _construirInstruccionesCliente() {
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
                'Configuración drpestcontrol:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Información del entorno actual
          _construirSeccionInstruccion(
            '🎯 Entorno Actual',
            [
              'Flavor: ${FlavorConfig.currentFlavor}',
              'Protocolo: $_protocoloActual',
              'Página en HTTPS: ${_paginaEnHttps ? "Sí" : "No"}',
              'Configuración: $_descripcionEntorno',
            ],
            color: _protocoloColor,
            backgroundColor: _protocoloColor.withOpacity(0.1),
          ),
          const SizedBox(height: 12),

          // ✅ NUEVO: Advertencia Mixed Content
          if (_paginaEnHttps)
            _construirSeccionInstruccion(
              '⚠️ Mixed Content',
              [
                'Esta página se cargó con HTTPS',
                'Todas las conexiones API DEBEN ser HTTPS',
                'El navegador bloquea conexiones HTTP',
                'Use siempre https://drpestcontrol:8000',
              ],
              color: Colors.amber.shade700,
              backgroundColor: Colors.amber.shade50,
            ),
          if (_paginaEnHttps) const SizedBox(height: 12),

          // Instrucciones según el contexto
          if (!_paginaEnHttps && FlavorConfig.isDevelopment) ...[
            _construirSeccionInstruccion(
              '🔧 Development (HTTP)',
              [
                'localhost:8000 (Principal)',
                'localhost:8080 (Alternativo)',
                'HTTP sin SSL - No se requiere certificado',
                'Perfecto para desarrollo y debugging',
              ],
              color: Colors.orange.shade700,
              backgroundColor: Colors.orange.shade50,
            ),
          ] else ...[
            _construirSeccionInstruccion(
              '🌟 Servidor Principal (HTTPS)',
              [
                'drpestcontrol:8000 (Puerto principal)',
                'Protocolo HTTPS requerido para funciones del navegador',
                'Configuración recomendada para operación normal',
              ],
              color: Colors.green.shade700,
              backgroundColor: Colors.green.shade50,
            ),
            const SizedBox(height: 12),
            _construirSeccionInstruccion(
              '🔄 Servidor Alternativo (HTTPS)',
              [
                'drpestcontrol:8080 (Puerto alternativo)',
                'Use si el puerto 8000 no está disponible',
                'Misma configuración HTTPS requerida',
              ],
              color: Colors.orange.shade700,
              backgroundColor: Colors.orange.shade50,
            ),
            const SizedBox(height: 12),
            _construirSeccionInstruccion(
              '🔒 Requisitos HTTPS',
              [
                'HTTPS es obligatorio para funciones del navegador',
                'Acepte certificado SSL cuando se solicite',
                'Verifique que drpestcontrol tenga HTTPS habilitado',
                'El navegador puede mostrar advertencia de seguridad',
              ],
              color: Colors.blue.shade700,
              backgroundColor: Colors.blue.shade50,
            ),
          ],

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
                Icon(Icons.business, color: Colors.amber.shade700, size: 20),
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
                          text: '🏢 Cliente Específico: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text:
                              'Esta configuración está optimizada específicamente para el servidor drpestcontrol. ',
                        ),
                        TextSpan(
                          text: _paginaEnHttps
                              ? 'Use https://drpestcontrol:8000 (HTTPS requerido).'
                              : (FlavorConfig.isDevelopment
                                  ? 'Use localhost:8000 para desarrollo.'
                                  : 'Use drpestcontrol:8000 como opción principal.'),
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

  @override
  Widget build(BuildContext context) {
    if (_autoConfigInProgress) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    if (!_showManualConfig) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '🚨 Configuración de Emergencia (${FlavorConfig.currentFlavor.toString().split('.').last.toUpperCase()})'),
        backgroundColor: _paginaEnHttps
            ? Colors.green.shade700
            : (FlavorConfig.isDevelopment
                ? Colors.orange.shade700
                : Colors.red.shade700),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew),
            onPressed: _reintentarAutoConfiguracion,
            tooltip: 'Reintentar auto-configuración',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isResetting ? null : _resetConfiguration,
            tooltip: 'Resetear configuración',
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
                _construirBannerEmergencia(),
                const SizedBox(height: 24),
                _construirLogo(),
                const SizedBox(height: 24),
                _construirTituloCliente(),
                const SizedBox(height: 24),
                _construirBotonReintentarAuto(),
                const SizedBox(height: 24),
                _construirCampoUrl(),
                const SizedBox(height: 16),
                _construirSugerenciasUrl(),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty) _construirMensajeError(),
                if (_successMessage.isNotEmpty) _construirMensajeExito(),
                const SizedBox(height: 16),
                _construirBotones(),
                const SizedBox(height: 24),
                _construirInstruccionesCliente(),
                const SizedBox(height: 16),
                _construirInfoDebug(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirBannerEmergencia() {
    final bool mostrarHttpsWarning = _paginaEnHttps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mostrarHttpsWarning
            ? Colors.amber.shade50
            : (FlavorConfig.isDevelopment
                ? Colors.orange.shade50
                : Colors.red.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mostrarHttpsWarning
              ? Colors.amber.shade300
              : (FlavorConfig.isDevelopment
                  ? Colors.orange.shade300
                  : Colors.red.shade300),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mostrarHttpsWarning
                    ? Icons.lock
                    : (FlavorConfig.isDevelopment
                        ? Icons.developer_mode
                        : Icons.warning),
                color: mostrarHttpsWarning
                    ? Colors.amber.shade700
                    : (FlavorConfig.isDevelopment
                        ? Colors.orange.shade700
                        : Colors.red.shade700),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mostrarHttpsWarning
                      ? '🔒 HTTPS REQUERIDO'
                      : (FlavorConfig.isDevelopment
                          ? '🔧 MODO DESARROLLO'
                          : '🚨 CONFIGURACIÓN DE EMERGENCIA'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mostrarHttpsWarning
                        ? Colors.amber.shade900
                        : (FlavorConfig.isDevelopment
                            ? Colors.orange.shade900
                            : Colors.red.shade900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mostrarHttpsWarning
                ? 'Esta página se cargó con HTTPS. El navegador bloquea conexiones HTTP (Mixed Content). Use siempre HTTPS para las conexiones al servidor.'
                : (FlavorConfig.isDevelopment
                    ? 'Modo desarrollo activo - Se usará HTTP sin SSL para facilitar debugging.'
                    : 'Esta pantalla solo aparece cuando hay problemas graves de conectividad con drpestcontrol.'),
            style: TextStyle(
              fontSize: 16,
              color: mostrarHttpsWarning
                  ? Colors.amber.shade800
                  : (FlavorConfig.isDevelopment
                      ? Colors.orange.shade800
                      : Colors.red.shade800),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _protocoloColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.pest_control, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          'Pest Control',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _protocoloColor,
          ),
        ),
        const Text(
          'drpestcontrol - Costa Analytics',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _construirTituloCliente() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Servidor drpestcontrol',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _paginaEnHttps
                    ? Colors.amber.shade100
                    : (FlavorConfig.isDevelopment
                        ? Colors.orange.shade100
                        : Colors.red.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _paginaEnHttps
                      ? Colors.amber.shade300
                      : (FlavorConfig.isDevelopment
                          ? Colors.orange.shade300
                          : Colors.red.shade300),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _paginaEnHttps
                        ? Icons.lock
                        : (FlavorConfig.isDevelopment
                            ? Icons.developer_mode
                            : Icons.error),
                    size: 16,
                    color: _paginaEnHttps
                        ? Colors.amber.shade700
                        : (FlavorConfig.isDevelopment
                            ? Colors.orange.shade700
                            : Colors.red.shade700),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _paginaEnHttps
                        ? 'HTTPS'
                        : (FlavorConfig.isDevelopment
                            ? 'DESARROLLO'
                            : 'SIN CONEXIÓN'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _paginaEnHttps
                          ? Colors.amber.shade700
                          : (FlavorConfig.isDevelopment
                              ? Colors.orange.shade700
                              : Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Configure manualmente la conexión al servidor drpestcontrol',
          style: TextStyle(
            fontSize: 14,
            color: _paginaEnHttps
                ? Colors.amber.shade700
                : (FlavorConfig.isDevelopment
                    ? Colors.orange.shade700
                    : Colors.red.shade700),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _protocoloColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _protocoloColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _paginaEnHttps
                    ? Icons.lock
                    : (FlavorConfig.isDevelopment
                        ? Icons.developer_mode
                        : Icons.lock),
                size: 16,
                color: _protocoloColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$_protocoloActual ${_paginaEnHttps ? "(Requerido por HTTPS)" : (FlavorConfig.isDevelopment ? "(Desarrollo)" : "(Requerido)")}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _protocoloColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirBotonReintentarAuto() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _autoConfigInProgress ? null : _reintentarAutoConfiguracion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: _autoConfigInProgress
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Reintentando auto-configuración...',
                      style: TextStyle(fontSize: 16)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.autorenew, size: 24),
                  SizedBox(width: 12),
                  Text('Reintentar Auto-configuración',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
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
                  'Error de Conexión a drpestcontrol',
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
          Text(_errorMessage, style: TextStyle(color: Colors.red.shade800)),
        ],
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
                  'Conectado a drpestcontrol',
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
          Text(_successMessage, style: TextStyle(color: Colors.green.shade800)),
          if (_connectionInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '⚡ Endpoint: ${_connectionInfo['workingEndpoint'] ?? 'N/A'}',
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
        ElevatedButton(
          onPressed: _isLoading ? null : _probarConexion,
          style: ElevatedButton.styleFrom(
            backgroundColor: _paginaEnHttps
                ? Colors.green.shade600
                : (FlavorConfig.isDevelopment
                    ? Colors.orange.shade600
                    : Colors.red.shade600),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Conectando a drpestcontrol...',
                        style: TextStyle(fontSize: 14)),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, size: 20),
                    SizedBox(width: 8),
                    Text('Conectar Manualmente a drpestcontrol',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
        const SizedBox(height: 12),
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
                    Text(
                      'Resetear a ${_paginaEnHttps ? "drpestcontrol" : (FlavorConfig.isDevelopment ? "localhost" : "drpestcontrol")}:8000',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _construirInfoDebug() {
    final debugInfo = widget.apiConfig.getDebugInfo();

    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: _protocoloColor),
          const SizedBox(width: 8),
          const Text('Información de Configuración'),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _protocoloColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              FlavorConfig.currentFlavor
                  .toString()
                  .split('.')
                  .last
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: _protocoloColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      children: [
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('URL Configurada'),
          subtitle: Text(debugInfo['baseUrl']?.isNotEmpty == true
              ? debugInfo['baseUrl']
              : 'drpestcontrol no configurado'),
          trailing: debugInfo['baseUrl']?.isNotEmpty == true
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.error, color: Colors.red),
        ),
        ListTile(
          leading: const Icon(Icons.api),
          title: const Text('URL API'),
          subtitle: Text(debugInfo['apiUrl']?.isNotEmpty == true
              ? debugInfo['apiUrl']
              : 'API no configurada'),
        ),
        ListTile(
          leading: Icon(
            _paginaEnHttps
                ? Icons.lock
                : (FlavorConfig.isDevelopment
                    ? Icons.developer_mode
                    : Icons.lock),
            color: _protocoloColor,
          ),
          title: const Text('Protocolo'),
          subtitle: Text(
              '$_protocoloActual (${FlavorConfig.currentFlavor})${_paginaEnHttps ? " - Página en HTTPS" : ""}'),
          trailing: Icon(
            _paginaEnHttps
                ? Icons.lock
                : (FlavorConfig.isDevelopment
                    ? Icons.developer_mode
                    : Icons.security),
            color: _protocoloColor,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.web),
          title: const Text('Página Actual'),
          subtitle: Text(kIsWeb ? Uri.base.toString() : 'No es web'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Estado'),
          subtitle: Text(debugInfo['isConfigured'] == true
              ? '✅ DRPESTCONTROL CONFIGURADO'
              : '⚠️ DRPESTCONTROL NO CONFIGURADO'),
          trailing: debugInfo['isConfigured'] == true
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.warning, color: Colors.orange),
        ),
        ListTile(
          leading: const Icon(Icons.business),
          title: const Text('Cliente'),
          subtitle: const Text('drpestcontrol (Configuración específica)'),
          trailing: const Icon(Icons.verified, color: Colors.blue),
        ),
        if (_connectionInfo.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Última Conexión'),
            subtitle: Text(_connectionInfo['timestamp'] ?? 'Nunca'),
          ),
      ],
    );
  }

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
        print('🔍 Probando conexión a drpestcontrol:');
        print('   Base URL: $baseUrl');
        print('   API URL: $apiUrl');
        print('   Flavor: ${FlavorConfig.currentFlavor}');
        print('   Protocolo: $_protocoloActual');
        print('   Página en HTTPS: $_paginaEnHttps');
      }

      final endpoints = [
        '$apiUrl/config',
        '$apiUrl/system/status',
        '$apiUrl/health',
        baseUrl,
        '$apiUrl/diagnostico',
      ];

      Response? successResponse;
      String workingEndpoint = '';
      Map<String, dynamic> serverConfig = {};

      for (var endpoint in endpoints) {
        try {
          developer.log('🌐 Probando drpestcontrol: $endpoint',
              name: 'API_CONFIG');

          final response = await _dio.get(
            endpoint,
            options: Options(
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: true,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
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
              developer.log('✅ drpestcontrol conectado: $endpoint',
                  name: 'API_CONFIG');
              break;
            }
          }
        } catch (e) {
          developer.log('❌ Error en drpestcontrol $endpoint: $e',
              name: 'API_CONFIG');
          continue;
        }
      }

      if (successResponse != null) {
        await _procesarRespuestaExitosa(
            baseUrl, apiUrl, serverConfig, workingEndpoint);
      } else {
        _mostrarMensajeError('❌ No se pudo conectar a drpestcontrol\n\n'
            '🔍 Endpoints probados: ${endpoints.length}\n'
            '💡 Verifique que el servidor drpestcontrol esté ejecutándose\n'
            '🔒 Protocolo requerido: $_protocoloActual\n'
            '🏷️ Entorno: ${FlavorConfig.currentFlavor}\n'
            '${_paginaEnHttps ? "⚠️ NOTA: La página usa HTTPS, asegúrese de usar https:// en la URL" : ""}');
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
      print('🎉 Conexión exitosa a drpestcontrol:');
      print('   Base URL: $baseUrl');
      print('   API URL: $apiUrl');
      print('   Endpoint: $workingEndpoint');
      print('   Flavor: ${FlavorConfig.currentFlavor}');
      print('   Protocolo: $_protocoloActual');
    }

    await widget.apiConfig.updateBaseUrl(baseUrl);

    _connectionInfo = {
      'baseUrl': baseUrl,
      'workingEndpoint': workingEndpoint,
      'connectionType': 'drpestcontrol',
      'timestamp': DateTime.now().toIso8601String(),
      'detectionMethod': 'manual-emergency',
      'flavor': FlavorConfig.currentFlavor.toString(),
      'protocol': _protocoloActual,
      'paginaEnHttps': _paginaEnHttps,
    };

    if (serverConfig.containsKey('systemInfo')) {
      _connectionInfo['systemInfo'] = serverConfig['systemInfo'];
    }

    _detectedConnectionType = 'drpestcontrol';

    final version = serverConfig['version'] ?? 'N/A';
    final environment = serverConfig['environment'] ?? 'Producción';

    String successMsg = '✅ Conectado a drpestcontrol exitosamente\n\n'
        '🌐 Servidor: $baseUrl\n'
        '🔒 Protocolo: $_protocoloActual ✅\n'
        '🏷️ Entorno: ${FlavorConfig.currentFlavor}\n'
        '📋 Versión: $version\n'
        '🏷️ Environment: $environment\n'
        '🔗 Tipo: DRPESTCONTROL';

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

    if (widget.apiConfig.isConfigured &&
        widget.apiConfig.baseUrl.isNotEmpty &&
        widget.apiConfig.apiUrl.isNotEmpty) {
      if (kDebugMode) {
        print('✅ Configuración drpestcontrol verificada y persistida');
      }

      await Future.delayed(const Duration(milliseconds: 2000));

      if (mounted) {
        widget.onConfigSuccess();
      }
    } else {
      _mostrarMensajeError(
          '❌ Error al guardar la configuración de drpestcontrol');
    }
  }

  void _manejarErrorConexion(dynamic e) {
    String mensajeError = 'Error de conexión a drpestcontrol';
    String sugerencia = '';

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          mensajeError = '⏰ Tiempo de espera agotado con drpestcontrol';
          sugerencia = '• Verifique que drpestcontrol esté ejecutándose\n'
              '• Confirme que el puerto 8000 o 8080 esté disponible\n'
              '• Verifique la configuración $_protocoloActual\n'
              '• Intente con el puerto alternativo';
          break;

        case DioExceptionType.connectionError:
          mensajeError = '🔌 No se pudo conectar a drpestcontrol';
          sugerencia = '• Confirme que drpestcontrol esté en la red\n'
              '• Verifique la conectividad de red\n'
              '• Asegúrese que $_protocoloActual esté habilitado\n'
              '• Pruebe con drpestcontrol:8080';
          if (_paginaEnHttps) {
            sugerencia += '\n• ⚠️ La página usa HTTPS - use https:// en la URL';
          }
          break;

        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          mensajeError = '📋 Error del servidor drpestcontrol ($statusCode)';
          sugerencia = '• El servidor drpestcontrol respondió con error\n'
              '• Verifique la configuración del servidor\n'
              '• Confirme que el API esté habilitado';
          break;

        case DioExceptionType.unknown:
          if (e.message?.contains('CERTIFICATE_VERIFY_FAILED') == true) {
            mensajeError = '🔒 Error de certificado SSL en drpestcontrol';
            sugerencia = '• Acepte el certificado HTTPS de drpestcontrol\n'
                '• Verifique la configuración SSL del servidor\n'
                '• Confirme que el certificado esté válido';
          } else if (e.message?.contains('XMLHttpRequest') == true ||
              e.message?.contains('Mixed Content') == true) {
            mensajeError = '🚫 Error de Mixed Content';
            sugerencia =
                '• La página está en HTTPS pero intenta conectar a HTTP\n'
                '• Use siempre https:// en la URL del servidor\n'
                '• Ejemplo: https://drpestcontrol:8000';
          } else {
            mensajeError = '❓ Error de conexión con drpestcontrol';
            sugerencia = e.message ?? 'Error sin descripción';
          }
          break;

        default:
          mensajeError = '⚠️ Error de conexión con drpestcontrol';
          sugerencia = e.message ?? 'Error desconocido';
      }
    }

    final mensajeCompleto = '$mensajeError\n\n💡 Sugerencias:\n$sugerencia';
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
}
