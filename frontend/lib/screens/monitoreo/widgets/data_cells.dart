import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DataCells {
  // Construir widget para celda de tabla
  static Widget buildDataCell(String text, double width,
      {bool isUserMonitoreo = false,
      bool isAlternateRow = false,
      bool isNumeric = false}) {
    final bgColor = isAlternateRow ? const Color(0xFFF9F9F9) : Colors.white;
    final highlightColor =
        isUserMonitoreo ? Colors.amber.withOpacity(0.05) : Colors.transparent;

    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(highlightColor, bgColor),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Align(
        alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 13,
            fontWeight: isUserMonitoreo ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Widget para encabezado de tabla con ordenamiento y redimensionamiento
  static Widget buildTableHeader({
    required List<Map<String, dynamic>> columns,
    required String? sortColumn,
    required bool sortAscending,
    required Function(String, bool) onSort,
    required Map<String, double> columnWidths,
    required Function(String, double) onColumnResize,
  }) {
    return Container(
      color: const Color(0xFFF9F9F9),
      child: Row(
        children: [
          // Columna de acciones fija
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Text(
              'Acciones',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          // Encabezados de columnas
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: columns.map((column) {
                  final title = column['title'] as String;
                  final isNumeric = column['isNumeric'] as bool? ?? false;
                  final isCurrentSortColumn = sortColumn == title;
                  final width =
                      columnWidths[title] ?? (column['width'] as double);

                  return _buildResizableHeaderColumn(
                    title: title,
                    width: width,
                    isNumeric: isNumeric,
                    isSorted: isCurrentSortColumn,
                    isAscending: isCurrentSortColumn ? sortAscending : true,
                    onSort: () => onSort(
                        title, isCurrentSortColumn ? !sortAscending : true),
                    onResize: (newWidth) => onColumnResize(title, newWidth),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para columna de encabezado redimensionable
  static Widget _buildResizableHeaderColumn({
    required String title,
    required double width,
    required bool isNumeric,
    required bool isSorted,
    required bool isAscending,
    required VoidCallback onSort,
    required Function(double) onResize,
  }) {
    return _ResizableHeaderColumn(
      title: title,
      width: width,
      isNumeric: isNumeric,
      isSorted: isSorted,
      isAscending: isAscending,
      onSort: onSort,
      onResize: onResize,
    );
  }

  // Construir elemento de detalle para el diálogo
  static Widget buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF505050),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para celda de estado
  static Widget buildStatusCell(
      String value, double width, bool isUserMonitoreo, bool isAlternateRow) {
    final bgColor = isAlternateRow ? const Color(0xFFF9F9F9) : Colors.white;
    final highlightColor =
        isUserMonitoreo ? Colors.amber.withOpacity(0.05) : Colors.transparent;

    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(highlightColor, bgColor),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: value == 'Activo'
                ? const Color(0xFFE7F5E7)
                : const Color(0xFFFCE8E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: value == 'Activo'
                  ? const Color(0xFF219653)
                  : const Color(0xFFE53935),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Widget para celda de nivel
  static Widget buildNivelCell(
      String value, double width, bool isUserMonitoreo, bool isAlternateRow) {
    // Determinar color según el nivel
    Color nivelColor = Colors.grey.shade100; // Default
    final bgColor = isAlternateRow ? const Color(0xFFF9F9F9) : Colors.white;

    if (value != '-') {
      int nivel = int.tryParse(value) ?? 0;
      // Colores según el nivel
      if (nivel == 1) {
        nivelColor = const Color(0xFFDEF0DE); // Verde
      } else if (nivel == 2) {
        nivelColor = const Color(0xFFF9EFD6); // Naranja suave
      } else if (nivel == 3) {
        nivelColor = const Color(0xFFF5D6D6); // Rojo suave
      }
    }

    final highlightColor =
        isUserMonitoreo ? Colors.amber.withOpacity(0.05) : Colors.transparent;

    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
        ),
        // Combinar el color base, el color de nivel y el resaltado
        color: Color.alphaBlend(
            Color.alphaBlend(highlightColor, nivelColor), bgColor),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 13,
            fontWeight: value != '-' ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// Widget para la columna de encabezado redimensionable
class _ResizableHeaderColumn extends StatefulWidget {
  final String title;
  final double width;
  final bool isNumeric;
  final bool isSorted;
  final bool isAscending;
  final VoidCallback onSort;
  final Function(double) onResize;

  const _ResizableHeaderColumn({
    required this.title,
    required this.width,
    required this.isNumeric,
    required this.isSorted,
    required this.isAscending,
    required this.onSort,
    required this.onResize,
  });

  @override
  _ResizableHeaderColumnState createState() => _ResizableHeaderColumnState();
}

class _ResizableHeaderColumnState extends State<_ResizableHeaderColumn> {
  double _width = 0;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _width = widget.width;
  }

  @override
  void didUpdateWidget(_ResizableHeaderColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) {
      _width = widget.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onSort,
      child: Container(
        width: _width,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: widget.isNumeric
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.isSorted
                          ? MonitoreoStyles.primaryColor
                          : Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign:
                        widget.isNumeric ? TextAlign.right : TextAlign.left,
                  ),
                ),
                if (widget.isSorted)
                  Icon(
                    widget.isAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: MonitoreoStyles.primaryColor,
                  ),
              ],
            ),
            // Área para redimensionar columna
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isResizing = true;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _width = _width + details.delta.dx;
                      // Ancho mínimo de 50 píxeles para la columna
                      if (_width < 50) _width = 50;
                      widget.onResize(_width);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _isResizing = false;
                    });
                  },
                  child: Container(
                    width: 16,
                    color: _isResizing
                        ? Colors.grey.withOpacity(0.2)
                        : Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 24,
                        color: _isResizing
                            ? MonitoreoStyles.primaryColor
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
