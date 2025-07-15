import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int totalItems;
  final int itemsPerPage;
  final int currentPage;
  final Function(int) onPageChanged;
  final Color primaryColor;
  final Color textColor;
  final String itemsLabel;

  const PaginationWidget({
    Key? key,
    required this.totalItems,
    required this.currentPage,
    required this.onPageChanged,
    this.itemsPerPage = 20,
    this.primaryColor = const Color(0xFF1E73BB),
    this.textColor = const Color(0xFF505050),
    this.itemsLabel = 'elementos',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calcular el total de páginas
    final int totalPages = (totalItems / itemsPerPage).ceil();

    // Si solo hay una página, no mostrar controles de paginación
    if (totalPages <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Center(
          child: Text(
            totalItems == 0
                ? 'No hay $itemsLabel para mostrar'
                : 'Mostrando $totalItems $itemsLabel',
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
          ),
        ),
      );
    }

    // Calcular rango de elementos mostrados
    final int startItem = (currentPage - 1) * itemsPerPage + 1;
    final int endItem =
        currentPage == totalPages ? totalItems : currentPage * itemsPerPage;

    // Determinar qué números de página mostrar
    List<int> pagesToShow = [];

    // Siempre incluir la primera página
    pagesToShow.add(1);

    // Agregar páginas alrededor de la página actual
    for (int i = currentPage - 2; i <= currentPage + 2; i++) {
      if (i > 1 && i < totalPages) {
        pagesToShow.add(i);
      }
    }

    // Siempre incluir la última página si hay más de una
    if (totalPages > 1) {
      pagesToShow.add(totalPages);
    }

    // Ordenar y eliminar duplicados
    pagesToShow = pagesToShow.toSet().toList()..sort();

    // Construir botones de paginación
    List<Widget> pageButtons = [];

    // Botón para ir a la página anterior
    pageButtons.add(
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed:
            currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
        color: currentPage > 1 ? primaryColor : Colors.grey.shade400,
        tooltip: 'Página anterior',
      ),
    );

    // Botones para páginas específicas
    int prevPage = 0;
    for (int page in pagesToShow) {
      // Agregar indicador de puntos suspensivos si hay saltos entre páginas
      if (prevPage > 0 && page - prevPage > 1) {
        pageButtons.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('...', style: TextStyle(color: Colors.grey.shade600)),
          ),
        );
      }

      // Agregar botón para la página
      pageButtons.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            borderRadius: BorderRadius.circular(4),
            color: currentPage == page ? primaryColor : Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => onPageChanged(page),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  page.toString(),
                  style: TextStyle(
                    color: currentPage == page
                        ? Colors.white
                        : Colors.grey.shade700,
                    fontWeight: currentPage == page
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      prevPage = page;
    }

    // Botón para ir a la página siguiente
    pageButtons.add(
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: currentPage < totalPages
            ? () => onPageChanged(currentPage + 1)
            : null,
        color: currentPage < totalPages ? primaryColor : Colors.grey.shade400,
        tooltip: 'Página siguiente',
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Información de registros mostrados
          Text(
            'Mostrando $startItem-$endItem de $totalItems $itemsLabel',
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
          ),

          // Control de paginación
          Row(
            mainAxisSize: MainAxisSize.min,
            children: pageButtons,
          ),
        ],
      ),
    );
  }
}
