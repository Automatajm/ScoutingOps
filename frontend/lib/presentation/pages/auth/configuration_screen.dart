import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../../../core/config/flavor_config.dart';

/// Configuration Screen Refactorizado - Zero Hardcoding
///
/// Características:
/// - ✅ Lee CLIENT_NAME dinámicamente desde .env
/// - ✅ Genera URLs basadas en FlavorConfig
/// - ✅ Zero hardcoding de nombres de clientes
/// - ✅ UI moderna y limpia
/// - ✅ Auto-configuración inteligente
/// - ✅ Funciona para cualquier cliente sin cambios de código
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

  // ✅ DINÁMICO: Cliente desde FlavorConfig (lee de .env)
  String get _clientName => FlavorConfig.client;

  // ✅ DINÁMICO: Detectar si la página está en HTTPS
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

  // ✅ DINÁMICO: Protocolo correcto según contexto
  String get _protocoloActual {
    if (_paginaEnHttps) return 'HTTPS'; // Forzar HTTPS si página está en HTTPS
    return FlavorConfig.isDevelopment ? 'HTTP' : 'HTTPS';
  }

  // ✅ DINÁMICO: Color del protocolo
  Color get _protocoloColor {
    if (_paginaEnHttps) return Colors.green;
    return FlavorConfig.isDevelopment ? Colors.orange : Colors.green;
  }

  // ✅ DINÁMICO: Descripción del entorno
  String get _descripcionEntorno {
    if (_paginaEnHttps) {
      return 'HTTPS Requerido (Página en HTTPS)';
    }
    return FlavorConfig.isDevelopment
        ? 'Development (HTTP - Sin SSL)'
        : 'Production (HTTPS - SSL Requerido)';
  }

  // ✅ DINÁMICO: URLs a probar (generadas automáticamente)
  List<String> get _clientUrls {
    final protocol =
        _paginaEnHttps ? 'https' : (_protocoloActual.toLowerCase());
    final client = _clientName;

    if (_paginaEnHttps) {
      // Si página en HTTPS, solo HTTPS
      return [
        'https://$client:8000', // Puerto principal
        'https://$client:8080', // Puerto alternativo
        FlavorConfig.baseUrl, // URL configurada en flavor
      ];
    }

    if (FlavorConfig.isDevelopment) {
      // Development: HTTP + localhost
      return [
        'http://localhost:8000',
        'http://localhost:8080',
        'http://$client:8000',
        'http://$client:8080',
      ];
    }

    // Production: HTTPS
    return [
      'https://$client:8000',
      'https://$client:8080',
      FlavorConfig.baseUrl,
    ];
  }

  @override
  void initState() {
    super.initState();
    _setupDioInterceptors();

    // ✅ FIX: Si ya está configurado, saltar configuración inmediatamente
    if (widget.apiConfig.isConfigured &&
        widget.apiConfig.baseUrl.isNotEmpty &&
        widget.apiConfig.apiUrl.isNotEmpty) {
      if (kDebugMode) {
        print('✅ Configuración válida detectada, saltando auto-config');
        print('   baseUrl: ${widget.apiConfig.baseUrl}');
        print('   apiUrl: ${widget.apiConfig.apiUrl}');
      }

      // Saltar directamente a la app
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onConfigSuccess();
        }
      });
      return;
    }

    _iniciarAutoConfiguracion();
  }

  void _iniciarAutoConfiguracion() async {
    if (kDebugMode) {
      print('🤖 Iniciando auto-configuración para cliente: $_clientName');
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
      // Verificar configuración existente
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
      }

      // Intentar auto-configuración
      final autoConfigExitosa = await _intentarAutoConfiguracion();

      if (autoConfigExitosa) {
        if (kDebugMode) {
          print('✅ Auto-configuración exitosa para $_clientName');
        }
        _continuarAApp();
      } else {
        if (kDebugMode) {
          print('❌ Auto-configuración falló, mostrando UI manual...');
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
      String urlToTest = widget.apiConfig.baseUrl;

      // Convertir a HTTPS si página está en HTTPS
      if (_paginaEnHttps && urlToTest.startsWith('http://')) {
        urlToTest = urlToTest.replaceFirst('http://', 'https://');
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
      return false;
    }
  }

  Future<bool> _intentarAutoConfiguracion() async {
    for (String url in _clientUrls) {
      try {
        if (kDebugMode) {
          print('🔍 Probando: $url');
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
            print('✅ Auto-configuración exitosa: $url');
          }

          return true;
        }
      } catch (e) {
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
      _errorMessage = '🚨 No se pudo conectar automáticamente\n\n'
          'Cliente: $_clientName\n'
          'Entorno: $_descripcionEntorno\n'
          'Protocolo: $_protocoloActual\n\n'
          'Configure manualmente la conexión al servidor.';
    });

    // Pre-completar URL según contexto
    if (_paginaEnHttps) {
      _urlController.text = '$_clientName:8000';
    } else if (FlavorConfig.isDevelopment) {
      _urlController.text = 'localhost:8000';
    } else {
      _urlController.text = '$_clientName:8000';
    }
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

  // ✅ DINÁMICO: Formatear URL respetando protocolo
  String _formatUrl(String url) {
    url = url.trim();

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (_paginaEnHttps) {
        url = 'https://$url';
      } else if (FlavorConfig.isDevelopment) {
        url = 'http://$url';
      } else {
        url = 'https://$url';
      }
    }

    // Convertir a HTTPS si página está en HTTPS
    if (_paginaEnHttps && url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }

    // Limpiar trailing slashes
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
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
      await widget.apiConfig.reset();

      // Reset según contexto
      if (_paginaEnHttps) {
        _urlController.text = '$_clientName:8000';
      } else if (FlavorConfig.isDevelopment) {
        _urlController.text = 'localhost:8000';
      } else {
        _urlController.text = '$_clientName:8000';
      }

      _mostrarMensajeExito('🔄 Configuración reseteada\n\n'
          '✅ Restaurado a ${_urlController.text}\n'
          '🔧 Cliente: $_clientName\n'
          '🏷️ Protocolo: $_protocoloActual');
    } catch (e) {
      _mostrarMensajeError('❌ Error al resetear: $e');
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
        ? '$_clientName:8000'
        : (FlavorConfig.isDevelopment ? 'localhost:8000' : '$_clientName:8000');

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.refresh_rounded,
                    color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                const Text('Resetear Configuración'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Resetear a configuración por defecto?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(height: 8),
                      _buildInfoRow('Cliente', _clientName),
                      _buildInfoRow('URL', defaultUrl),
                      _buildInfoRow('Protocolo', _protocoloActual),
                      _buildInfoRow(
                          'Entorno',
                          FlavorConfig.currentFlavor
                              .toString()
                              .split('.')
                              .last),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Resetear'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('• $label: ',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  // ========================================================================
  // UI WIDGETS - MODERNA Y LIMPIA
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    // Pantalla transparente durante auto-configuración
    if (_autoConfigInProgress) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    // Mostrar UI manual solo cuando hay problemas
    if (!_showManualConfig) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildAutoRetryButton(),
                const SizedBox(height: 24),
                _buildUrlCard(),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty) _buildErrorMessage(),
                if (_successMessage.isNotEmpty) _buildSuccessMessage(),
                const SizedBox(height: 16),
                _buildActionButtons(),
                const SizedBox(height: 24),
                _buildInstructionsCard(),
                const SizedBox(height: 16),
                _buildDebugInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.settings_rounded, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Configuración - $_clientName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: _protocoloColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.autorenew_rounded),
          onPressed: _reintentarAutoConfiguracion,
          tooltip: 'Reintentar auto-configuración',
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _isResetting ? null : _resetConfiguration,
          tooltip: 'Resetear',
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_protocoloColor.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _protocoloColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _protocoloColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.pest_control_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              'Pest Control',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _protocoloColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _clientName.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Badge del entorno
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _protocoloColor.withOpacity(0.15),
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
                            ? Icons.code
                            : Icons.production_quantity_limits),
                    size: 18,
                    color: _protocoloColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _descripcionEntorno,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _protocoloColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoRetryButton() {
    return ElevatedButton.icon(
      onPressed: _autoConfigInProgress ? null : _reintentarAutoConfiguracion,
      icon: Icon(_autoConfigInProgress
          ? Icons.hourglass_empty
          : Icons.autorenew_rounded),
      label: Text(
        _autoConfigInProgress
            ? 'Reintentando...'
            : 'Reintentar Auto-Configuración',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  Widget _buildUrlCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_rounded, color: _protocoloColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Servidor $_clientName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo URL
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL del Servidor',
                hintText: _paginaEnHttps
                    ? '$_clientName:8000'
                    : (FlavorConfig.isDevelopment
                        ? 'localhost:8000'
                        : '$_clientName:8000'),
                helperText:
                    'Puerto 8000 (principal) o 8080 (alternativo) - $_protocoloActual',
                prefixIcon: Icon(
                  _paginaEnHttps
                      ? Icons.lock
                      : (FlavorConfig.isDevelopment
                          ? Icons.computer
                          : Icons.business),
                  color: _protocoloColor,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _protocoloColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _protocoloActual,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _protocoloColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _urlController.clear(),
                    ),
                  ],
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _protocoloColor, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese la URL del servidor';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Sugerencias de URL
            _buildUrlSuggestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline,
                color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 8),
            Text(
              'Opciones disponibles ($_protocoloActual):',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Advertencia Mixed Content
        if (_paginaEnHttps)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Página en HTTPS: todas las conexiones deben ser HTTPS',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Chips de URLs
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _clientUrls.map((url) {
            final cleanUrl =
                url.replaceAll('https://', '').replaceAll('http://', '');
            final isCurrentUrl = _urlController.text == cleanUrl;
            final port = cleanUrl.contains(':8000') ? '8000' : '8080';
            final isPrimary = port == '8000';
            final isHttps = url.startsWith('https://');

            return ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 14,
                    color: isPrimary
                        ? Colors.amber.shade700
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isHttps ? Icons.lock : Icons.lock_open,
                    size: 14,
                    color: isHttps ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cleanUrl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isCurrentUrl ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                _urlController.text = cleanUrl;
                setState(() {});
              },
              backgroundColor: isCurrentUrl
                  ? (isPrimary ? Colors.amber.shade100 : Colors.blue.shade100)
                  : null,
              side: isCurrentUrl
                  ? BorderSide(
                      color: isPrimary
                          ? Colors.amber.shade400
                          : Colors.blue.shade400)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red.shade900, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline,
                color: Colors.green.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _successMessage,
                style: TextStyle(color: Colors.green.shade900, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Botón Conectar
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _probarConexion,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.link_rounded),
          label: Text(
            _isLoading ? 'Conectando...' : 'Conectar a $_clientName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _protocoloColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),

        const SizedBox(height: 12),

        // Botón Reset
        OutlinedButton.icon(
          onPressed: (_isLoading || _isResetting) ? null : _resetConfiguration,
          icon: _isResetting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.orange.shade700, strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label:
              Text(_isResetting ? 'Reseteando...' : 'Resetear Configuración'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade700,
            side: BorderSide(color: Colors.orange.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Instrucciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionSection(
              '🎯 Configuración Actual',
              [
                'Cliente: $_clientName',
                'Flavor: ${FlavorConfig.currentFlavor.toString().split('.').last}',
                'Protocolo: $_protocoloActual',
                'Entorno: $_descripcionEntorno',
              ],
              _protocoloColor,
            ),
            const SizedBox(height: 16),
            if (_paginaEnHttps)
              _buildInstructionSection(
                '⚠️ Mixed Content',
                [
                  'Página cargada con HTTPS',
                  'Todas las conexiones DEBEN ser HTTPS',
                  'El navegador bloquea conexiones HTTP',
                  'Use siempre https://$_clientName:8000',
                ],
                Colors.amber.shade700,
              )
            else if (FlavorConfig.isDevelopment)
              _buildInstructionSection(
                '🔧 Development',
                [
                  'localhost:8000 (Principal)',
                  'localhost:8080 (Alternativo)',
                  'HTTP sin SSL para debugging',
                ],
                Colors.orange.shade700,
              )
            else
              _buildInstructionSection(
                '🌟 Production',
                [
                  '$_clientName:8000 (Principal)',
                  '$_clientName:8080 (Alternativo)',
                  'HTTPS requerido para funciones del navegador',
                ],
                Colors.green.shade700,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionSection(
      String title, List<String> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: color.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    final debugInfo = widget.apiConfig.getDebugInfo();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(Icons.bug_report_rounded, color: _protocoloColor),
        title: const Text('Información de Debug'),
        children: [
          ListTile(
            leading: const Icon(Icons.business_rounded),
            title: const Text('Cliente'),
            subtitle: Text(_clientName.toUpperCase()),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('URL Configurada'),
            subtitle: Text(debugInfo['baseUrl']?.isNotEmpty == true
                ? debugInfo['baseUrl']
                : 'No configurado'),
            trailing: debugInfo['baseUrl']?.isNotEmpty == true
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.error, color: Colors.red),
          ),
          ListTile(
            leading: Icon(
              _paginaEnHttps
                  ? Icons.lock
                  : (FlavorConfig.isDevelopment ? Icons.code : Icons.security),
              color: _protocoloColor,
            ),
            title: const Text('Protocolo'),
            subtitle: Text(
                '$_protocoloActual - ${FlavorConfig.currentFlavor.toString().split('.').last}'),
          ),
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.web_rounded),
              title: const Text('Página Web'),
              subtitle: Text(Uri.base.toString()),
            ),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Estado'),
            subtitle: Text(debugInfo['isConfigured'] == true
                ? 'Configurado'
                : 'No configurado'),
            trailing: debugInfo['isConfigured'] == true
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.warning, color: Colors.orange),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // LÓGICA DE CONEXIÓN
  // ========================================================================

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
        print('   Cliente: $_clientName');
        print('   Base URL: $baseUrl');
        print('   API URL: $apiUrl');
        print('   Protocolo: $_protocoloActual');
      }

      final endpoints = [
        '$apiUrl/config',
        '$apiUrl/system/status',
        '$apiUrl/health',
        baseUrl,
      ];

      Response? successResponse;
      String workingEndpoint = '';
      Map<String, dynamic> serverConfig = {};

      for (var endpoint in endpoints) {
        try {
          final response = await _dio.get(
            endpoint,
            options: Options(
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
            ),
          );

          if (response.statusCode == 200) {
            successResponse = response;
            workingEndpoint = endpoint;
            if (response.data is Map) {
              serverConfig = Map<String, dynamic>.from(response.data);
            }
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (successResponse != null) {
        await _procesarRespuestaExitosa(
            baseUrl, apiUrl, serverConfig, workingEndpoint);
      } else {
        _mostrarMensajeError('❌ No se pudo conectar a $_clientName\n\n'
            'Verifique que el servidor esté ejecutándose\n'
            'Protocolo requerido: $_protocoloActual');
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

  Future<void> _procesarRespuestaExitosa(
    String baseUrl,
    String apiUrl,
    Map<String, dynamic> serverConfig,
    String workingEndpoint,
  ) async {
    await widget.apiConfig.updateBaseUrl(baseUrl);

    _connectionInfo = {
      'baseUrl': baseUrl,
      'workingEndpoint': workingEndpoint,
      'client': _clientName,
      'timestamp': DateTime.now().toIso8601String(),
      'protocol': _protocoloActual,
    };

    final version = serverConfig['version'] ?? 'N/A';
    final environment = serverConfig['environment'] ?? 'N/A';

    String successMsg = '✅ Conectado exitosamente\n\n'
        '🏢 Cliente: $_clientName\n'
        '🌐 Servidor: $baseUrl\n'
        '🔒 Protocolo: $_protocoloActual\n'
        '📋 Versión: $version\n'
        '🏷️ Environment: $environment';

    _mostrarMensajeExito(successMsg);

    await Future.delayed(const Duration(milliseconds: 2000));

    if (mounted) {
      widget.onConfigSuccess();
    }
  }

  void _manejarErrorConexion(dynamic e) {
    String mensajeError = 'Error de conexión';
    String sugerencia = '';

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          mensajeError = '⏰ Tiempo de espera agotado';
          sugerencia = 'Verifique que el servidor esté ejecutándose';
          break;

        case DioExceptionType.connectionError:
          mensajeError = '🔌 No se pudo conectar';
          sugerencia =
              'Verifique la conectividad de red y que $_protocoloActual esté habilitado';
          if (_paginaEnHttps) {
            sugerencia += '\n⚠️ Use https:// (página en HTTPS)';
          }
          break;

        case DioExceptionType.badResponse:
          mensajeError = '📋 Error del servidor (${e.response?.statusCode})';
          sugerencia = 'El servidor respondió con error';
          break;

        case DioExceptionType.unknown:
          if (e.message?.contains('Mixed Content') == true) {
            mensajeError = '🚫 Error de Mixed Content';
            sugerencia = 'Use siempre https:// cuando la página está en HTTPS';
          } else {
            mensajeError = '❓ Error de conexión';
            sugerencia = e.message ?? 'Error desconocido';
          }
          break;

        default:
          mensajeError = '⚠️ Error de conexión';
          sugerencia = e.message ?? 'Error desconocido';
      }
    }

    _mostrarMensajeError('$mensajeError\n\n💡 $sugerencia');
  }

  void _mostrarMensajeError(String mensaje) {
    if (mounted) {
      setState(() {
        _errorMessage = mensaje;
        _successMessage = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
