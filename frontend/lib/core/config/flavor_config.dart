import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum Flavor { development, staging, production }

// ===== LOGGER CENTRALIZADO INTEGRADO =====
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

  // Para casos críticos que SÍ necesitas ver en producción
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
      Logger.debug('No hay configuración manual, usando valores por defecto');

      await _apiConfig.updateFromServerResponse({
        'apiUrl': apiUrl,
        'baseUrl': apiUrl.replaceAll('/api', ''),
        'environment': environment,
        'version': version
      });
    } else {
      Logger.info('Configuración manual detectada, manteniéndola intacta', {
        'baseUrl': _apiConfig.baseUrl,
        'apiUrl': _apiConfig.apiUrl,
      });

      await _apiConfig.updateSystemInfo({
        'environment': environment,
        'version': version,
      });
    }

    Logger.info('FlavorConfig inicializado completamente para WEB', {
      'apiConfigConfigured': _apiConfig.isConfigured,
      'baseUrl': _apiConfig.baseUrl,
      'apiUrl': _apiConfig.apiUrl,
      'platform': 'WEB',
      'flavor': _currentFlavor.toString(),
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
    } catch (e) {
      Logger.warning(
          'No se pudo cargar $envFile, usando valores por defecto', e);
    }

    _config = {
      'API_URL': dotenv.env['API_URL'] ?? _getDefaultApiUrl(),
      'ENVIRONMENT': dotenv.env['ENVIRONMENT'] ?? 'development',
      'VERSION': dotenv.env['VERSION'] ?? '1.0.0',
      'DB_HOST': dotenv.env['DB_HOST'] ?? 'localhost',
      'DB_PORT': dotenv.env['DB_PORT'] ?? '5432',
      'DB_NAME': dotenv.env['DB_NAME'] ?? 'Pest_Control',
      'DB_USER': dotenv.env['DB_USER'] ?? 'postgres',
      'DB_PASSWORD': dotenv.env['DB_PASSWORD'] ?? '',
    };

    Logger.debug('FlavorConfig cargado para WEB', {
      'apiUrl': _config['API_URL'],
      'environment': _config['ENVIRONMENT'],
      'platform': 'Web',
      'flavor': _currentFlavor.toString(),
    });
  }

  static String _getDefaultApiUrl() {
    return 'https://10.0.0.19:8000/api';
  }

  // Getters para acceder a la configuración
  static String get apiUrl => _config['API_URL'];
  static String get environment => _config['ENVIRONMENT'];
  static String get version => _config['VERSION'];
  static String get dbHost => _config['DB_HOST'];
  static String get dbPort => _config['DB_PORT'];
  static String get dbName => _config['DB_NAME'];
  static String get dbUser => _config['DB_USER'];
  static String get dbPassword => _config['DB_PASSWORD'];

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

/// Clase ApiConfig para aplicaciones WEB (móvil + PC)
class ApiConfig extends ChangeNotifier {
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  // Valores por defecto
  String _apiUrl = '';
  String _baseUrl = '';
  bool _isConfigured = false;
  String _environment = 'development';
  String _version = '1.0.0';

  // Información adicional
  List<String> _suggestedUrls = [];
  Map<String, dynamic> _serverInfo = {};
  bool _isInitialized = false;

  // Getters
  String get apiUrl => _apiUrl;
  String get baseUrl => _baseUrl;
  bool get isConfigured => _isConfigured;
  String get environment => _environment;
  String get version => _version;
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

    await _loadFromStorage();
    await _generateSuggestedUrlsWeb();

    if (!isConfigured || _baseUrl.isEmpty) {
      _setDefaultUrlsWeb();
      Logger.debug(
          'Usando URLs por defecto para WEB (no hay configuración guardada)');
    }

    _isInitialized = true;

    Logger.info('ApiConfig WEB Inicializado', {
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'isConfigured': isConfigured,
      'platform': 'WEB',
      'suggestedUrlsCount': _suggestedUrls.length,
    });
  }

  Future<void> _generateSuggestedUrlsWeb() async {
    _suggestedUrls.clear();

    _suggestedUrls.addAll([
      'https://10.0.0.19:8000',
      'https://localhost:8000',
      'https://127.0.0.1:8000',
    ]);

    _suggestedUrls.addAll([
      'http://10.0.0.19:8000',
      'http://localhost:8000',
      'http://127.0.0.1:8000',
    ]);

    _suggestedUrls.addAll([
      'https://192.168.1.100:8000',
      'https://192.168.0.100:8000',
      'https://192.168.1.1:8000',
    ]);

    _suggestedUrls.addAll([
      'https://xxx.ngrok-free.app',
      'https://xxx.ngrok.io',
      'https://xxx.loca.lt',
      'https://xxx.herokuapp.com',
      'https://xxx.vercel.app',
    ]);

    Logger.debug('URLs sugeridas para WEB generadas', {
      'count': _suggestedUrls.length,
      'first5': _suggestedUrls.take(5).toList(),
    });
  }

  void _setDefaultUrlsWeb() {
    _baseUrl = 'https://10.0.0.19:8000';
    _apiUrl = '$_baseUrl/api';
    _isConfigured = false;
    _environment = 'development';
    _version = '1.0.0';

    Logger.debug('URLs por defecto WEB establecidas', {
      'baseUrl': _baseUrl,
      'apiUrl': _apiUrl,
      'platform': 'WEB',
      'isConfigured': _isConfigured,
    });
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedBaseUrl = prefs.getString('baseUrl');
      final storedApiUrl = prefs.getString('apiUrl');
      final storedEnvironment = prefs.getString('environment') ?? 'development';
      final storedVersion = prefs.getString('version') ?? '1.0.0';
      final storedConfigured = prefs.getBool('isConfigured') ?? false;

      Logger.debug('Cargando configuración WEB guardada', {
        'baseUrl': storedBaseUrl,
        'apiUrl': storedApiUrl,
        'isConfigured': storedConfigured,
      });

      if (_esUrlValidaWeb(storedBaseUrl) &&
          _esUrlValidaWeb(storedApiUrl) &&
          storedConfigured) {
        _baseUrl = storedBaseUrl!;
        _apiUrl = storedApiUrl!;
        _environment = storedEnvironment;
        _version = storedVersion;
        _isConfigured = true;

        Logger.info('Configuración WEB válida restaurada', {
          'baseUrl': _baseUrl,
          'apiUrl': _apiUrl,
          'isConfigured': _isConfigured,
        });

        notifyListeners();
      } else {
        Logger.debug('No hay configuración WEB válida guardada');
        _isConfigured = false;
      }
    } catch (e) {
      Logger.error('Error cargando configuración WEB', e);
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
      await prefs.setBool('isConfigured', _isConfigured);

      Logger.debug('Configuración WEB guardada', {
        'baseUrl': _baseUrl,
        'apiUrl': _apiUrl,
        'isConfigured': _isConfigured,
      });

      await Future.delayed(const Duration(milliseconds: 100));
      final verification = await _verifyStorageSaveWeb();

      Logger.debug('Verificación WEB', {'success': verification});
    } catch (e) {
      Logger.error('Error guardando configuración WEB', e);
    }
  }

  Future<bool> _verifyStorageSaveWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBase = prefs.getString('baseUrl');
      final savedApi = prefs.getString('apiUrl');
      final savedConfigured = prefs.getBool('isConfigured') ?? false;

      return savedBase == _baseUrl &&
          savedApi == _apiUrl &&
          savedConfigured == _isConfigured;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateBaseUrl(String newBaseUrl) async {
    if (_esUrlValidaWeb(newBaseUrl)) {
      _baseUrl = _limpiarUrlWeb(newBaseUrl);
      _apiUrl = '$_baseUrl/api';
      _isConfigured = true;

      Logger.info('URL WEB configurada manualmente', {
        'newBaseUrl': _baseUrl,
        'newApiUrl': _apiUrl,
        'isConfigured': _isConfigured,
      });

      notifyListeners();
      await _saveToStorage();
    } else {
      Logger.warning('URL base WEB inválida', newBaseUrl);
    }
  }

  Future<void> updateApiUrl(String newApiUrl) async {
    if (_esUrlValidaWeb(newApiUrl)) {
      _apiUrl = _limpiarUrlWeb(newApiUrl);

      if (_apiUrl.endsWith('/api')) {
        _baseUrl = _apiUrl.substring(0, _apiUrl.length - 4);
      } else {
        _baseUrl = _apiUrl;
        _apiUrl = '$_baseUrl/api';
      }

      _isConfigured = true;

      Logger.info('API WEB configurada manualmente', {
        'newApiUrl': _apiUrl,
        'derivedBaseUrl': _baseUrl,
        'isConfigured': _isConfigured,
      });

      notifyListeners();
      await _saveToStorage();
    } else {
      Logger.warning('URL API WEB inválida', newApiUrl);
    }
  }

  Future<void> updateFromServerResponse(Map<String, dynamic>? config) async {
    if (config == null) return;

    Logger.debug('Respuesta del servidor WEB', config);

    _serverInfo = Map<String, dynamic>.from(config);

    final hasManualConfig =
        _isConfigured && _baseUrl.isNotEmpty && _apiUrl.isNotEmpty;

    if (hasManualConfig) {
      Logger.info('Configuración manual WEB detectada - Manteniendo URLs', {
        'baseUrlPreserved': _baseUrl,
        'apiUrlPreserved': _apiUrl,
      });

      await updateSystemInfo(config);
      return;
    }

    bool updated = false;

    if (config.containsKey('baseUrl')) {
      String serverBaseUrl = _limpiarUrlWeb(config['baseUrl'].toString());
      if (_baseUrl != serverBaseUrl) {
        _baseUrl = serverBaseUrl;
        _apiUrl = '$_baseUrl/api';
        updated = true;
      }
    }

    if (config.containsKey('apiUrl')) {
      String serverApiUrl = _limpiarUrlWeb(config['apiUrl'].toString());
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

    _updateSuggestedUrlsFromServerWeb(config);
    await updateSystemInfo(config);

    if (updated) {
      _isConfigured = false;

      Logger.info('URLs WEB actualizadas desde servidor', {
        'baseUrl': _baseUrl,
        'apiUrl': _apiUrl,
        'configuredManually': _isConfigured,
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

    if (updated) {
      Logger.debug('Info del sistema WEB actualizada', {
        'environment': _environment,
        'version': _version,
      });

      notifyListeners();
      await _saveToStorage();
    }
  }

  void _updateSuggestedUrlsFromServerWeb(Map<String, dynamic> config) {
    if (config.containsKey('urls') && config['urls'] is Map) {
      final urls = config['urls'] as Map;

      if (urls.containsKey('allLocal') && urls['allLocal'] is List) {
        final allLocalUrls = urls['allLocal'] as List;
        for (var url in allLocalUrls) {
          final cleanUrl = url
              .toString()
              .replaceAll('http://', '')
              .replaceAll('https://', '');
          if (!_suggestedUrls.contains(cleanUrl)) {
            _suggestedUrls.insert(0, cleanUrl);
          }
        }
      }
    }

    if (config.containsKey('systemInfo') && config['systemInfo'] is Map) {
      final systemInfo = config['systemInfo'] as Map;

      if (systemInfo.containsKey('allLocalIPs') &&
          systemInfo['allLocalIPs'] is List) {
        final serverIPs = systemInfo['allLocalIPs'] as List;
        for (var ip in serverIPs) {
          final ipUrl = '$ip:8000';
          if (!_suggestedUrls.contains(ipUrl)) {
            _suggestedUrls.insert(0, ipUrl);
          }
        }
      }
    }
  }

  bool _esUrlValidaWeb(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      final urlRegex = RegExp(
          r'^(https?://)?' // Protocolo opcional
          r'('
          r'localhost|' // localhost
          r'127\.0\.0\.1|' // 127.0.0.1
          r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|' // IPv4
          r'[\w\-]+\.ngrok\.io|' // ngrok viejo
          r'[\w\-]+\.ngrok-free\.app|' // ngrok nuevo
          r'[\w\-]+\.ngrok\.app|' // ngrok alternativo
          r'[\w\-]+\.loca\.lt|' // LocalTunnel
          r'[\w\-]+\.herokuapp\.com|' // Heroku
          r'[\w\-]+\.vercel\.app|' // Vercel
          r'[\w\-]+\.netlify\.app|' // Netlify
          r'[\w\-]+(\.[\w\-]+)*\.(dev|com|net|org|app|io|co|me)' // Dominios
          r')'
          r'(:\d+)?' // Puerto opcional
          r'(/.*)?', // Path opcional
          caseSensitive: false);

      return urlRegex.hasMatch(url);
    } catch (e) {
      return false;
    }
  }

  String _limpiarUrlWeb(String url) {
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
    Logger.debug('Reiniciando configuración WEB a valores por defecto');

    _setDefaultUrlsWeb();
    _serverInfo.clear();
    await _generateSuggestedUrlsWeb();
    await _saveToStorage();
    notifyListeners();
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

  bool isNgrokUrl() {
    return _baseUrl.contains('ngrok');
  }

  bool isExternalUrl() {
    return !isLocalUrl();
  }

  String getConnectionType() {
    if (isNgrokUrl()) return 'ngrok';
    if (_baseUrl.contains('loca.lt')) return 'localtunnel';
    if (_baseUrl.contains('herokuapp.com')) return 'heroku';
    if (_baseUrl.contains('vercel.app')) return 'vercel';
    if (_baseUrl.contains('netlify.app')) return 'netlify';
    if (_baseUrl.contains('github.')) return 'github';
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
      'platform': 'WEB',
      'isLocalUrl': isLocalUrl(),
      'isHttpsUrl': isHttpsUrl(),
      'isNgrokUrl': isNgrokUrl(),
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
      'isHttps': isHttpsUrl(),
    };
  }
}
