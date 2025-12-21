// 📁 UBICACIÓN: lib/presentation/widgets/import_preview_dialog.dart
// ⚡ ARCHIVO NUEVO - Crear este archivo

import 'package:flutter/material.dart';
import '../../models/import_analysis_model.dart';
import '../../models/lote_model.dart';

class ImportPreviewDialog extends StatefulWidget {
  final ImportAnalysis analysis;
  final Function(List<LoteToCreate>, List<LoteToUpdate>) onConfirm;

  const ImportPreviewDialog({
    Key? key,
    required this.analysis,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Control de selección
  Set<int> _lotesNuevosSeleccionados = {};
  Set<int> _lotesActualizarSeleccionados = {};

  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color successColor = const Color(0xFF219653);
  final Color warningColor = const Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Por defecto, seleccionar todos
    _lotesNuevosSeleccionados = Set.from(
        List.generate(widget.analysis.lotesNuevos.length, (index) => index));
    _lotesActualizarSeleccionados = Set.from(List.generate(
        widget.analysis.lotesActualizar.length, (index) => index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            _buildHeader(),
            _buildEstadisticas(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLotesNuevosTab(),
                  _buildLotesActualizarTab(),
                  _buildLotesSinCambiosTab(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.upload_file,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista Previa de Importación',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Revisa los cambios antes de importar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildEstadistica(
              'Nuevos',
              widget.analysis.totalNuevos,
              successColor,
              Icons.add_circle_outline,
            ),
          ),
          Expanded(
            child: _buildEstadistica(
              'Actualizar',
              widget.analysis.totalActualizar,
              warningColor,
              Icons.update,
            ),
          ),
          Expanded(
            child: _buildEstadistica(
              'Sin Cambios',
              widget.analysis.totalSinCambios,
              Colors.grey.shade600,
              Icons.check_circle_outline,
            ),
          ),
          Expanded(
            child: _buildEstadistica(
              'Total',
              widget.analysis.totalLotes,
              primaryColor,
              Icons.list_alt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadistica(
      String label, int valor, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            valor.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 18),
                const SizedBox(width: 8),
                Text('Nuevos (${widget.analysis.totalNuevos})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.update, size: 18),
                const SizedBox(width: 8),
                Text('Actualizar (${widget.analysis.totalActualizar})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 8),
                Text('Sin Cambios (${widget.analysis.totalSinCambios})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotesNuevosTab() {
    if (widget.analysis.lotesNuevos.isEmpty) {
      return _buildEmptyState('No hay lotes nuevos para crear');
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: successColor.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _lotesNuevosSeleccionados.length ==
                    widget.analysis.lotesNuevos.length,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _lotesNuevosSeleccionados = Set.from(List.generate(
                          widget.analysis.lotesNuevos.length,
                          (index) => index));
                    } else {
                      _lotesNuevosSeleccionados.clear();
                    }
                  });
                },
              ),
              Text(
                'Seleccionar todos (${_lotesNuevosSeleccionados.length} de ${widget.analysis.lotesNuevos.length})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.analysis.lotesNuevos.length,
            itemBuilder: (context, index) {
              final loteNuevo = widget.analysis.lotesNuevos[index];
              final seleccionado = _lotesNuevosSeleccionados.contains(index);

              return _buildLoteNuevoCard(loteNuevo.lote, index, seleccionado);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLotesActualizarTab() {
    if (widget.analysis.lotesActualizar.isEmpty) {
      return _buildEmptyState('No hay lotes para actualizar');
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: warningColor.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _lotesActualizarSeleccionados.length ==
                    widget.analysis.lotesActualizar.length,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _lotesActualizarSeleccionados = Set.from(List.generate(
                          widget.analysis.lotesActualizar.length,
                          (index) => index));
                    } else {
                      _lotesActualizarSeleccionados.clear();
                    }
                  });
                },
              ),
              Text(
                'Seleccionar todos (${_lotesActualizarSeleccionados.length} de ${widget.analysis.lotesActualizar.length})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.analysis.lotesActualizar.length,
            itemBuilder: (context, index) {
              final loteUpdate = widget.analysis.lotesActualizar[index];
              final seleccionado =
                  _lotesActualizarSeleccionados.contains(index);

              return _buildLoteActualizarCard(loteUpdate, index, seleccionado);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLotesSinCambiosTab() {
    if (widget.analysis.lotesSinCambios.isEmpty) {
      return _buildEmptyState('Todos los lotes tienen cambios');
    }

    return ListView.builder(
      itemCount: widget.analysis.lotesSinCambios.length,
      itemBuilder: (context, index) {
        final lote = widget.analysis.lotesSinCambios[index];
        return _buildLoteSinCambiosCard(lote);
      },
    );
  }

  Widget _buildLoteNuevoCard(Lote lote, int index, bool seleccionado) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seleccionado ? successColor : Colors.grey.shade300,
          width: seleccionado ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: successColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: seleccionado,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _lotesNuevosSeleccionados.add(index);
                      } else {
                        _lotesNuevosSeleccionados.remove(index);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                Icon(Icons.add_circle_outline, color: successColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lote.pmlt_codigo ?? '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NUEVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildDetailRow('Canteros', lote.pmlt_canteros ?? '-'),
                _buildDetailRow(
                    'Cantidad', lote.pmlt_cantidad?.toString() ?? '0'),
                _buildDetailRow('Variedad', lote.pmlt_variedad ?? '-'),
                _buildDetailRow('Contenedor', lote.pmlt_contenedor ?? '-'),
                _buildDetailRow('Casa', lote.pmlt_casa ?? '-'),
                _buildDetailRow('Grower', lote.pmlt_grower ?? '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoteActualizarCard(
      LoteToUpdate loteUpdate, int index, bool seleccionado) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seleccionado ? warningColor : Colors.grey.shade300,
          width: seleccionado ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: warningColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: seleccionado,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _lotesActualizarSeleccionados.add(index);
                      } else {
                        _lotesActualizarSeleccionados.remove(index);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                Icon(Icons.update, color: warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loteUpdate.loteExistente.pmlt_codigo ?? '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: warningColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${loteUpdate.cambios.length} CAMBIO${loteUpdate.cambios.length > 1 ? "S" : ""}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: loteUpdate.cambios.map((cambio) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: warningColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: warningColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_forward, color: warningColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cambio.fieldLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cambio.oldValue ?? '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_forward, size: 14),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cambio.newValue ?? '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoteSinCambiosCard(Lote lote) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lote.pmlt_codigo ?? '-',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            'Sin cambios',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final totalSeleccionados =
        _lotesNuevosSeleccionados.length + _lotesActualizarSeleccionados.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalSeleccionados elemento${totalSeleccionados != 1 ? "s" : ""} seleccionado${totalSeleccionados != 1 ? "s" : ""}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_lotesNuevosSeleccionados.length} nuevo${_lotesNuevosSeleccionados.length != 1 ? "s" : ""} • ${_lotesActualizarSeleccionados.length} actualización${_lotesActualizarSeleccionados.length != 1 ? "es" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: totalSeleccionados > 0
                ? () {
                    final lotesCrear = _lotesNuevosSeleccionados
                        .map((index) => widget.analysis.lotesNuevos[index])
                        .toList();

                    final lotesActualizar = _lotesActualizarSeleccionados
                        .map((index) => widget.analysis.lotesActualizar[index])
                        .toList();

                    Navigator.pop(context);
                    widget.onConfirm(lotesCrear, lotesActualizar);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.upload, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Importar Seleccionados ($totalSeleccionados)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
