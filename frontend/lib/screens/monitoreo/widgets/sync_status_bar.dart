import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/auth_service.dart';
import '../utils/constants.dart';

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
    final isSmallScreen = screenWidth < 600;

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
              // Cerrar el diálogo
              Navigator.pop(context);

              // Obtener referencia al AuthService
              final authService =
                  Provider.of<AuthService>(context, listen: false);

              // Ejecutar logout en el service
              authService.logout();

              // Navegar a la pantalla de login
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false, // Eliminar todas las rutas anteriores
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
