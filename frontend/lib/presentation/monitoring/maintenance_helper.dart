import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/offline_database_service.dart';
import '../../services/cache_service.dart';
import '../../data/datasources/auth_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Helper para funciones de mantenimiento y limpieza de la aplicación
/// Versión simplificada - solo funciones básicas que funcionan con certeza
class MaintenanceHelper {
  final BuildContext context;
  final VoidCallback? onSuccess;

  MaintenanceHelper(this.context, {this.onSuccess});

  /// Muestra mensaje de feedback al usuario
  void _showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 🗑️ OPCIÓN 1: Limpiar registros locales (SQLite)
  /// Borra todos los monitoreos guardados localmente usando JavaScript en web
  Future<void> limpiarRegistrosLocales() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.delete_sweep, color: Colors.red, size: 56),
        title: Text(
          'Limpiar registros locales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esto eliminará TODOS los monitoreos guardados en IndexedDB.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los datos se descargarán nuevamente del servidor',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      debugPrint('🗑️ Limpiando registros locales (web - IndexedDB)...');
      
      // En web, usar JavaScript para borrar IndexedDB específica
      // Esto borra solo las bases de datos de sqflite
      final jsCode = '''
        (async function() {
          try {
            let count = 0;
            
            // Obtener todas las bases de datos
            if (indexedDB.databases) {
              const dbs = await indexedDB.databases();
              console.log('🔍 Bases de datos encontradas:', dbs.length);
              
              // Borrar solo las bases de datos de sqflite/drift
              for (const db of dbs) {
                if (db.name && (db.name.includes('sqflite') || db.name.includes('drift') || db.name.includes('pestcontrol'))) {
                  console.log('🗑️ Borrando DB:', db.name);
                  indexedDB.deleteDatabase(db.name);
                  count++;
                }
              }
            } else {
              // Fallback: intentar borrar bases de datos conocidas
              console.log('⚠️ indexedDB.databases() no disponible, usando fallback...');
              const knownDbs = ['sqflite', 'drift.db', 'pestcontrol.db', 'pestcontrol'];
              for (const dbName of knownDbs) {
                try {
                  indexedDB.deleteDatabase(dbName);
                  count++;
                  console.log('🗑️ Intento de borrar:', dbName);
                } catch (e) {
                  console.log('⚠️ No se pudo borrar:', dbName);
                }
              }
            }
            
            console.log('✅ Total de DBs eliminadas:', count);
            return count;
          } catch (error) {
            console.error('❌ Error limpiando registros:', error);
            return 0;
          }
        })();
      ''';
      
      // Ejecutar código JavaScript
      final result = js.context.callMethod('eval', [jsCode]);
      
      debugPrint('✅ Registros locales eliminados');
      
      _showMessage('✅ Registros locales eliminados');
      
      // Esperar un momento y recargar datos
      await Future.delayed(Duration(milliseconds: 500));
      
      // Llamar callback para recargar datos
      onSuccess?.call();
      
    } catch (e) {
      debugPrint('❌ Error limpiando registros: $e');
      _showMessage('❌ Error: ${e.toString()}');
    }
  }

  /// 🗄️ OPCIÓN 2: Borrar base de datos SQLite completa
  /// Usa el mismo método que emergencyReset para máxima compatibilidad
  Future<void> borrarBaseDatos() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 56),
        title: Text(
          '⚠️ BORRAR BASE DE DATOS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESTA ACCIÓN ES IRREVERSIBLE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Se eliminará:\n• IndexedDB completo\n• localStorage y sessionStorage\n• Service Workers y Caches',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La página se recargará automáticamente',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('BORRAR TODO'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      debugPrint('💀 Borrando base de datos (usando emergencyReset)...');
      
      // Usar la misma función emergencyReset de JavaScript
      if (js.context.hasProperty('emergencyReset')) {
        js.context.callMethod('emergencyReset');
        debugPrint('✅ window.emergencyReset() ejecutado');
      } else {
        // Fallback manual
        debugPrint('⚠️ emergencyReset no encontrado, usando fallback...');
        
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'pestcontrol.db');
        await deleteDatabase(path);
        
        debugPrint('✅ Base de datos eliminada (fallback)');
        _showMessage('✅ Base de datos eliminada - Recargando...');
        
        await Future.delayed(Duration(milliseconds: 500));
        html.window.location.reload();
      }
      
    } catch (e) {
      debugPrint('❌ Error borrando base de datos: $e');
      _showMessage('❌ Error: ${e.toString()}');
    }
  }

  /// 🔄 OPCIÓN 3: Hard Refresh (COMBO)
  /// Limpia TODO: Service Workers, Caches, IndexedDB, Storage + Recarga automática
  Future<void> hardRefresh() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.refresh, color: Colors.purple, size: 56),
        title: Text(
          '🔄 Hard Refresh',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esto hará una limpieza completa:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              '✓ Service Workers\n✓ Caches del navegador\n✓ IndexedDB completo\n✓ localStorage y sessionStorage\n✓ Recarga automática',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Soluciona registros bloqueados y problemas de sincronización',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: Text('Ejecutar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      debugPrint('🔄 Iniciando Hard Refresh (usando emergencyReset de JavaScript)...');
      
      // Mostrar indicador de progreso
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Limpiando aplicación completa...'),
              ],
            ),
          ),
        ),
      );

      // Llamar a la función emergencyReset de JavaScript que ya existe en index.html
      // Esta función hace TODO: Service Workers, Caches, IndexedDB, Storage, y recarga
      debugPrint('🎯 Llamando a window.emergencyReset()...');
      
      // Usar dart:js para llamar a la función JavaScript
      if (js.context.hasProperty('emergencyReset')) {
        js.context.callMethod('emergencyReset');
        debugPrint('✅ window.emergencyReset() ejecutado');
      } else {
        // Fallback: hacer limpieza manual y recargar
        debugPrint('⚠️ window.emergencyReset() no encontrado, usando fallback...');
        
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'pestcontrol.db');
        await deleteDatabase(path);
        
        debugPrint('✅ Base de datos eliminada (fallback)');
        
        // Cerrar diálogo
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        _showMessage('✅ Limpieza completada - Recargando...');
        await Future.delayed(Duration(milliseconds: 500));
        html.window.location.reload();
      }
      
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      debugPrint('❌ Error en hard refresh: $e');
      _showMessage('❌ Error: ${e.toString()}');
    }
  }
}