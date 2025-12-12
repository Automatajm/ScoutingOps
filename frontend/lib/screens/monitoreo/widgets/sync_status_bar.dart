import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../../data/datasources/auth_service.dart';
import '../../../services/cache_service.dart';
import '../utils/constants.dart';

// Declaración de la función JavaScript para reset de emergencia
@JS('emergencyReset')
external void _callJsEmergencyReset();

class SyncStatusBar extends StatelessWidget {
  final bool isConnected;
  final int pendingChanges;
  final bool isSyncing;
  final String lastSyncStatus;
  final VoidCallback onSyncPressed;

  const SyncStatusBar({
    Key? key,
    required this.isConnected,
    required this.pendingChanges,
    required this.isSyncing,
    required this.lastSyncStatus,
    required this.onSyncPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determinar si es una pantalla pequeña
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    // Obtener información del usuario
    final authService = Provider.of<AuthService>(context);
    final String username = authService.currentUser?.username ?? 'Usuario';

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16, vertical: isSmallScreen ? 6 : 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: isSmallScreen
          ? _buildMobileLayout(context, username)
          : _buildDesktopLayout(context, username),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, String username) {
    return Row(
      children: [
        // Indicador de conexión
        Icon(
          isConnected ? Icons.wifi : Icons.wifi_off,
          color: isConnected ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),

        // Estado de conexión
        Text(
          isConnected
              ? 'Conectado a la intranet'
              : 'Sin conexión - Modo offline',
          style: TextStyle(
            color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),

        // Separador
        if (pendingChanges > 0 || lastSyncStatus.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 20,
            width: 1,
            color: Colors.grey.shade300,
          ),

        // Cambios pendientes
        if (pendingChanges > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sync_problem,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  '$pendingChanges cambios pendientes',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // Estado de sincronización
        if (lastSyncStatus.isNotEmpty && !isSyncing)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              lastSyncStatus,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),

        // Indicador de sincronización en progreso
        if (isSyncing)
          Row(
            children: [
              const SizedBox(width: 8),
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sincronizando...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

        const Spacer(),

        // Información de usuario
        Row(
          children: [
            CircleAvatar(
              backgroundColor: MonitoreoStyles.primaryColor.withOpacity(0.2),
              radius: 14,
              child: Icon(
                Icons.person,
                size: 16,
                color: MonitoreoStyles.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              username,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        // Menú de opciones de caché con debug y reset de emergencia
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
          tooltip: 'Opciones',
          onSelected: (value) => _handleMenuOption(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'cache_info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Información de caché'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'debug_negative_ids',
              child: Row(
                children: [
                  Icon(Icons.bug_report, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('🔧 DEBUG: Limpiar IDs negativos'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_pending',
              child: Row(
                children: [
                  Icon(Icons.sync_problem, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Limpiar cambios pendientes'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_monitoreos',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Limpiar datos de monitoreos'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_auxiliary',
              child: Row(
                children: [
                  Icon(Icons.cleaning_services, size: 18, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Limpiar datos auxiliares'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_all',
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Limpiar todo el caché'),
                ],
              ),
            ),
            // ═══════════════════════════════════════════════════════════════
            // NUEVO: Reset de Emergencia
            // ═══════════════════════════════════════════════════════════════
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'emergency_reset',
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('🚨 Reset de Emergencia',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(width: 8),

        // Botón de sincronización
        if (isConnected && pendingChanges > 0 && !isSyncing)
          ElevatedButton.icon(
            onPressed: onSyncPressed,
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sincronizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MonitoreoStyles.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),

        // Botón de cerrar sesión
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout, size: 16),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, String username) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primera fila con conexión e información de usuario
        Row(
          children: [
            // Indicador de conexión
            Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),

            // Estado de conexión (versión compacta)
            Text(
              isConnected ? 'Conectado' : 'Sin conexión',
              style: TextStyle(
                color:
                    isConnected ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),

            const Spacer(),

            // Menú de opciones de caché (móvil) con reset de emergencia
            PopupMenuButton<String>(
              icon:
                  Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
              tooltip: 'Opciones',
              onSelected: (value) => _handleMenuOption(context, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'cache_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Info caché', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'debug_negative_ids',
                  child: Row(
                    children: [
                      Icon(Icons.bug_report, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('🔧 Debug IDs', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_pending',
                  child: Row(
                    children: [
                      Icon(Icons.sync_problem, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Limpiar pendientes',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_monitoreos',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Limpiar monitoreos',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Limpiar todo', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                // ═══════════════════════════════════════════════════════════
                // NUEVO: Reset de Emergencia (móvil)
                // ═══════════════════════════════════════════════════════════
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'emergency_reset',
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('🚨 Reset',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            // Información de usuario (compacta)
            Text(
              username,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),

            // Botón de cerrar sesión pequeño
            IconButton(
              onPressed: () => _logout(context),
              icon: Icon(Icons.logout, size: 18, color: Colors.red.shade700),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              tooltip: 'Cerrar sesión',
            ),
          ],
        ),

        // Segunda fila con información de sincronización (solo si es necesario)
        if (pendingChanges > 0 || isSyncing || lastSyncStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                // Cambios pendientes
                if (pendingChanges > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync_problem,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pendingChanges pendientes',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Indicador de sincronización en progreso
                if (isSyncing)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sincronizando...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Estado de sincronización (compacto)
                if (lastSyncStatus.isNotEmpty && !isSyncing)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        lastSyncStatus,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                const Spacer(),

                // Botón de sincronización compacto
                if (isConnected && pendingChanges > 0 && !isSyncing)
                  ElevatedButton.icon(
                    onPressed: onSyncPressed,
                    icon: const Icon(Icons.sync, size: 12),
                    label: const Text('Sincronizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MonitoreoStyles.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                      minimumSize: const Size(32, 28),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Manejar opciones del menú de caché
  void _handleMenuOption(BuildContext context, String option) {
    switch (option) {
      case 'cache_info':
        _showCacheInfoDialog(context);
        break;
      case 'debug_negative_ids':
        _debugCleanNegativeIds(context);
        break;
      case 'clear_pending':
        _showClearCacheDialog(context, 'pending');
        break;
      case 'clear_monitoreos':
        _showClearCacheDialog(context, 'monitoreos');
        break;
      case 'clear_auxiliary':
        _showClearCacheDialog(context, 'auxiliary');
        break;
      case 'clear_all':
        _showClearCacheDialog(context, 'all');
        break;
      // ═══════════════════════════════════════════════════════════════════════
      // NUEVO: Case para Reset de Emergencia
      // ═══════════════════════════════════════════════════════════════════════
      case 'emergency_reset':
        _emergencyReset(context);
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NUEVO: Reset de Emergencia - Limpia Service Worker, IndexedDB, Cache
  // ═══════════════════════════════════════════════════════════════════════════
  void _emergencyReset(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Reset de Emergencia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de ejecutar un reset completo?',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Esta acción:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Limpiará el Service Worker'),
                  Text('• Eliminará todos los datos locales (SQLite)'),
                  Text('• Borrará catálogos sincronizados'),
                  Text('• Recargará la aplicación completamente'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '⚠️ Los monitoreos NO sincronizados se PERDERÁN.',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeEmergencyReset(context);
            },
            child: const Text('Sí, Resetear'),
          ),
        ],
      ),
    );
  }

  void _executeEmergencyReset(BuildContext context) {
    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Limpiando todos los datos...',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'La aplicación se recargará automáticamente',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );

    // Ejecutar el reset via JavaScript
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        _callJsEmergencyReset();
      } catch (e) {
        debugPrint('Error en emergency reset: $e');
        // Fallback: recargar la página
        web.window.location.reload();
      }
    });
  }

  // Método para debug y limpieza específica de IDs negativos
  void _debugCleanNegativeIds(BuildContext context) async {
    final cacheService = Provider.of<CacheService>(context, listen: false);

    try {
      // Leer datos actuales
      final monitoreoData =
          await cacheService.loadData('monitoreos_data') ?? [];
      final pendingData =
          await cacheService.loadData('pending_monitoreos') ?? [];

      print('🔧 ANTES DE LIMPIAR:');
      print('   - monitoreos_data: ${monitoreoData.length}');
      print('   - pending_monitoreos: ${pendingData.length}');

      int removedFromMonitoreos = 0;
      int removedFromPending = 0;

      // Filtrar IDs negativos de monitoreos_data
      if (monitoreoData is List) {
        final filtered = monitoreoData.where((item) {
          if (item is Map && item['pmmo_secuencia'] != null) {
            final id = item['pmmo_secuencia'];
            final isNegative = id is int && id < 0;
            if (isNegative) {
              print('   🗑️ Eliminando de monitoreos_data: ID $id');
              removedFromMonitoreos++;
              return false;
            }
            return true;
          }
          return true;
        }).toList();

        await cacheService.saveData('monitoreos_data', filtered);
        print(
            '   - Eliminados $removedFromMonitoreos registros con ID negativo de monitoreos_data');
      }

      // Filtrar IDs negativos de pending_monitoreos
      if (pendingData is List) {
        final filtered = pendingData.where((change) {
          if (change is Map &&
              change['monitoreo'] != null &&
              change['monitoreo']['pmmo_secuencia'] != null) {
            final id = change['monitoreo']['pmmo_secuencia'];
            final isNegative = id is int && id < 0;
            if (isNegative) {
              print(
                  '   🗑️ Eliminando de pending_monitoreos: ID $id, operación: ${change['operation']}');
              removedFromPending++;
              return false;
            }
            return true;
          }
          return true;
        }).toList();

        await cacheService.saveData('pending_monitoreos', filtered);
        print(
            '   - Eliminados $removedFromPending cambios pendientes con ID negativo');
      }

      print('🔧 DESPUÉS DE LIMPIAR:');
      print(
          '   - Total eliminados: ${removedFromMonitoreos + removedFromPending}');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'DEBUG: Limpieza completada - ${removedFromMonitoreos + removedFromPending} registros con ID negativo eliminados'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Forzar recarga de la página después de la limpieza
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/monitoreo');
        }
      });
    } catch (e) {
      print('ERROR en limpieza debug: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ERROR en limpieza debug: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Mostrar información del caché
  void _showCacheInfoDialog(BuildContext context) async {
    final cacheService = Provider.of<CacheService>(context, listen: false);

    try {
      final stats = await cacheService.getCacheStats();
      final counts = await cacheService.getCacheItemCounts();

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Información del caché'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estadísticas del caché:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildCacheInfoRow('Monitoreos:',
                  '${counts['monitoreos'] ?? 0} registros (${stats['monitoreos'] ?? '0 B'})'),
              _buildCacheInfoRow('Cambios pendientes:',
                  '${counts['pending_changes'] ?? 0} operaciones (${stats['pending'] ?? '0 B'})'),
              _buildCacheInfoRow(
                  'Datos auxiliares:', '${stats['auxiliary'] ?? '0 B'}'),
              _buildCacheInfoRow(
                  'Otros datos:', '${stats['cache_general'] ?? '0 B'}'),
              const Divider(),
              _buildCacheInfoRow('Total:',
                  '${counts['total_keys'] ?? 0} elementos (${stats['total'] ?? '0 B'})'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener información del caché: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCacheInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Mostrar diálogo de confirmación para limpiar caché
  void _showClearCacheDialog(BuildContext context, String type) async {
    final cacheService = Provider.of<CacheService>(context, listen: false);

    String title;
    String message;
    String warningMessage;
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'pending':
        title = 'Limpiar cambios pendientes';
        message =
            '¿Desea eliminar todos los cambios pendientes de sincronización?';
        warningMessage =
            'ADVERTENCIA: Esto eliminará permanentemente los cambios no sincronizados.';
        icon = Icons.sync_problem;
        iconColor = Colors.orange;
        break;
      case 'monitoreos':
        title = 'Limpiar datos de monitoreos';
        message =
            '¿Desea eliminar todos los datos de monitoreos almacenados localmente?';
        warningMessage =
            'ADVERTENCIA: Necesitará conexión para recargar los datos.';
        icon = Icons.delete_sweep;
        iconColor = Colors.blue;
        break;
      case 'auxiliary':
        title = 'Limpiar datos auxiliares';
        message =
            '¿Desea eliminar los datos auxiliares (variedades, casas, plagas)?';
        warningMessage =
            'ADVERTENCIA: Estos datos se recargarán automáticamente al usar la aplicación.';
        icon = Icons.cleaning_services;
        iconColor = Colors.purple;
        break;
      case 'all':
      default:
        title = 'Limpiar todo el caché';
        message =
            '¿Desea eliminar completamente todos los datos almacenados localmente?';
        warningMessage =
            'ADVERTENCIA: Esto eliminará TODOS los datos locales y cambios no sincronizados.';
        icon = Icons.clear_all;
        iconColor = Colors.red;
        break;
    }

    // Obtener estadísticas antes de mostrar el diálogo
    Map<String, int> counts = {};
    try {
      counts = await cacheService.getCacheItemCounts();
    } catch (e) {
      print('Error al obtener estadísticas: $e');
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                warningMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
            if (type == 'pending' && counts['pending_changes'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Se eliminarán ${counts['pending_changes']} cambios pendientes.',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeCacheClear(context, type);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  // Ejecutar la limpieza del caché
  Future<void> _executeCacheClear(BuildContext context, String type) async {
    final cacheService = Provider.of<CacheService>(context, listen: false);

    try {
      String successMessage;

      switch (type) {
        case 'pending':
          await cacheService.clearPendingChanges();
          successMessage = 'Cambios pendientes eliminados correctamente';
          break;
        case 'monitoreos':
          await cacheService.clearMonitoreoData();
          successMessage = 'Datos de monitoreos eliminados correctamente';
          break;
        case 'auxiliary':
          await cacheService.clearAuxiliaryData();
          successMessage = 'Datos auxiliares eliminados correctamente';
          break;
        case 'all':
        default:
          await cacheService.clearAllData();
          successMessage = 'Todo el caché eliminado correctamente';
          break;
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(successMessage)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al limpiar caché: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Método para mostrar diálogo de cierre de sesión
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              authService.logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
