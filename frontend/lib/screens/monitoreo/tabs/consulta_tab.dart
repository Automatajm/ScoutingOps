import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/monitoreo_model.dart';
import '../../../services/monitoreo_service.dart';
import '../../../data/datasources/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/data_cells.dart';
import '../widgets/responsive_card.dart';

class ConsultaTab extends StatefulWidget {
  final List<Monitoreo> monitoreos;
  final List<Map<String, dynamic>> columns;
  final bool isLoading;
  final String errorMessage;
  final Function(Monitoreo) onEdit;
  final Function(Monitoreo) onDelete;
  final Function(Monitoreo) onDetails;
  final Function() onSearch;
  final Function() onReload;
  final TextEditingController searchController;
  final TextEditingController fechaInicioController;
  final TextEditingController fechaFinController;
  final String? selectedEstado;
  final String? selectedPlaga;
  // Controladores para los filtros adicionales
  final String? selectedCasa;
  final String? selectedCantero;
  final String? selectedVariedad;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final List<String> plagas;
  // Listas para los filtros adicionales
  final List<String> casas;
  final List<String> canteros;
  final List<String> variedades;
  final Function(String?) onEstadoChanged;
  final Function(String?) onPlagaChanged;
  // Callbacks para los filtros adicionales
  final Function(String?) onCasaChanged;
  final Function(String?) onCanteroChanged;
  final Function(String?) onVariedadChanged;
  final Function(BuildContext) onSelectDateRange;
  final Function() onFechaReset;
  final Function(String, bool) onExportExcel;

  // Propiedades para paginación
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final int totalItems;
  final Function(int) onPageChanged;
  final Function(int) onItemsPerPageChanged;

  // Propiedades para ordenamiento
  final String? sortColumn;
  final bool sortAscending;
  final Function(String, bool) onSort;
  final Function(String, double) onColumnResize;
  final Map<String, double> columnWidths;

  // Propiedad para cambios pendientes
  final int pendingChangesCount;

  // Nueva propiedad para identificar pantallas pequeñas
  final bool isSmallScreen;

  // Nuevo callback para crear un nuevo monitoreo
  final Function()? onNuevoMonitoreo;

  const ConsultaTab({
    Key? key,
    required this.monitoreos,
    required this.columns,
    required this.isLoading,
    required this.errorMessage,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
    required this.onSearch,
    required this.onReload,
    required this.searchController,
    required this.fechaInicioController,
    required this.fechaFinController,
    required this.selectedEstado,
    required this.selectedPlaga,
    this.selectedCasa,
    this.selectedCantero,
    this.selectedVariedad,
    required this.fechaInicio,
    required this.fechaFin,
    required this.plagas,
    this.casas = const ['Todas'],
    this.canteros = const ['Todos'],
    this.variedades = const ['Todas'],
    required this.onEstadoChanged,
    required this.onPlagaChanged,
    required this.onCasaChanged,
    required this.onCanteroChanged,
    required this.onVariedadChanged,
    required this.onSelectDateRange,
    required this.onFechaReset,
    required this.onExportExcel,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.totalItems,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onColumnResize,
    required this.columnWidths,
    this.pendingChangesCount = 0,
    this.isSmallScreen = false,
    this.onNuevoMonitoreo,
  }) : super(key: key);

  @override
  State<ConsultaTab> createState() => _ConsultaTabState();
}

class _ConsultaTabState extends State<ConsultaTab> {
  // Estado para controlar la expansión de filtros en pantalla pequeña
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();

    // ✅ NUEVO: Mostrar mensaje temporal de modo filtrado al inicializar (solo una vez)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFilteredModeMessageIfNeeded();
    });
  }

  @override
  void didUpdateWidget(ConsultaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns != widget.columns) {
      _initializeColumnWidths();
    }
  }

  void _initializeColumnWidths() {
    if (widget.columnWidths.isNotEmpty) return;

    for (var column in widget.columns) {
      final title = column['title'] as String;
      if (!widget.columnWidths.containsKey(title)) {
        widget.columnWidths[title] = column['width'] as double;
      }
    }
  }

  // ✅ NUEVO: Mostrar mensaje temporal de modo filtrado (solo si es necesario)
  void _showFilteredModeMessageIfNeeded() {
    final authService = Provider.of<AuthService>(context, listen: false);

    //modal filtro por usuarios eliminado por juan mendoza
  }

  // Aplicar ordenamiento a los datos
  List<Monitoreo> _getSortedData() {
    if (widget.sortColumn == null) return widget.monitoreos;

    final sortColumnInfo = widget.columns.firstWhere(
      (column) => column['title'] == widget.sortColumn,
      orElse: () => widget.columns.first,
    );

    List<Monitoreo> sortedList = List<Monitoreo>.from(widget.monitoreos);

    sortedList.sort((a, b) {
      var aValue = sortColumnInfo['valueExtractor'](a);
      var bValue = sortColumnInfo['valueExtractor'](b);

      // Manejo especial para números que podrían venir como string
      if (aValue is String && bValue is String) {
        // Intenta convertir a números si es posible
        var aNum = double.tryParse(aValue.replaceAll(',', '.'));
        var bNum = double.tryParse(bValue.replaceAll(',', '.'));

        if (aNum != null && bNum != null) {
          return widget.sortAscending
              ? aNum.compareTo(bNum)
              : bNum.compareTo(aNum);
        }

        // Si no se puede convertir a número, compara como strings
        return widget.sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      } else if (aValue is num && bValue is num) {
        return widget.sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      } else if (aValue is DateTime && bValue is DateTime) {
        return widget.sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }

      // Fallback para otros tipos o valores nulos
      return widget.sortAscending ? 0 : 0;
    });

    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    // Lista de filtros para la búsqueda
    final List<String> filtrosPlagas = ['Todas', ...widget.plagas];

    // Preparar las listas para los filtros con la opción "Todas/Todos" al inicio
    final List<String> filtrosCasas = [
      'Todas',
      ...widget.casas.where((casa) => casa != 'Todas')
    ];
    final List<String> filtrosCanteros = [
      'Todos',
      ...widget.canteros.where((cantero) => cantero != 'Todos')
    ];
    final List<String> filtrosVariedades = [
      'Todas',
      ...widget.variedades.where((variedad) => variedad != 'Todas')
    ];

    // Obtener el servicio de autenticación y monitoreo
    final authService = Provider.of<AuthService>(context, listen: false);
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);
    final currentUserId = authService.getCurrentUserId();

    // Obtener datos ordenados
    final sortedData = _getSortedData();

    return Container(
      color: MonitoreoStyles.lightGrey,
      padding: EdgeInsets.all(widget.isSmallScreen ? 8 : 16),
      child: Column(
        children: [
          // ✅ REMOVIDO: Banner persistente de modo filtrado (ahora es mensaje temporal)

          // Banner de cambios pendientes
          if (widget.pendingChangesCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_problem,
                      color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hay ${widget.pendingChangesCount} cambios pendientes de sincronizar.',
                      style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Contenido principal adaptable
          Expanded(
            child: widget.isSmallScreen
                ? _buildMobileLayout(sortedData, currentUserId, filtrosPlagas,
                    filtrosCasas, filtrosCanteros, filtrosVariedades)
                : _buildDesktopLayout(sortedData, currentUserId, filtrosPlagas,
                    filtrosCasas, filtrosCanteros, filtrosVariedades),
          ),
        ],
      ),
    );
  }

  // Layout para pantallas de escritorio
  Widget _buildDesktopLayout(
    List<Monitoreo> sortedData,
    int currentUserId,
    List<String> filtrosPlagas,
    List<String> filtrosCasas,
    List<String> filtrosCanteros,
    List<String> filtrosVariedades,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filtros de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primera fila de filtros
                Row(
                  children: [
                    // Campo Lote/Código
                    Expanded(
                      child: _buildFilterFormField(
                        label: 'Lote / Código',
                        hint: 'Buscar por lote o código',
                        controller: widget.searchController,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Campo Plaga
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Plaga',
                        hint: 'Seleccione plaga',
                        options: filtrosPlagas,
                        value: widget.selectedPlaga,
                        onChanged: (value) {
                          widget
                              .onPlagaChanged(value == 'Todas' ? null : value);
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Campo Estado
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Estado',
                        hint: 'Seleccione estado',
                        options: ['Todos', 'Activo', 'Inactivo'],
                        value: widget.selectedEstado,
                        onChanged: (value) {
                          widget
                              .onEstadoChanged(value == 'Todos' ? null : value);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Segunda fila de filtros
                Row(
                  children: [
                    // Filtro Casa
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Casa',
                        hint: 'Seleccione casa',
                        options: filtrosCasas,
                        value: widget.selectedCasa,
                        onChanged: (value) {
                          widget.onCasaChanged(value == 'Todas' ? null : value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Filtro Cantero
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Cantero',
                        hint: 'Seleccione cantero',
                        options: filtrosCanteros,
                        value: widget.selectedCantero,
                        onChanged: (value) {
                          widget.onCanteroChanged(
                              value == 'Todos' ? null : value);
                        },
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Filtro Variedad
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Variedad',
                        hint: 'Seleccione variedad',
                        options: filtrosVariedades,
                        value: widget.selectedVariedad,
                        onChanged: (value) {
                          widget.onVariedadChanged(
                              value == 'Todas' ? null : value);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Tercera fila con selector de fechas, buscar y botón de exportar
                Row(
                  children: [
                    // Selector de fechas (expandido pero con límite de tamaño)
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () => widget.onSelectDateRange(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 18,
                                  color: MonitoreoStyles.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.fechaInicio != null &&
                                          widget.fechaFin != null
                                      ? 'Del ${DateFormat('dd/MM/yyyy').format(widget.fechaInicio!)} al ${DateFormat('dd/MM/yyyy').format(widget.fechaFin!)}'
                                      : 'Seleccione rango de fechas',
                                  style: TextStyle(
                                    color: widget.fechaInicio != null
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (widget.fechaInicio != null)
                                InkWell(
                                  onTap: widget.onFechaReset,
                                  child: Icon(Icons.clear,
                                      size: 18, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Botón Buscar
                    ElevatedButton.icon(
                      onPressed: widget.onSearch,
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MonitoreoStyles.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Botón para exportar a Excel
                    ElevatedButton.icon(
                      onPressed: () =>
                          widget.onExportExcel('Monitoreos', false),
                      icon: const Icon(Icons.file_download, size: 20),
                      label: const Text('Exportar Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

          // Tabla de monitoreos
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.errorMessage.isNotEmpty
                    ? _buildErrorMessage()
                    : Column(
                        children: [
                          // Encabezados de tabla con soporte para ordenamiento
                          DataCells.buildTableHeader(
                            columns: widget.columns,
                            sortColumn: widget.sortColumn,
                            sortAscending: widget.sortAscending,
                            onSort: widget.onSort,
                            columnWidths: widget.columnWidths,
                            onColumnResize: widget.onColumnResize,
                          ),

                          // Filas de datos
                          Expanded(
                            child: sortedData.isEmpty
                                ? Center(
                                    child: Text(
                                      'No hay monitoreos para mostrar',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : _buildDataRows(sortedData, currentUserId),
                          ),

                          // Controles de paginación
                          _buildPaginationControls(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // Layout para pantallas móviles con paginación fija mejorada
  Widget _buildMobileLayout(
    List<Monitoreo> sortedData,
    int currentUserId,
    List<String> filtrosPlagas,
    List<String> filtrosCasas,
    List<String> filtrosCanteros,
    List<String> filtrosVariedades,
  ) {
    return Column(
      children: [
        // SECCIÓN SUPERIOR: Filtros + Resultados (ocupa todo el espacio disponible)
        Expanded(
          child: Column(
            children: [
              // FILTROS: Tamaño fijo cuando está expandido
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isFilterExpanded
                    ? 400
                    : 60, // Altura fija cuando está expandido
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título y control de expansión (siempre visible)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isFilterExpanded = !_isFilterExpanded;
                          });
                        },
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Filtros de búsqueda',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: MonitoreoStyles.primaryColor,
                                  ),
                                ),
                              ),
                              Icon(
                                _isFilterExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Contenido de filtros (expandible con scroll interno)
                      if (_isFilterExpanded)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: [
                                // Campo Lote/Código
                                _buildFilterFormField(
                                  label: 'Lote / Código',
                                  hint: 'Buscar por lote o código',
                                  controller: widget.searchController,
                                ),
                                const SizedBox(height: 12),

                                // Campo Plaga
                                _buildFilterDropdown(
                                  label: 'Plaga',
                                  hint: 'Seleccione plaga',
                                  options: filtrosPlagas,
                                  value: widget.selectedPlaga,
                                  onChanged: (value) {
                                    widget.onPlagaChanged(
                                        value == 'Todas' ? null : value);
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Campo Estado
                                _buildFilterDropdown(
                                  label: 'Estado',
                                  hint: 'Seleccione estado',
                                  options: ['Todos', 'Activo', 'Inactivo'],
                                  value: widget.selectedEstado,
                                  onChanged: (value) {
                                    widget.onEstadoChanged(
                                        value == 'Todos' ? null : value);
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Filtros adicionales en una tarjeta expandible
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  color: Colors.grey.shade50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: ExpansionTile(
                                    title: const Text('Filtros adicionales',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    textColor: MonitoreoStyles.primaryColor,
                                    iconColor: MonitoreoStyles.primaryColor,
                                    collapsedBackgroundColor:
                                        Colors.grey.shade50,
                                    backgroundColor: Colors.grey.shade50,
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    childrenPadding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 12),
                                    children: [
                                      // Casa
                                      _buildFilterDropdown(
                                        label: 'Casa',
                                        hint: 'Seleccione casa',
                                        options: filtrosCasas,
                                        value: widget.selectedCasa,
                                        onChanged: (value) {
                                          widget.onCasaChanged(
                                              value == 'Todas' ? null : value);
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Cantero
                                      _buildFilterDropdown(
                                        label: 'Cantero',
                                        hint: 'Seleccione cantero',
                                        options: filtrosCanteros,
                                        value: widget.selectedCantero,
                                        onChanged: (value) {
                                          widget.onCanteroChanged(
                                              value == 'Todos' ? null : value);
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      // Variedad
                                      _buildFilterDropdown(
                                        label: 'Variedad',
                                        hint: 'Seleccione variedad',
                                        options: filtrosVariedades,
                                        value: widget.selectedVariedad,
                                        onChanged: (value) {
                                          widget.onVariedadChanged(
                                              value == 'Todas' ? null : value);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Selector de fechas
                                InkWell(
                                  onTap: () =>
                                      widget.onSelectDateRange(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 16,
                                            color:
                                                MonitoreoStyles.primaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.fechaInicio != null &&
                                                    widget.fechaFin != null
                                                ? 'Del ${DateFormat('dd/MM/yyyy').format(widget.fechaInicio!)} al ${DateFormat('dd/MM/yyyy').format(widget.fechaFin!)}'
                                                : 'Seleccione rango de fechas',
                                            style: TextStyle(
                                              color: widget.fechaInicio != null
                                                  ? Colors.black
                                                  : Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (widget.fechaInicio != null)
                                          InkWell(
                                            onTap: widget.onFechaReset,
                                            child: Icon(Icons.clear,
                                                size: 16,
                                                color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Botones de acción
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: widget.onSearch,
                                        icon:
                                            const Icon(Icons.search, size: 16),
                                        label: const Text('Buscar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              MonitoreoStyles.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => widget.onExportExcel(
                                            'Monitoreos', false),
                                        icon: const Icon(Icons.file_download,
                                            size: 16),
                                        label: const Text('Exportar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // RESULTADOS: Ocupan el espacio restante disponible
              Expanded(
                child: widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.errorMessage.isNotEmpty
                        ? _buildErrorMessage()
                        : Column(
                            children: [
                              // Información de resultados
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Mostrando ${sortedData.length} de ${widget.totalItems} resultados',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              // Lista de monitoreos como tarjetas
                              Expanded(
                                child: sortedData.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No hay monitoreos para mostrar',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      )
                                    : _buildMonitoreoCards(
                                        sortedData, currentUserId),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),

        // PAGINACIÓN: Siempre fija en la parte inferior
        _buildMobilePaginationControls(),
      ],
    );
  }

  // Widget para mostrar mensajes de error
  Widget _buildErrorMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.onReload,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // Widget para los controles de paginación en escritorio
  Widget _buildPaginationControls() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selector de elementos por página
          Row(
            children: [
              Text(
                'Mostrar ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              DropdownButton<int>(
                value: widget.itemsPerPage,
                items: [25, 50, 100, 200].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onItemsPerPageChanged(value);
                  }
                },
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                underline: Container(),
              ),
              Text(
                ' elementos',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),

          // Información de página actual
          Text(
            'Mostrando ${widget.monitoreos.isEmpty ? 0 : 1}-${widget.monitoreos.length} de ${widget.totalItems} elementos',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),

          // Botones de navegación
          Row(
            children: [
              // Botón para ir a la primera página
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: widget.currentPage > 1
                    ? () => widget.onPageChanged(1)
                    : null,
                color: widget.currentPage > 1
                    ? MonitoreoStyles.primaryColor
                    : Colors.grey.shade400,
                iconSize: 20,
                splashRadius: 20,
              ),

              // Botón para ir a la página anterior
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: widget.currentPage > 1
                    ? () => widget.onPageChanged(widget.currentPage - 1)
                    : null,
                color: widget.currentPage > 1
                    ? MonitoreoStyles.primaryColor
                    : Colors.grey.shade400,
                iconSize: 20,
                splashRadius: 20,
              ),

              // Número de página actual
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MonitoreoStyles.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.currentPage}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              // Botón para ir a la página siguiente
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: widget.currentPage < widget.totalPages
                    ? () => widget.onPageChanged(widget.currentPage + 1)
                    : null,
                color: widget.currentPage < widget.totalPages
                    ? MonitoreoStyles.primaryColor
                    : Colors.grey.shade400,
                iconSize: 20,
                splashRadius: 20,
              ),

              // Botón para ir a la última página
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: widget.currentPage < widget.totalPages
                    ? () => widget.onPageChanged(widget.totalPages)
                    : null,
                color: widget.currentPage < widget.totalPages
                    ? MonitoreoStyles.primaryColor
                    : Colors.grey.shade400,
                iconSize: 20,
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para los controles de paginación en móvil
  Widget _buildMobilePaginationControls() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botones de navegación simplificados
          Row(
            children: [
              // Botón para ir a la página anterior
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: widget.currentPage > 1
                    ? () => widget.onPageChanged(widget.currentPage - 1)
                    : null,
                color: widget.currentPage > 1
                    ? MonitoreoStyles.primaryColor
                    : Colors.grey.shade400,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ), // Número de página actual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MonitoreoStyles.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.currentPage}/${widget.totalPages}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              // Botón para ir a la página siguiente
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: widget.currentPage < widget.totalPages
                    ? () => widget.onPageChanged(widget.currentPage + 1)
                    : null,
                color: widget.currentPage < widget.totalPages
                    ? MonitoreoStyles.primaryColor
                    : Colors.grey.shade400,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),

          // Selector de elementos por página compacto
          DropdownButton<int>(
            value: widget.itemsPerPage,
            items: [25, 50, 100].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child:
                    Text('$value / pág.', style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                widget.onItemsPerPageChanged(value);
              }
            },
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            underline: Container(),
          ),
        ],
      ),
    );
  }

  // Construir las filas de datos para vista de escritorio
  Widget _buildDataRows(List<Monitoreo> monitoreos, int currentUserId) {
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);

    return ListView.builder(
      itemCount: monitoreos.length,
      itemBuilder: (context, index) {
        final monitoreo = monitoreos[index];
        // Verificamos si el usuario actual es el creador del monitoreo
        bool isUserMonitoreo = monitoreo.pmmo_creadopor == currentUserId;
        bool isAlternateRow = index % 2 == 1;

        return _buildMonitoreoRow(
          monitoreo,
          isUserMonitoreo,
          isAlternateRow,
          monitoreoService,
        );
      },
    );
  }

  // Construir las tarjetas de monitoreo para vista móvil
  Widget _buildMonitoreoCards(List<Monitoreo> monitoreos, int currentUserId) {
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);

    return ListView.builder(
      itemCount: monitoreos.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (context, index) {
        final monitoreo = monitoreos[index];
        bool isUserMonitoreo = monitoreo.pmmo_creadopor == currentUserId;

        // Obtener valores específicos para la tarjeta
        final lote = monitoreo.pmlt_codigo ?? 'N/A';
        final casa = monitoreo.pmmo_casa ?? 'N/A';
        final cantero = monitoreo.pmmo_cantero ?? 'N/A';
        final variedad =
            monitoreo.pmmo_variedad ?? monitoreo.pmva_descripcion ?? 'N/A';
        final plaga = monitoreo.pmni_nombrecomun ?? 'N/A';
        final fecha = monitoreo.pmmo_fecha != null
            ? DateFormat('dd/MM/yyyy').format(monitoreo.pmmo_fecha!)
            : 'N/A';
        final estado = monitoreo.pmmo_estatus == 1 ? 'Activo' : 'Inactivo';
        final cantidad = monitoreo.pmmo_cantidad?.toString() ?? '0';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isUserMonitoreo
                  ? Colors.amber.shade300
                  : Colors.grey.shade200,
              width: isUserMonitoreo ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con fecha y estado
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monitoreo: $fecha',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: monitoreo.pmmo_estatus == 1
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: monitoreo.pmmo_estatus == 1
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                        ),
                      ),
                      child: Text(
                        estado,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: monitoreo.pmmo_estatus == 1
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido principal
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información de lote
                    Row(
                      children: [
                        Expanded(
                          child: _buildCardInfoItem('Lote', lote),
                        ),
                        Expanded(
                          child: _buildCardInfoItem('Casa', casa),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _buildCardInfoItem('Cantero', cantero),
                        ),
                        Expanded(
                          child: _buildCardInfoItem('Cantidad', cantidad),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _buildCardInfoItem('Variedad', variedad),
                        ),
                        Expanded(
                          child: _buildCardInfoItem('Plaga', plaga),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Acciones
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              ButtonBar(
                buttonPadding: EdgeInsets.zero,
                alignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Botón de ver detalles
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        color: MonitoreoStyles.accentColor,
                        onPressed: () => widget.onDetails(monitoreo),
                        tooltip: 'Ver detalles',
                      ),

                      // Botón de editar
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: monitoreoService.canEditMonitoreo(monitoreo)
                            ? MonitoreoStyles.primaryColor
                            : Colors.grey.shade400,
                        onPressed: monitoreoService.canEditMonitoreo(monitoreo)
                            ? () => widget.onEdit(monitoreo)
                            : null,
                        tooltip: 'Editar',
                      ),

                      // Botón de eliminar
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: monitoreoService.canDeleteMonitoreo(monitoreo)
                            ? Colors.red
                            : Colors.grey.shade400,
                        onPressed:
                            monitoreoService.canDeleteMonitoreo(monitoreo)
                                ? () => widget.onDelete(monitoreo)
                                : null,
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),

                  // Indicador de monitoreo propio
                  if (isUserMonitoreo)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          Icon(Icons.person,
                              size: 14, color: Colors.amber.shade800),
                          const SizedBox(width: 4),
                          Text(
                            'Propio',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Elemento de información para tarjetas móviles
  Widget _buildCardInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMonitoreoRow(
    Monitoreo monitoreo,
    bool isUserMonitoreo,
    bool isAlternateRow,
    MonitoreoService monitoreoService,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Columna de acciones fija
        Container(
          width: 140,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isAlternateRow
                ? Color.alphaBlend(
                    Colors.amber.withOpacity(isUserMonitoreo ? 0.05 : 0),
                    const Color(0xFFF9F9F9))
                : Color.alphaBlend(
                    Colors.amber.withOpacity(isUserMonitoreo ? 0.05 : 0),
                    Colors.white),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
              right: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de ver detalles
              InkWell(
                onTap: () => widget.onDetails(monitoreo),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 20,
                    color: MonitoreoStyles.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Botón de editar
              InkWell(
                onTap: monitoreoService.canEditMonitoreo(monitoreo)
                    ? () => widget.onEdit(monitoreo)
                    : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: monitoreoService.canEditMonitoreo(monitoreo)
                        ? MonitoreoStyles.primaryColor
                        : Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Botón de eliminar
              InkWell(
                onTap: monitoreoService.canDeleteMonitoreo(monitoreo)
                    ? () => widget.onDelete(monitoreo)
                    : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: monitoreoService.canDeleteMonitoreo(monitoreo)
                        ? Colors.red
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Datos desplazables
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.columns.map((column) {
                final title = column['title'] as String;
                final value = column['valueExtractor'](monitoreo);
                final width =
                    widget.columnWidths[title] ?? (column['width'] as double);
                final isNumeric = column.containsKey('isNumeric')
                    ? column['isNumeric'] as bool
                    : false;

                // Celda especial para el estado
                if (title == 'Estado') {
                  return DataCells.buildStatusCell(
                      value, width, isUserMonitoreo, isAlternateRow);
                } else if (['Nivel M1', 'Nivel M2', 'Nivel M3']
                    .contains(title)) {
                  // Celdas para niveles
                  return DataCells.buildNivelCell(
                      value, width, isUserMonitoreo, isAlternateRow);
                } else {
                  // Celdas normales
                  return DataCells.buildDataCell(
                    value,
                    width,
                    isUserMonitoreo: isUserMonitoreo,
                    isAlternateRow: isAlternateRow,
                    isNumeric: isNumeric,
                  );
                }
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF505050),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              fillColor: Colors.white,
              filled: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String hint,
    required List<String> options,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF505050),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: onChanged,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }
}
