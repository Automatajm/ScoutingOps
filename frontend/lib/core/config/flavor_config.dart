import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum Flavor { development, staging, production }

// ===== LOGGER CENTRALIZADO =====
class Logger {
  static void debug(String message, [dynamic data]) {
    if (FlavorConfig.isDevelopment) {
      debugPrint('🐛 DEBUG: $message${data != null ? ' - $data' : ''}');
    }
  }

  static void info(String message, [dynamic data]) {
    if (!FlavorConfig.isProduction) {
      debugPrint('ℹ️ INFO: $message${data != null ? ' - $data' : ''}');
    }
  }

  static void warning(String message, [dynamic data]) {
    if (FlavorConfig.isProduction) {
      debugPrint('⚠️ WARNING: [REF-${DateTime.now().millisecondsSinceEpoch}]');
    } else {
      debugPrint('⚠️ WARNING: $message${data != null ? ' - $data' : ''}');
    }
  }

  static void error(String message, [dynamic error]) {
    if (FlavorConfig.isProduction) {
      debugPrint('❌ ERROR: [REF-${DateTime.now().millisecondsSinceEpoch}]');
    } else {
      debugPrint('❌ ERROR: $message${error != null ? ' - $error' : ''}');
    }
  }

  static void network(String message, [dynamic data]) {
    if (FlavorConfig.isDevelopment) {
      debugPrint('🌐 NETWORK: $message${data != null ? ' - $data' : ''}');
    }
  }

  static void auth(String message, [dynamic data]) {
    if (FlavorConfig.isProduction) {
      debugPrint('🔐 AUTH: [SESSION_ACTION]');
    } else {
      debugPrint('🔐 AUTH: $message${data != null ? ' - $data' : ''}');
    }
  }

  static void database(String message, [dynamic data]) {
    if (FlavorConfig.isProduction) {
      debugPrint('💾 DB: [QUERY_EXECUTED]');
    } else {
      debugPrint('💾 DB: $message${data != null ? ' - $data' : ''}');
    }
  }

  static void critical(String message, [dynamic error]) {
    String ref = 'REF-${DateTime.now().millisecondsSinceEpoch}';
    if (FlavorConfig.isProduction) {
      debugPrintThrottled('🚨 CRITICAL: $ref');
    } else {
      debugPrintThrottled(
          '🚨 CRITICAL: $message [$ref]${error != null ? ' - $error' : ''}');
    }
  }

  static void security(String message, [dynamic data]) {
    String ref = 'REF-${DateTime.now().millisecondsSinceEpoch}';
    if (FlavorConfig.isProduction) {
      debugPrintThrottled('🔒 SECURITY: $ref');
    } else {
      debugPrintThrottled(
          '🔒 SECURITY: $message [$ref]${data != null ? ' - $data' : ''}');
    }
  }
}

class FlavorConfig {
  static Flavor _currentFlavor = Flavor.development;
  static Map<String, dynamic> _config = {};
  static final ApiConfig _apiConfig = ApiConfig();

  static Future<void> initialize(Flavor flavor) async {
    _currentFlavor = flavor;
    await _loadConfig();

    Logger.info('Inicializando ApiConfig desde SharedPreferences');
    await _apiConfig.initialize();

    if (!_apiConfig.isConfigured || _apiConfig.baseUrl.isEmpty) {
      Logger.debug(
          'No hay configuración manual, usando valores de $_currentFlavor');

      await _apiConfig.updateFromServerResponse({
        'apiUrl': apiUrl,
        'baseUrl': apiUrl.replaceAll('/api', ''),
        'environment': environment,
        'version': version,
        'client': client,
      });
    } else {
      Logger.info('Configuración manual detectada, manteniéndola intacta', {
        'baseUrl': _apiConfig.baseUrl,
        'apiUrl': _apiConfig.apiUrl,
      });

      await _apiConfig.updateSystemInfo({
        'environment': environment,
        'version': version,
        'client': client,
      });
    }

    Logger.info('FlavorConfig inicializado completamente para WEB', {
      'apiConfigConfigured': _apiConfig.isConfigured,
      'baseUrl': _apiConfig.baseUrl,
      'apiUrl': _apiConfig.apiUrl,
      'platform': 'WEB',
      'flavor': _currentFlavor.toString(),
      'client': client,
    });
  }

  static Future<void> _loadConfig() async {
    String envFile;
    switch (_currentFlavor) {
      case Flavor.development:
        envFile = '.env.development';
        break;
      case Flavor.staging:
        envFile = '.env.staging';
        break;
      case Flavor.production:
        envFile = '.env.production';
        break;
    }

    try {
      await dotenv.load(fileName: envFile);
      Logger.info('✅ Archivo $envFile cargado exitosamente');
    } catch (e) {
      Logger.warning(
          'No se pudo cargar $envFile, usando valores por defecto', e);
    }

    _config = {
      // Client info
      'CLIENT': dotenv.env['CLIENT_NAME'] ?? 'pestcontrol',
      'APP_NAME': dotenv.env['APP_NAME'] ?? 'PestControl',

      // API URLs
      'API_URL': dotenv.env['API_BASE_URL'] ??
          _getDefaultApiUrl(_currentFlavor, dotenv.env['CLIENT_NAME']),
      'BASE_URL': dotenv.env['BACKEND_URL'] ??
          _getDefaultBaseUrl(_currentFlavor, dotenv.env['CLIENT_NAME']),

      // Environment info
      'ENVIRONMENT': dotenv.env['ENVIRONMENT'] ??
          dotenv.env['NODE_ENV'] ??
          _currentFlavor.toString(),
      'VERSION': dotenv.env['VERSION'] ?? '1.0.0',

      // SSL/Security
      'SSL_ENABLED': dotenv.env['SSL_ENABLED'] == 'true',
      'VERIFY_SSL': dotenv.env['VERIFY_SSL'] == 'true',
      'TRUST_SELF_SIGNED': dotenv.env['TRUST_SELF_SIGNED'] == 'true',

      // Timeouts
      'REQUEST_TIMEOUT': dotenv.env['REQUEST_TIMEOUT'] ?? '20000',
      'CONNECT_TIMEOUT': dotenv.env['CONNECT_TIMEOUT'] ?? '5000',

      // Logging
      'LOG_LEVEL': dotenv.env['LOG_LEVEL'] ?? 'error',
      'DEBUG_MODE': dotenv.env['DEBUG_MODE'] == 'true',

      // Features
      'ENABLE_ANALYTICS': dotenv.env['ENABLE_ANALYTICS'] == 'true',
      'ENABLE_CRASHLYTICS': dotenv.env['ENABLE_CRASHLYTICS'] == 'true',
    };

    Logger.debug('FlavorConfig cargado para WEB', {
      'client': _config['CLIENT'],
      'apiUrl': _config['API_URL'],
      'baseUrl': _config['BASE_URL'],
      'environment': _config['ENVIRONMENT'],
      'platform': 'Web',
      'flavor': _currentFlavor.toString(),
      'sslEnabled': _config['SSL_ENABLED'],
      'debugMode': _config['DEBUG_MODE'],
    });
  }

  // ✅ Genera URLs por defecto basadas en CLIENT_NAME y FLAVOR
  static String _getDefaultBaseUrl(Flavor flavor, String? clientName) {
    final client = clientName ?? 'pestcontrol';

    switch (flavor) {
      case Flavor.production:
        // En producción, usar IP específica o dominio
        return 'https://192.168.137.177:8000';
      case Flavor.staging:
        return 'https://$client:8080';
      case Flavor.development:
      default:
        return 'https://$client:8000';
    }
  }

  static String _getDefaultApiUrl(Flavor flavor, String? clientName) {
    return '${_getDefaultBaseUrl(flavor, clientName)}/api';
  }

  // Getters
  static String get client => _config['CLIENT'];
  static String get appName => _config['APP_NAME'];
  static String get apiUrl => _config['API_URL'];
  static String get baseUrl => _config['BASE_URL'];
  static String get environment => _config['ENVIRONMENT'];
  static String get version => _config['VERSION'];

  // Security
  static bool get sslEnabled => _config['SSL_ENABLED'];
  static bool get verifySSL => _config['VERIFY_SSL'];
  static bool get trustSelfSigned => _config['TRUST_SELF_SIGNED'];

  // Timeouts
  static int get requestTimeout =>
      int.tryParse(_config['REQUEST_TIMEOUT']) ?? 20000;
  static int get connectTimeout =>
      int.tryParse(_config['CONNECT_TIMEOUT']) ?? 5000;

  // Logging
  static String get logLevel => _config['LOG_LEVEL'];
  static bool get debugMode => _config['DEBUG_MODE'];

  // Features
  static bool get enableAnalytics => _config['ENABLE_ANALYTICS'];
  static bool get enableCrashlytics => _config['ENABLE_CRASHLYTICS'];

  static Map<String, dynamic> get config => _config;

  static Flavor get currentFlavor => _currentFlavor;
  static bool get isDevelopment => _currentFlavor == Flavor.development;
  static bool get isStaging => _currentFlavor == Flavor.staging;
  static bool get isProduction => _currentFlavor == Flavor.production;

  static ApiConfig get apiConfig => _apiConfig;
}

// Clase de compatibilidad para importaciones legacy
class DatabaseConfig {
  static String get apiUrl => ApiConfig.staticApiUrl;
}

/// Clase ApiConfig multi-cliente
class ApiConfig extends ChangeNotifier {
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  String _apiUrl = '';
  String _baseUrl = '';
  bool _isConfigured = false;
  String _environment = 'development';
  String _version = '1.0.0';
  String _client = 'pestcontrol';

  List<String> _suggestedUrls = [];
  Map<String, dynamic> _serverInfo = {};
  bool _isInitialized = false;

  // Getters
  String get apiUrl => _apiUrl;
  String get baseUrl => _baseUrl;
  bool get isConfigured => _isConfigured;
  String get environment => _environment;
  String get version => _version;
  String get client => _client;
  List<String> get suggestedUrls => _suggestedUrls;
  Map<String, dynamic> get serverInfo => _serverInfo;

  // URLs específicas de servicios
  String get authUrl => '$_apiUrl/auth';
  String get usersUrl => '$_apiUrl/usuarios';
  String get rolesUrl => '$_apiUrl/roles';
  String get variedadesUrl => '$_apiUrl/variedades';
  String get unidadesCultivoUrl => '$_apiUrl/unidadesCultivo';
  String get plagasUrl => '$_apiUrl/plagas';
  String get nivelesInfestacionUrl => '$_apiUrl/nivelesinfestacion';
  String get lotesUrl => '$_apiUrl/lotes';
  String get monitoreoUrl => '$_apiUrl/monitoreo';

  String get loginUrl => '$authUrl/login';
  String get configUrl => '$_apiUrl/config';
  String get healthUrl => '$_apiUrl/health';
  String get systemStatusUrl => '$_apiUrl/system/status';
  String get diagnosticoUrl => '$_apiUrl/diagnostico';

  static String get staticApiUrl => ApiConfig().apiUrl;

  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.warning('ApiConfig ya está inicializado, omitiendo...');
      return;
    }

    Logger.debug('Inicializando ApiConfig para WEB...');

    _client = FlavorConfig.client;
    await _loadFromStorage();
    await _generateSuggestedUrls();

    if (!isConfigured || _baseUrl.isEmpty) {
      _setDefaultUrls();
      Logger.debug('Usando URLs por defecto (no hay configuración guardada)');
    }

    _isInitialized = true;

    Logger.info('ApiConfig WEB Inicializado', {
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'isConfigured': isConfigured,
      'platform': 'WEB',
      'client': _client,
      'flavor': FlavorConfig.currentFlavor.toString(),
      'suggestedUrlsCount': _suggestedUrls.length,
    });
  }

  Future<void> _generateSuggestedUrls() async {
    _suggestedUrls.clear();

    switch (FlavorConfig.currentFlavor) {
      case Flavor.production:
        _suggestedUrls.addAll([
          'https://192.168.137.177:8000', // IP de producción
          'https://$_client:8000', // Fallback
          'https://$_client:8080', // Puerto alternativo
        ]);
        break;
      case Flavor.staging:
        _suggestedUrls.addAll([
          'https://$_client:8080', // Staging principal
          'https://$_client:8000', // Fallback
        ]);
        break;
      case Flavor.development:
      default:
        _suggestedUrls.addAll([
          'https://$_client:8000', // Development principal
          'https://$_client:8080', // Alternativo
        ]);
        break;
    }

    Logger.debug('URLs sugeridas generadas', {
      'count': _suggestedUrls.length,
      'urls': _suggestedUrls,
      'client': _client,
      'flavor': FlavorConfig.currentFlavor.toString(),
    });
  }

  void _setDefaultUrls() {
    _baseUrl = FlavorConfig.baseUrl;
    _apiUrl = FlavorConfig.apiUrl;
    _isConfigured = false;
    _environment = FlavorConfig.environment;
    _version = FlavorConfig.version;
    _client = FlavorConfig.client;

    Logger.debug('URLs por defecto establecidas', {
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'platform': 'WEB',
      'client': _client,
      'flavor': FlavorConfig.currentFlavor.toString(),
      'isConfigured': _isConfigured,
    });
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedBaseUrl = prefs.getString('baseUrl');
      final storedApiUrl = prefs.getString('apiUrl');
      final storedEnvironment =
          prefs.getString('environment') ?? FlavorConfig.environment;
      final storedVersion = prefs.getString('version') ?? FlavorConfig.version;
      final storedClient = prefs.getString('client') ?? FlavorConfig.client;
      final storedConfigured = prefs.getBool('isConfigured') ?? false;

      Logger.debug('Cargando configuración guardada', {
        'baseUrl': storedBaseUrl,
        'apiUrl': storedApiUrl,
        'isConfigured': storedConfigured,
        'client': storedClient,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      if (_esUrlValida(storedBaseUrl) &&
          _esUrlValida(storedApiUrl) &&
          storedConfigured) {
        _baseUrl = storedBaseUrl!;
        _apiUrl = storedApiUrl!;
        _environment = storedEnvironment;
        _version = storedVersion;
        _client = storedClient;
        _isConfigured = true;

        Logger.info('Configuración válida restaurada', {
          'baseUrl': _baseUrl,
          'apiUrl': _apiUrl,
          'isConfigured': _isConfigured,
          'client': _client,
          'flavor': FlavorConfig.currentFlavor.toString(),
        });

        notifyListeners();
      } else {
        Logger.debug('No hay configuración válida guardada');
        _isConfigured = false;
      }
    } catch (e) {
      Logger.error('Error cargando configuración', e);
      _isConfigured = false;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('baseUrl', _baseUrl);
      await prefs.setString('apiUrl', _apiUrl);
      await prefs.setString('environment', _environment);
      await prefs.setString('version', _version);
      await prefs.setString('client', _client);
      await prefs.setBool('isConfigured', _isConfigured);

      Logger.debug('Configuración guardada', {
        'baseUrl': _baseUrl,
        'apiUrl': _apiUrl,
        'isConfigured': _isConfigured,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });
    } catch (e) {
      Logger.error('Error guardando configuración', e);
    }
  }

  Future<void> updateBaseUrl(String newBaseUrl) async {
    if (_esUrlValida(newBaseUrl)) {
      _baseUrl = _limpiarUrl(newBaseUrl);
      _apiUrl = '$_baseUrl/api';
      _isConfigured = true;

      Logger.info('URL configurada manualmente', {
        'newBaseUrl': _baseUrl,
        'newApiUrl': _apiUrl,
        'isConfigured': _isConfigured,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      notifyListeners();
      await _saveToStorage();
    } else {
      Logger.warning('URL base inválida', newBaseUrl);
    }
  }

  Future<void> updateApiUrl(String newApiUrl) async {
    if (_esUrlValida(newApiUrl)) {
      _apiUrl = _limpiarUrl(newApiUrl);

      if (_apiUrl.endsWith('/api')) {
        _baseUrl = _apiUrl.substring(0, _apiUrl.length - 4);
      } else {
        _baseUrl = _apiUrl;
        _apiUrl = '$_baseUrl/api';
      }

      _isConfigured = true;

      Logger.info('API configurada manualmente', {
        'newApiUrl': _apiUrl,
        'derivedBaseUrl': _baseUrl,
        'isConfigured': _isConfigured,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      notifyListeners();
      await _saveToStorage();
    } else {
      Logger.warning('URL API inválida', newApiUrl);
    }
  }

  Future<void> updateFromServerResponse(Map<String, dynamic>? config) async {
    if (config == null) return;

    Logger.debug('Respuesta del servidor', config);

    _serverInfo = Map<String, dynamic>.from(config);

    final hasManualConfig =
        _isConfigured && _baseUrl.isNotEmpty && _apiUrl.isNotEmpty;

    if (hasManualConfig) {
      Logger.info('Configuración manual detectada - Manteniendo URLs', {
        'baseUrlPreserved': _baseUrl,
        'apiUrlPreserved': _apiUrl,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      await updateSystemInfo(config);
      return;
    }

    bool updated = false;

    if (config.containsKey('baseUrl')) {
      String serverBaseUrl = _limpiarUrl(config['baseUrl'].toString());
      if (_baseUrl != serverBaseUrl) {
        _baseUrl = serverBaseUrl;
        _apiUrl = '$_baseUrl/api';
        updated = true;
      }
    }

    if (config.containsKey('apiUrl')) {
      String serverApiUrl = _limpiarUrl(config['apiUrl'].toString());
      if (!serverApiUrl.endsWith('/api')) {
        serverApiUrl = '$serverApiUrl/api';
      }
      if (_apiUrl != serverApiUrl) {
        _apiUrl = serverApiUrl;
        if (!config.containsKey('baseUrl')) {
          _baseUrl = serverApiUrl.endsWith('/api')
              ? serverApiUrl.substring(0, serverApiUrl.length - 4)
              : serverApiUrl;
        }
        updated = true;
      }
    }

    await updateSystemInfo(config);

    if (updated) {
      _isConfigured = false;

      Logger.info('URLs actualizadas desde servidor', {
        'baseUrl': _baseUrl,
        'apiUrl': _apiUrl,
        'configuredManually': _isConfigured,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> updateSystemInfo(Map<String, dynamic> config) async {
    bool updated = false;

    if (config.containsKey('environment')) {
      final newEnv = config['environment'].toString();
      if (_environment != newEnv) {
        _environment = newEnv;
        updated = true;
      }
    }

    if (config.containsKey('version')) {
      final newVersion = config['version'].toString();
      if (_version != newVersion) {
        _version = newVersion;
        updated = true;
      }
    }

    if (config.containsKey('client')) {
      final newClient = config['client'].toString();
      if (_client != newClient) {
        _client = newClient;
        updated = true;
      }
    }

    if (updated) {
      Logger.debug('Info del sistema actualizada', {
        'environment': _environment,
        'version': _version,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      notifyListeners();
      await _saveToStorage();
    }
  }

  bool _esUrlValida(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      // Regex flexible para URLs válidas
      final validUrlRegex = RegExp(
        r'^(https?://)?' // Protocolo opcional
        r'(' // Inicio de grupo de hosts válidos
        r'[a-zA-Z0-9\-]+' // Cualquier hostname válido
        r'|' // O
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' // IPv4
        r')' // Fin de grupo
        r'(:\d+)?' // Puerto opcional
        r'(/.*)?$', // Path opcional
        caseSensitive: false,
      );

      final isValid = validUrlRegex.hasMatch(url.toLowerCase());

      Logger.debug('Validando URL', {
        'url': url,
        'valid': isValid,
        'client': _client,
        'flavor': FlavorConfig.currentFlavor.toString(),
      });

      return isValid;
    } catch (e) {
      Logger.error('Error validando URL', e);
      return false;
    }
  }

  String _limpiarUrl(String url) {
    url = url.trim();

    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }

    url = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    return url;
  }

  String getFullUrl(String endpoint) {
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }
    return '$_apiUrl$endpoint';
  }

  Future<void> reset() async {
    Logger.debug('Reiniciando configuración a valores por defecto');

    _setDefaultUrls();
    _serverInfo.clear();
    await _generateSuggestedUrls();
    await _saveToStorage();
    notifyListeners();

    Logger.info('Configuración reseteada', {
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'client': _client,
      'flavor': FlavorConfig.currentFlavor.toString(),
    });
  }

  bool isLocalUrl() {
    return _baseUrl.contains('localhost') ||
        _baseUrl.contains('127.0.0.1') ||
        RegExp(r'192\.168\.\d+\.\d+').hasMatch(_baseUrl) ||
        RegExp(r'10\.\d+\.\d+\.\d+').hasMatch(_baseUrl) ||
        RegExp(r'172\.(1[6-9]|2\d|3[01])\.\d+\.\d+').hasMatch(_baseUrl);
  }

  bool isHttpsUrl() {
    return _baseUrl.startsWith('https://');
  }

  bool isExternalUrl() {
    return !isLocalUrl();
  }

  String getConnectionType() {
    if (_baseUrl.contains('ngrok')) return 'ngrok';
    if (_baseUrl.contains('loca.lt')) return 'localtunnel';
    if (_baseUrl.contains('herokuapp.com')) return 'heroku';
    if (_baseUrl.contains('vercel.app')) return 'vercel';
    if (_baseUrl.contains('netlify.app')) return 'netlify';
    if (isLocalUrl()) return 'local';
    return 'external';
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'isConfigured': _isConfigured,
      'environment': _environment,
      'version': _version,
      'client': _client,
      'platform': 'WEB',
      'flavor': FlavorConfig.currentFlavor.toString(),
      'isLocalUrl': isLocalUrl(),
      'isHttpsUrl': isHttpsUrl(),
      'connectionType': getConnectionType(),
      'suggestedUrls': _suggestedUrls,
      'serverInfo': _serverInfo,
      'allUrls': {
        'auth': authUrl,
        'config': configUrl,
        'health': healthUrl,
        'login': loginUrl,
        'monitoreo': monitoreoUrl,
        'diagnostico': diagnosticoUrl,
      }
    };
  }

  Future<Map<String, dynamic>> testConnectivity() async {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'isConfigured': _isConfigured,
      'connectionType': getConnectionType(),
      'platform': 'WEB',
      'client': _client,
      'flavor': FlavorConfig.currentFlavor.toString(),
      'isHttps': isHttpsUrl(),
    };
  }
}
