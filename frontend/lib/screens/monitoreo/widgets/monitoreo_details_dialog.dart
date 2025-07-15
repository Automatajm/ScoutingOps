import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/monitoreo_model.dart';
import '../utils/constants.dart';
import 'data_cells.dart';

class MonitoreoDetailsDialog {
  static Future<void> showMonitoreoDetails(
      BuildContext context, Monitoreo monitoreo, Function() onEdit) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de monitoreo - #${monitoreo.pmmo_secuencia}'),
        content: Container(
          width: isSmallScreen ? screenWidth * 0.9 : screenWidth * 0.7,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: isSmallScreen ? double.infinity : 800,
          ),
          child: SingleChildScrollView(
            child: isSmallScreen
                ? _buildMobileDetailsContent(monitoreo)
                : _buildDesktopDetailsContent(monitoreo),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              foregroundColor: const Color.fromARGB(255, 71, 71, 71),
            ),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  // Build mobile-friendly content
  static Widget _buildMobileDetailsContent(Monitoreo monitoreo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lote Information
        _ResponsiveCard(
          title: 'Información del lote',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Código de lote:', monitoreo.pmlt_codigo ?? 'N/A'),
              _buildDetailRow('Casa:', monitoreo.pmmo_casa ?? 'N/A'),
              _buildDetailRow('Cantero:', monitoreo.pmmo_cantero ?? 'N/A'),
              _buildDetailRow(
                  'Canteros (Original):', monitoreo.pmmo_canteros ?? 'N/A'),
              _buildDetailRow(
                  'Variedad:',
                  monitoreo.pmmo_variedad ??
                      monitoreo.pmva_descripcion ??
                      'N/A'),
              _buildDetailRow(
                  'ID Variedad:', monitoreo.pmmo_idvariedad ?? 'N/A'),
              _buildDetailRow(
                  'Cultivador/Responsable:', monitoreo.pmmo_grower ?? 'N/A'),
              _buildDetailRow(
                  'Contenedor:', monitoreo.pmmo_contenedor ?? 'N/A'),
            ],
          ),
        ),

        // Monitoreo Information
        _ResponsiveCard(
          title: 'Datos del monitoreo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Fecha:',
                  monitoreo.pmmo_fecha != null
                      ? DateFormat('dd/MM/yyyy').format(monitoreo.pmmo_fecha!)
                      : 'N/A'),
              _buildDetailRow('Plaga:', monitoreo.pmni_nombrecomun ?? 'N/A'),
              _buildDetailRow('Cantidad observada:',
                  monitoreo.pmmo_cantidad?.toString() ?? '0'),
              _buildDetailRow('Cantidad eliminada:',
                  monitoreo.pmmo_cant_botada?.toString() ?? '0'),
              _buildDetailRow(
                  'Comentarios:', monitoreo.pmmo_comentarios ?? 'N/A'),
            ],
          ),
        ),

        // Samples and Levels
        _ResponsiveCard(
          title: 'Muestras y niveles',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Muestra 1:', monitoreo.pmmo_muestra1?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel automático 1:',
                  monitoreo.pmmo_nivmuestraa1?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel manual 1:',
                  monitoreo.pmmo_nivmuestram1?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Muestra 2:', monitoreo.pmmo_muestra2?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel automático 2:',
                  monitoreo.pmmo_nivmuestraa2?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel manual 2:',
                  monitoreo.pmmo_nivmuestram2?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Muestra 3:', monitoreo.pmmo_muestra3?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel automático 3:',
                  monitoreo.pmmo_nivmuestraa3?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel manual 3:',
                  monitoreo.pmmo_nivmuestram3?.toString() ?? 'N/A'),
              const SizedBox(height: 8),
              const Text(
                'Información de límites:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildDetailRow(
                  'Límite nivel 1:', monitoreo.lmsupniv1?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Límite nivel 2:', monitoreo.lmsupniv2?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Límite nivel 3:', monitoreo.lmsupniv3?.toString() ?? 'N/A'),
            ],
          ),
        ),

        // Additional Information
        _ResponsiveCard(
          title: 'Información adicional',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Estado:',
                  monitoreo.pmmo_estatus == 1 ? 'Activo' : 'Inactivo'),
              _buildDetailRow('Modo de entrada:',
                  monitoreo.pmmo_automatico == true ? 'Automático' : 'Manual'),
              _buildDetailRow(
                  'Fecha de creación:',
                  monitoreo.pmmo_fechacreacion != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(monitoreo.pmmo_fechacreacion!)
                      : 'N/A'),
              _buildDetailRow(
                  'Última modificación:',
                  monitoreo.pmmo_fechamodificacion != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(monitoreo.pmmo_fechamodificacion!)
                      : 'N/A'),
              _buildDetailRow(
                  'Creado por:', monitoreo.pmmo_creadopor?.toString() ?? 'N/A'),
              _buildDetailRow('Modificado por:',
                  monitoreo.pmmo_modificadopor?.toString() ?? 'N/A'),
            ],
          ),
        ),
      ],
    );
  }

  // Build desktop-friendly content (original implementation)
  static Widget _buildDesktopDetailsContent(Monitoreo monitoreo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lote Information Card
        _ResponsiveCard(
          title: 'Información del lote',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Código de lote:', monitoreo.pmlt_codigo ?? 'N/A'),
              _buildDetailRow('Casa:', monitoreo.pmmo_casa ?? 'N/A'),
              _buildDetailRow('Cantero:', monitoreo.pmmo_cantero ?? 'N/A'),
              _buildDetailRow(
                  'Canteros (Original):', monitoreo.pmmo_canteros ?? 'N/A'),
              _buildDetailRow(
                  'Variedad:',
                  monitoreo.pmmo_variedad ??
                      monitoreo.pmva_descripcion ??
                      'N/A'),
              _buildDetailRow(
                  'ID Variedad:', monitoreo.pmmo_idvariedad ?? 'N/A'),
              _buildDetailRow(
                  'Cultivador/Responsable:', monitoreo.pmmo_grower ?? 'N/A'),
              _buildDetailRow(
                  'Contenedor:', monitoreo.pmmo_contenedor ?? 'N/A'),
            ],
          ),
        ),

        // Monitoreo Information Card
        _ResponsiveCard(
          title: 'Datos del monitoreo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Fecha:',
                  monitoreo.pmmo_fecha != null
                      ? DateFormat('dd/MM/yyyy').format(monitoreo.pmmo_fecha!)
                      : 'N/A'),
              _buildDetailRow('Plaga:', monitoreo.pmni_nombrecomun ?? 'N/A'),
              _buildDetailRow('Cantidad observada:',
                  monitoreo.pmmo_cantidad?.toString() ?? '0'),
              _buildDetailRow('Cantidad eliminada:',
                  monitoreo.pmmo_cant_botada?.toString() ?? '0'),
              _buildDetailRow(
                  'Comentarios:', monitoreo.pmmo_comentarios ?? 'N/A'),
            ],
          ),
        ),

        // Samples and Levels Card
        _ResponsiveCard(
          title: 'Muestras y niveles',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Muestra 1:', monitoreo.pmmo_muestra1?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel automático 1:',
                  monitoreo.pmmo_nivmuestraa1?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel manual 1:',
                  monitoreo.pmmo_nivmuestram1?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Muestra 2:', monitoreo.pmmo_muestra2?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel automático 2:',
                  monitoreo.pmmo_nivmuestraa2?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel manual 2:',
                  monitoreo.pmmo_nivmuestram2?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Muestra 3:', monitoreo.pmmo_muestra3?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel automático 3:',
                  monitoreo.pmmo_nivmuestraa3?.toString() ?? 'N/A'),
              _buildDetailRow('Nivel manual 3:',
                  monitoreo.pmmo_nivmuestram3?.toString() ?? 'N/A'),
              const SizedBox(height: 8),
              const Text(
                'Información de límites:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildDetailRow(
                  'Límite nivel 1:', monitoreo.lmsupniv1?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Límite nivel 2:', monitoreo.lmsupniv2?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Límite nivel 3:', monitoreo.lmsupniv3?.toString() ?? 'N/A'),
            ],
          ),
        ),

        // Additional Information Card
        _ResponsiveCard(
          title: 'Información adicional',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Estado:',
                  monitoreo.pmmo_estatus == 1 ? 'Activo' : 'Inactivo'),
              _buildDetailRow('Modo de entrada:',
                  monitoreo.pmmo_automatico == true ? 'Automático' : 'Manual'),
              _buildDetailRow(
                  'Fecha de creación:',
                  monitoreo.pmmo_fechacreacion != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(monitoreo.pmmo_fechacreacion!)
                      : 'N/A'),
              _buildDetailRow(
                  'Última modificación:',
                  monitoreo.pmmo_fechamodificacion != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(monitoreo.pmmo_fechamodificacion!)
                      : 'N/A'),
              _buildDetailRow(
                  'Creado por:', monitoreo.pmmo_creadopor?.toString() ?? 'N/A'),
              _buildDetailRow('Modificado por:',
                  monitoreo.pmmo_modificadopor?.toString() ?? 'N/A'),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build detail rows for mobile view
  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// Custom responsive card widget for mobile view
class _ResponsiveCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ResponsiveCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MonitoreoStyles.primaryColor,
              ),
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
