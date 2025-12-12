import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<void> saveData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<dynamic> loadData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonData = prefs.getString(key);

    if (jsonData != null) {
      return jsonDecode(jsonData);
    }

    return null;
  }

  Future<bool> hasData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  Future<void> removeData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Limpiar solo datos de monitoreos (conservar configuraciones)
  Future<void> clearMonitoreoData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) =>
            key.startsWith('monitoreos_data') ||
            key.startsWith('pending_monitoreos') ||
            key.startsWith('last_search_') ||
            key.startsWith('monitoreo_') ||
            key.startsWith('lote_info_') ||
            key.startsWith('last_online_sync'))
        .toList();

    for (String key in keys) {
      await prefs.remove(key);
    }
  }

  /// Limpiar solo cambios pendientes (útil si se corrompen)
  Future<void> clearPendingChanges() async {
    await removeData('pending_monitoreos');
  }

  /// Limpiar datos auxiliares (variedades, casas, plagas, etc.)
  Future<void> clearAuxiliaryData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) =>
            key.startsWith('variedades_data') ||
            key.startsWith('casas_data') ||
            key.startsWith('plagas_nombres') ||
            key.startsWith('niveles_limites'))
        .toList();

    for (String key in keys) {
      await prefs.remove(key);
    }
  }

  /// Obtener tamaño del caché - VERSIÓN CORREGIDA
  Future<Map<String, int>> getCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    Map<String, int> sizes = {
      'monitoreos': 0,
      'pending': 0,
      'auxiliary': 0,
      'cache_general': 0,
      'total': 0,
    };

    if (keys.isEmpty) {
      return sizes;
    }

    try {
      for (String key in keys) {
        int size = 0;

        // Obtener el valor como string primero (que es como guardamos la mayoría)
        final stringValue = prefs.getString(key);
        if (stringValue != null) {
          // Usar UTF-8 encoding para calcular bytes reales
          size = utf8.encode(stringValue).length;
        } else {
          // Para otros tipos, calcular tamaño estimado
          final intValue = prefs.getInt(key);
          final boolValue = prefs.getBool(key);
          final doubleValue = prefs.getDouble(key);
          final listValue = prefs.getStringList(key);

          if (intValue != null) {
            size = 4; // int en bytes
          } else if (boolValue != null) {
            size = 1; // bool en bytes
          } else if (doubleValue != null) {
            size = 8; // double en bytes
          } else if (listValue != null) {
            // Calcular tamaño de lista
            size = utf8.encode(listValue.join(',')).length;
          }
        }

        // Categorizar por tipo de clave
        if (key.startsWith('monitoreos_data') ||
            key.startsWith('monitoreo_') ||
            key.startsWith('lote_info_')) {
          sizes['monitoreos'] = sizes['monitoreos']! + size;
        } else if (key.startsWith('pending_monitoreos')) {
          sizes['pending'] = sizes['pending']! + size;
        } else if (key.startsWith('variedades_data') ||
            key.startsWith('casas_data') ||
            key.startsWith('plagas_nombres') ||
            key.startsWith('niveles_limites')) {
          sizes['auxiliary'] = sizes['auxiliary']! + size;
        } else {
          sizes['cache_general'] = sizes['cache_general']! + size;
        }

        sizes['total'] = sizes['total']! + size;
      }
    } catch (e) {
      print('Error al calcular tamaño de caché: $e');
    }

    return sizes;
  }

  /// Obtener estadísticas del caché de forma legible
  Future<Map<String, String>> getCacheStats() async {
    try {
      final sizes = await getCacheSize();

      return {
        'monitoreos': _formatBytes(sizes['monitoreos'] ?? 0),
        'pending': _formatBytes(sizes['pending'] ?? 0),
        'auxiliary': _formatBytes(sizes['auxiliary'] ?? 0),
        'cache_general': _formatBytes(sizes['cache_general'] ?? 0),
        'total': _formatBytes(sizes['total'] ?? 0),
      };
    } catch (e) {
      print('Error al obtener estadísticas de caché: $e');
      return {
        'monitoreos': '0 B',
        'pending': '0 B',
        'auxiliary': '0 B',
        'cache_general': '0 B',
        'total': '0 B',
      };
    }
  }

  /// Contar elementos en caché
  Future<Map<String, int>> getCacheItemCounts() async {
    Map<String, int> counts = {
      'monitoreos': 0,
      'pending_changes': 0,
      'total_keys': 0,
    };

    try {
      // Contar monitoreos
      final monitoreoData = await loadData('monitoreos_data');
      if (monitoreoData is List) {
        counts['monitoreos'] = monitoreoData.length;
      }

      // Contar cambios pendientes
      final pendingData = await loadData('pending_monitoreos');
      if (pendingData is List) {
        counts['pending_changes'] = pendingData.length;
      }

      // Contar total de claves
      final prefs = await SharedPreferences.getInstance();
      counts['total_keys'] = prefs.getKeys().length;
    } catch (e) {
      print('Error al contar elementos del caché: $e');
    }

    return counts;
  }

  /// Obtener información completa: recuento y peso
  Future<Map<String, dynamic>> getCompleteStats() async {
    final counts = await getCacheItemCounts();
    final sizes = await getCacheStats();

    return {
      'monitoreos': {
        'count': counts['monitoreos'],
        'size': sizes['monitoreos'],
      },
      'pending_changes': {
        'count': counts['pending_changes'],
        'size': sizes['pending'],
      },
      'auxiliary': {
        'count': 0, // No tenemos conteo específico para auxiliares
        'size': sizes['auxiliary'],
      },
      'cache_general': {
        'count': 0, // No tenemos conteo específico para general
        'size': sizes['cache_general'],
      },
      'total': {
        'count': counts['total_keys'],
        'size': sizes['total'],
      },
    };
  }

  /// Formatear bytes a formato legible
  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// MÉTODO DE DEBUG - Listar todas las claves
  Future<void> debugListAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList()..sort();

    print('Claves en caché (${keys.length} total):');
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final value = prefs.getString(key);
      final valueLength = value?.length ?? 0;
      print(
          '${(i + 1).toString().padLeft(3)}: $key (${_formatBytes(valueLength)})');
    }
  }

  /// MÉTODO DE DEBUG - Ver contenido de clave específica
  Future<void> debugSpecificKey(String keyToDebug) async {
    final prefs = await SharedPreferences.getInstance();

    print('Debug de clave: "$keyToDebug"');

    if (!prefs.containsKey(keyToDebug)) {
      print('La clave no existe');
      return;
    }

    final stringValue = prefs.getString(keyToDebug);
    if (stringValue != null) {
      print('Tipo: String');
      print('Longitud: ${stringValue.length} caracteres');
      print('Tamaño: ${_formatBytes(utf8.encode(stringValue).length)}');
      if (stringValue.length > 200) {
        print(
            'Contenido (primeros 200 chars): ${stringValue.substring(0, 200)}...');
      } else {
        print('Contenido: $stringValue');
      }
    }
  }
}
