import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../models/pm_plan_model.dart';
import '../../../models/unidad_cultivo_model.dart';
import '../../../services/pm_plan_service.dart';
import '../../widgets/pagination_widget.dart';

// Clase para manejar la información de las columnas
class ColumnInfo {
  final String title;
  double width;
  bool isSorted;
  bool sortAscending;
  final Function(dynamic) valueExtractor;

  ColumnInfo({
    required this.title,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    required this.valueExtractor,
  });
}

class PmPlanManagementScreen extends StatefulWidget {
  final Function(bool)? onEditModeChanged;

  const PmPlanManagementScreen({Key? key, this.onEditModeChanged})
      : super(key: key);

  @override
  State<PmPlanManagementScreen> createState() => _PmPlanManagementScreenState();
}

class _PmPlanManagementScreenState extends State<PmPlanManagementScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codigoSearchController = TextEditingController();

  // Modo actual: 'Planificar' o 'Planificado'
  String _currentMode = 'Planificar';

  // Variables para filtros
  List<String> _ubicaciones = []; // Ya no hardcodeado
  String? _selectedUbicacion; // Ya no tiene valor por defecto
  bool _isLoadingUbicaciones = false;

  String? _selectedEstado;
  String? _selectedEstadoPlanificacion;

  // Variables para filtros avanzados
  List<String> _selectedCodigos = [];
  List<String> _availableCodigos = [];
  bool _showCodigoFilter = false;
  List<String> _filteredCodigos = [];

  // Variables para selección múltiple (modo planificar)
  List<UnidadCultivo> _selectedUnidades = [];
  bool _selectAll = false;

  // Colores del tema
  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color backgroundColor = Colors.white;
  final Color lightGrey = const Color(0xFFF5F5F5);

  // Variables para datos
  List<UnidadCultivo> _unidadData = [];
  List<PmPlan> _planData = [];
  List<dynamic> _sortedData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Variables para paginación
  int _currentPage = 1;
  int _itemsPerPage = 20;
  int _totalItems = 0;
  int _totalPages = 1;
  List<dynamic> _allPlanes = [];

  // Servicio
  final PmPlanService _pmPlanService = PmPlanService();

  // Mapeo de estatus a nombres de estado
  final Map<int, String> _estatusMap = {
    1: 'Activo',
    0: 'Inactivo',
  };

  // Estados de planificación
  final List<String> _estadosPlanificacion = [
    'Planificado',
    'En proceso',
    'Ejecutado'
  ];

  // Definición de columnas para unidades de cultivo (modo planificar)
  late List<ColumnInfo> _unidadColumns;

  // Definición de columnas para planes (modo planificado)
  late List<ColumnInfo> _planColumns;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Inicializar columnas para unidades de cultivo
    _unidadColumns = [
      // ✅ NUEVA: Columna de Acción
      ColumnInfo(
        title: 'Acción',
        width: 80,
        valueExtractor: (unidad) => '',
      ),
      ColumnInfo(
        title: 'Código',
        width: 150,
        valueExtractor: (unidad) => unidad.codigo,
      ),
      ColumnInfo(
        title: 'Cantero',
        width: 180,
        valueExtractor: (unidad) => unidad.cantero,
      ),
      ColumnInfo(
        title: 'ID Externo',
        width: 120,
        valueExtractor: (unidad) => unidad.id.toString(),
      ),
      ColumnInfo(
        title: 'Estado Invernadero',
        width: 180,
        valueExtractor: (unidad) => _estatusMap[unidad.estatus] ?? '-',
      ),
    ];

    // Inicializar columnas para planes
    _planColumns = [
      ColumnInfo(
        title: 'Código',
        width: 150,
        valueExtractor: (plan) => plan.unidadCodigo,
      ),
      ColumnInfo(
        title: 'Cantero',
        width: 180,
        valueExtractor: (plan) => plan.unidadCantero,
      ),
      ColumnInfo(
        title: 'Ubicación',
        width: 150,
        valueExtractor: (plan) => plan.ubicacion,
      ),
      ColumnInfo(
        title: 'Estado Planificación',
        width: 180,
        valueExtractor: (plan) => plan.estadoPlanificacion,
      ),
      ColumnInfo(
        title: 'Estado Plan',
        width: 120,
        valueExtractor: (plan) => _estatusMap[plan.estatus] ?? '-',
      ),
      ColumnInfo(
        title: 'Fecha Ejecución',
        width: 150,
        valueExtractor: (plan) {
          if (plan.fechaEjecucion != null && plan.fechaEjecucion!.isNotEmpty) {
            try {
              final DateTime date = DateTime.parse(plan.fechaEjecucion!);
              return DateFormat('dd/MM/yyyy HH:mm').format(date);
            } catch (e) {
              return plan.fechaEjecucion ?? '-';
            }
          }
          return '-';
        },
      ),
    ];

    // Escuchar cambios de tab
    _tabController.addListener(() {
      if (mounted) {
        final newMode =
            _tabController.index == 0 ? 'Planificar' : 'Planificado';
        if (_currentMode != newMode) {
          setState(() {
            _currentMode = newMode;
            _clearSelections();
          });
          _loadData();
        }
      }
    });

    // ⭐ CARGAR UBICACIONES DINÁMICAMENTE AL INICIAR
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUbicaciones();
      }
    });
  }

  // ⭐ NUEVO MÉTODO: Cargar ubicaciones dinámicamente
  Future<void> _loadUbicaciones() async {
    if (!mounted) return;

    setState(() {
      _isLoadingUbicaciones = true;
    });

    try {
      print('🔄 Cargando ubicaciones dinámicamente...');
      final ubicaciones = await _pmPlanService.getUbicaciones();

      if (mounted) {
        setState(() {
          _ubicaciones = ubicaciones;
          // ⭐ Seleccionar la primera ubicación disponible automáticamente
          if (_ubicaciones.isNotEmpty && _selectedUbicacion == null) {
            _selectedUbicacion = _ubicaciones.first;
            print(
                '✅ Ubicación seleccionada automáticamente: $_selectedUbicacion');
          }
          _isLoadingUbicaciones = false;
        });

        // Cargar datos después de obtener las ubicaciones
        if (_selectedUbicacion != null) {
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUbicaciones = false;
          _errorMessage = 'Error al cargar ubicaciones: $e';
        });
        print('❌ Error al cargar ubicaciones: $e');
        _showMessage('Error al cargar ubicaciones dinámicas');
      }
    }
  }

  // ✅ VERIFICAR SI HAY FILTROS APLICADOS O DATOS SELECCIONADOS
  bool get _hasFiltersAppliedOrSelection {
    // Verificar filtros aplicados
    bool hasFilters = _selectedEstado != null ||
        _selectedEstadoPlanificacion != null ||
        _searchController.text.isNotEmpty ||
        _selectedCodigos.isNotEmpty;

    // ⭐ NUEVA LÓGICA: Verificar selecciones en AMBOS modos
    bool hasSelections = false;

    if (_currentMode == 'Planificar') {
      hasSelections = _selectedUnidades.isNotEmpty;
    } else if (_currentMode == 'Planificado') {
      // ⭐ AGREGAR: Permitir actualización masiva si hay datos visibles
      hasSelections = _sortedData.isNotEmpty;
    }

    return hasFilters || hasSelections;
  }

  // Obtener códigos únicos de los datos actuales
  void _updateAvailableCodigos() {
    final Set<String> codigos = {};

    if (_currentMode == 'Planificar') {
      for (final unidad in _unidadData) {
        if (unidad.codigo.toLowerCase() != 'general') {
          codigos.add(unidad.codigo);
        }
      }
    } else {
      for (final plan in _planData) {
        if (plan.unidadCodigo.toLowerCase() != 'general') {
          codigos.add(plan.unidadCodigo);
        }
      }
    }

    _availableCodigos = codigos.toList()..sort();

    // Reinicializar _filteredCodigos basado en la búsqueda actual
    if (_codigoSearchController.text.isEmpty) {
      _filteredCodigos = List.from(_availableCodigos);
    } else {
      _filteredCodigos = _availableCodigos
          .where((codigo) => codigo
              .toLowerCase()
              .contains(_codigoSearchController.text.toLowerCase()))
          .toList();
    }

    _selectedCodigos = _selectedCodigos
        .where((codigo) => _availableCodigos.contains(codigo))
        .toList();
  }

  // Aplicar filtro de códigos a los datos
  void _applyCodigoFilter() {
    if (_selectedCodigos.isEmpty) {
      _applyPagination();
      return;
    }

    final List<dynamic> filteredData;

    if (_currentMode == 'Planificar') {
      filteredData = _unidadData
          .where((unidad) => _selectedCodigos.contains(unidad.codigo))
          .toList();
    } else {
      filteredData = _planData
          .where((plan) => _selectedCodigos.contains(plan.unidadCodigo))
          .toList();
    }

    setState(() {
      _totalItems = filteredData.length;
      _currentPage = 1;

      final int startIndex = (_currentPage - 1) * _itemsPerPage;
      int endIndex = startIndex + _itemsPerPage;

      if (endIndex > filteredData.length) {
        endIndex = filteredData.length;
      }

      _sortedData = filteredData.sublist(startIndex, endIndex);
    });
  }

  // Obtener color del estado ejecutado basado en la fecha
  Map<String, Color> _getEjecutadoColors(String? fechaEjecucion) {
    if (fechaEjecucion == null ||
        fechaEjecucion.isEmpty ||
        fechaEjecucion == '-') {
      return {
        'background': const Color(0xFFF5F5F5),
        'text': const Color(0xFF757575),
      };
    }

    try {
      final DateTime fechaEjec = DateTime.parse(fechaEjecucion);
      final DateTime now = DateTime.now();

      final DateTime fechaEjecSoloFecha =
          DateTime(fechaEjec.year, fechaEjec.month, fechaEjec.day);
      final DateTime hoySoloFecha = DateTime(now.year, now.month, now.day);

      final int diasDiferencia =
          hoySoloFecha.difference(fechaEjecSoloFecha).inDays;

      if (diasDiferencia <= 7) {
        return {
          'background': const Color(0xFFE8F5E8),
          'text': const Color(0xFF388E3C),
        };
      } else if (diasDiferencia <= 14) {
        return {
          'background': const Color(0xFFF8F4E6),
          'text': const Color(0xFFFF8F00),
        };
      } else {
        return {
          'background': const Color(0xFFFFEBEE),
          'text': const Color(0xFFD32F2F),
        };
      }
    } catch (e) {
      return {
        'background': const Color(0xFFF5F5F5),
        'text': const Color(0xFF757575),
      };
    }
  }

  // Obtener información detallada del tiempo transcurrido
  String _getTimeElapsedInfo(String? fechaEjecucion) {
    if (fechaEjecucion == null ||
        fechaEjecucion.isEmpty ||
        fechaEjecucion == '-') {
      return 'Sin fecha de ejecución';
    }

    try {
      final DateTime fechaEjec = DateTime.parse(fechaEjecucion);
      final DateTime now = DateTime.now();

      final DateTime fechaEjecSoloFecha =
          DateTime(fechaEjec.year, fechaEjec.month, fechaEjec.day);
      final DateTime hoySoloFecha = DateTime(now.year, now.month, now.day);

      final int diasDiferencia =
          hoySoloFecha.difference(fechaEjecSoloFecha).inDays;

      if (diasDiferencia == 0) {
        return 'Ejecutado hoy';
      } else if (diasDiferencia == 1) {
        return 'Ejecutado hace 1 día';
      } else if (diasDiferencia <= 7) {
        return 'Ejecutado hace $diasDiferencia días';
      } else if (diasDiferencia <= 14) {
        final semanas = (diasDiferencia / 7).floor();
        final diasExtra = diasDiferencia % 7;
        if (diasExtra == 0) {
          return 'Ejecutado hace ${semanas == 1 ? '1 semana' : '$semanas semanas'}';
        } else {
          return 'Ejecutado hace ${semanas == 1 ? '1 semana' : '$semanas semanas'} y $diasExtra ${diasExtra == 1 ? 'día' : 'días'}';
        }
      } else {
        final semanas = (diasDiferencia / 7).floor();
        return 'Ejecutado hace $semanas semanas';
      }
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  // ✅ ACTUALIZACIÓN MASIVA DE ESTADO DE PLANIFICACIÓN
  Future<void> _showMassiveUpdateDialog() async {
    String? selectedEstado;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Actualización Masiva'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccione el nuevo estado de planificación para todos los planes que coincidan con los filtros actuales:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedEstado,
                      isExpanded: true,
                      hint: const Text('Seleccione nuevo estado'),
                      items: _estadosPlanificacion.map((String estado) {
                        return DropdownMenuItem<String>(
                          value: estado,
                          child: Text(estado),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setDialogState(() {
                          selectedEstado = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtros aplicados:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedUbicacion != null)
                        Text('• Ubicación: $_selectedUbicacion'),
                      if (_selectedEstadoPlanificacion != null)
                        Text(
                            '• Estado planificación: $_selectedEstadoPlanificacion'),
                      if (_selectedEstado != null)
                        Text('• Estado: $_selectedEstado'),
                      if (_searchController.text.isNotEmpty)
                        Text('• Búsqueda: "${_searchController.text}"'),
                      if (_selectedCodigos.isNotEmpty)
                        Text(
                            '• Códigos seleccionados: ${_selectedCodigos.length} códigos (${_selectedCodigos.take(3).join(', ')}${_selectedCodigos.length > 3 ? '...' : ''})'),
                      if (_selectedUbicacion == null &&
                          _selectedEstadoPlanificacion == null &&
                          _selectedEstado == null &&
                          _searchController.text.isEmpty &&
                          _selectedCodigos.isEmpty)
                        const Text('• Sin filtros (todos los planes)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedEstado == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _performMassiveUpdate(selectedEstado!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performMassiveUpdate(String nuevoEstado) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _pmPlanService.updateEstadoPlanificacionMasivo(
        nuevoEstado: nuevoEstado,
        ubicacion: _selectedUbicacion,
        estadoPlanificacion: _selectedEstadoPlanificacion != null &&
                _selectedEstadoPlanificacion != 'Todos'
            ? _selectedEstadoPlanificacion
            : null,
        estatus: _selectedEstado != null && _selectedEstado != 'Todos'
            ? (_estatusMap
                .map((k, v) => MapEntry(v, k.toString()))[_selectedEstado])
            : null,
        busqueda:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        codigos: _selectedCodigos.isNotEmpty ? _selectedCodigos : null,
        modificadoPor: 1,
      );

      if (result['success'] == true && mounted) {
        final planesActualizados = result['planes_actualizados'] ?? 0;
        String mensaje =
            '$planesActualizados planes actualizados a estado "$nuevoEstado"';

        if (_selectedCodigos.isNotEmpty) {
          mensaje +=
              '\n✅ Se aplicó el filtro de ${_selectedCodigos.length} códigos seleccionados.';
        }

        _showMessage(mensaje);
        await _loadData();
      }
    } catch (e) {
      _showMessage('Error en actualización masiva: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Método para notificar el cambio en el modo de edición
  void _updateEditMode(bool isEditing) {
    if (widget.onEditModeChanged != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onEditModeChanged!(isEditing);
        }
      });
    }
  }

  // Limpiar selecciones y filtros
  void _clearSelections() {
    setState(() {
      _selectedUnidades.clear();
      _selectAll = false;
      _selectedCodigos.clear();
      _showCodigoFilter = false;
      _codigoSearchController.clear();
      _filteredCodigos = List.from(_availableCodigos);
      _searchController.clear();
      _selectedEstado = null;
      _selectedEstadoPlanificacion = null;
    });
  }

  // ✅ MÉTODO PARA LIMPIAR TODOS LOS FILTROS Y RECARGAR
  Future<void> _clearAllFiltersAndReload() async {
    setState(() {
      _selectedUnidades.clear();
      _selectAll = false;
      _selectedCodigos.clear();
      _showCodigoFilter = false;
      _codigoSearchController.clear();
      _searchController.clear();
      _selectedEstado = null;
      _selectedEstadoPlanificacion = null;
      _filteredCodigos.clear();
      _availableCodigos.clear();
    });

    await _loadData();
  }

  // Método para ordenar datos
  void _sortData(int columnIndex) {
    if (!mounted) return;

    final columns =
        _currentMode == 'Planificar' ? _unidadColumns : _planColumns;

    setState(() {
      for (int i = 0; i < columns.length; i++) {
        if (i != columnIndex) {
          columns[i].isSorted = false;
        }
      }

      if (columns[columnIndex].isSorted) {
        columns[columnIndex].sortAscending =
            !columns[columnIndex].sortAscending;
      } else {
        columns[columnIndex].isSorted = true;
        columns[columnIndex].sortAscending = true;
      }

      _sortedData.sort((a, b) {
        dynamic valueA = columns[columnIndex].valueExtractor(a);
        dynamic valueB = columns[columnIndex].valueExtractor(b);

        int result;

        if (valueA is String && valueB is String) {
          result = valueA.compareTo(valueB);
        } else {
          try {
            final numA = num.parse(valueA.toString());
            final numB = num.parse(valueB.toString());
            result = numA.compareTo(numB);
          } catch (e) {
            result = valueA.toString().compareTo(valueB.toString());
          }
        }

        return columns[columnIndex].sortAscending ? result : -result;
      });
    });
  }

  // Método para cambiar de página
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _applyPagination();
    });
  }

  // Aplicar paginación a los datos
  void _applyPagination() {
    List<dynamic> dataToUse;

    if (_selectedCodigos.isNotEmpty) {
      if (_currentMode == 'Planificar') {
        dataToUse = _unidadData
            .where((unidad) => _selectedCodigos.contains(unidad.codigo))
            .toList();
      } else {
        dataToUse = _planData
            .where((plan) => _selectedCodigos.contains(plan.unidadCodigo))
            .toList();
      }
    } else {
      dataToUse = _currentMode == 'Planificar' ? _unidadData : _planData;
    }

    if (dataToUse.isEmpty) {
      _sortedData = [];
      _totalItems = 0;
      return;
    }

    _totalItems = dataToUse.length;

    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (endIndex > dataToUse.length) {
      endIndex = dataToUse.length;
    }

    if (startIndex >= dataToUse.length) {
      _currentPage = (dataToUse.length / _itemsPerPage).ceil();
      return _applyPagination();
    }

    _sortedData = dataToUse.sublist(startIndex, endIndex);
  }

  // Cargar datos según el modo actual
  Future<void> _loadData() async {
    if (!mounted) return;

    // ⭐ VALIDAR QUE HAY UNA UBICACIÓN SELECCIONADA
    if (_selectedUbicacion == null || _selectedUbicacion!.isEmpty) {
      print('⚠️ No hay ubicación seleccionada, no se cargan datos');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Debe seleccionar una ubicación primero';
      });
      _showMessage('Seleccione una ubicación para cargar datos');
      return;
    }

    print('🎯 Cargando datos para ubicación: $_selectedUbicacion');

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_currentMode == 'Planificar') {
        print(
            '📋 Modo: Planificar - Cargando unidades disponibles para $_selectedUbicacion');

        final unidades =
            await _pmPlanService.getUnidadesDisponiblesParaPlanificar(
          ubicacion: _selectedUbicacion!,
          busqueda:
              _searchController.text.isNotEmpty ? _searchController.text : null,
          estatus: _selectedEstado != null && _selectedEstado != 'Todos'
              ? (_estatusMap
                  .map((k, v) => MapEntry(v, k.toString()))[_selectedEstado])
              : null,
        );

        print(
            '✅ Unidades obtenidas para $_selectedUbicacion: ${unidades.length}');

        final unidadesFiltradas = unidades.where((unidad) {
          return unidad.codigo.toLowerCase() != 'general';
        }).toList();

        unidadesFiltradas.sort((a, b) => a.codigo.compareTo(b.codigo));

        if (mounted) {
          setState(() {
            _unidadData = unidadesFiltradas;
            _totalItems = unidadesFiltradas.length;
            _currentPage = 1;
            _updateAvailableCodigos();
            _applyPagination();
            _isLoading = false;
          });
        }
      } else {
        print(
            '📊 Modo: Gestión - Cargando planes existentes para $_selectedUbicacion');

        final estatusMap = _estatusMap.map((k, v) => MapEntry(v, k.toString()));

        final planes = await _pmPlanService.getPlanes(
          ubicacion: _selectedUbicacion,
          estadoPlanificacion: _selectedEstadoPlanificacion != null &&
                  _selectedEstadoPlanificacion != 'Todos'
              ? _selectedEstadoPlanificacion
              : null,
          estatus: _selectedEstado != null && _selectedEstado != 'Todos'
              ? estatusMap[_selectedEstado]
              : null,
          busqueda:
              _searchController.text.isNotEmpty ? _searchController.text : null,
        );

        print('✅ Planes obtenidos para $_selectedUbicacion: ${planes.length}');

        final planesFiltrados = planes.where((plan) {
          return plan.unidadCodigo.toLowerCase() != 'general';
        }).toList();

        planesFiltrados
            .sort((a, b) => a.unidadCodigo.compareTo(b.unidadCodigo));

        if (mounted) {
          setState(() {
            _planData = planesFiltrados;
            _totalItems = planesFiltrados.length;
            _currentPage = 1;
            _updateAvailableCodigos();
            _applyPagination();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error al cargar datos para $_selectedUbicacion: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos: $e';
        });
        _showMessage('Error al cargar datos. Por favor intente nuevamente.');
      }
    }
  }

  // Búsqueda
  Future<void> _searchData() async {
    await _loadData();
  }

  // Manejar selección de unidad individual
  void _toggleUnidadSelection(UnidadCultivo unidad, bool? selected) {
    setState(() {
      if (selected == true) {
        if (!_selectedUnidades.contains(unidad)) {
          _selectedUnidades.add(unidad);
        }
      } else {
        _selectedUnidades.remove(unidad);
      }

      _selectAll = _selectedUnidades.length == _sortedData.length;
    });
    _updateEditMode(_selectedUnidades.isNotEmpty);
  }

  // Manejar selección de todas las unidades
  void _toggleSelectAll(bool? selectAll) {
    setState(() {
      _selectAll = selectAll ?? false;
      _selectedUnidades.clear();

      if (_selectAll) {
        _selectedUnidades.addAll(_sortedData.cast<UnidadCultivo>());
      }
    });
    _updateEditMode(_selectedUnidades.isNotEmpty);
  }

  // Crear planes desde unidades seleccionadas
  Future<void> _createPlanesFromSelected() async {
    if (_selectedUnidades.isEmpty) {
      _showMessage('Por favor seleccione al menos una unidad de cultivo');
      return;
    }

    if (_selectedUbicacion == null) {
      _showMessage('Por favor seleccione una ubicación');
      return;
    }

    final unidadesGenerales = _selectedUnidades.where((unidad) {
      return unidad.codigo.toLowerCase() == 'general';
    }).toList();

    if (unidadesGenerales.isNotEmpty) {
      _showMessage(
          'No se pueden crear planes para unidades con código "General"');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _pmPlanService.createPlanesFromUnidades(
        unidades: _selectedUnidades,
        ubicacion: _selectedUbicacion!,
        creadoPor: 1,
      );

      if (success && mounted) {
        _showMessage(
            '${_selectedUnidades.length} planes creados correctamente');
        _clearSelections();
        await _loadData();
        _updateEditMode(false);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al crear planes: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Actualizar estado de planificación
  Future<void> _updatePlanEstado(PmPlan plan, String nuevoEstado) async {
    try {
      final updatedPlan = plan.copyWith(
        estadoPlanificacion: nuevoEstado,
        modificadoPor: 1,
      );

      final success = await _pmPlanService.updatePlan(updatedPlan);

      if (success && mounted) {
        _showMessage('Estado actualizado correctamente');
        await _loadData();
      }
    } catch (e) {
      _showMessage('Error al actualizar estado: $e');
    }
  }

  // ✅ TOGGLE PARA EL PLAN (pmpl_estatus)
  Future<void> _togglePlanEstatus(PmPlan plan) async {
    try {
      final nuevoEstatus = plan.estatus == 1 ? 0 : 1;
      final updatedPlan = plan.copyWith(
        estatus: nuevoEstatus,
        modificadoPor: 1,
      );

      final success = await _pmPlanService.updatePlan(updatedPlan);

      if (success && mounted) {
        _showMessage('Estatus del plan actualizado correctamente');
        await _loadData();
      }
    } catch (e) {
      _showMessage('Error al actualizar estatus del plan: $e');
    }
  }

  // ✅ ZAFACÓN PARA EL INVERNADERO (estatus de unidad)
  Future<void> _toggleInvernaderoEstatus(PmPlan plan) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambio de estatus'),
        content: Text(
          '¿Está seguro que desea cambiar el estatus del invernadero para la unidad ${plan.unidadCodigo}?\n\n'
          'Esto afectará la disponibilidad de la unidad de cultivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final success =
                    await _pmPlanService.updateUnidadEstatusFromPlan(
                  unidadCodigo: plan.unidadCodigo,
                  ubicacion: plan.ubicacion,
                  modificadoPor: 1,
                );

                if (success && mounted) {
                  _showMessage(
                      'Estatus del invernadero actualizado correctamente');
                  await _loadData();
                }
              } catch (e) {
                _showMessage('Error al actualizar estatus del invernadero: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  // ⭐ NUEVO MÉTODO: Mostrar diálogo de crear planes múltiples (VERSIÓN SIMPLE)
  void _showCreateMultiplePlanDialog() async {
    // ⭐ VALIDACIÓN INICIAL
    if (_selectedUbicacion == null || _selectedUbicacion!.isEmpty) {
      _showMessage('Debe seleccionar una ubicación primero');
      return;
    }

    // ⭐ VERIFICAR QUE HAY UNIDADES FILTRADAS
    List<UnidadCultivo> unidadesParaPlanificar = [];

    if (_selectedCodigos.isNotEmpty) {
      // Si hay filtro de códigos, usar solo esas unidades
      unidadesParaPlanificar = _unidadData
          .where((unidad) => _selectedCodigos.contains(unidad.codigo))
          .toList();
    } else {
      // Si no hay filtro, usar todas las unidades visibles
      unidadesParaPlanificar = List.from(_unidadData);
    }

    if (unidadesParaPlanificar.isEmpty) {
      _showMessage(
          'No hay unidades seleccionadas para planificar. Use el filtro por códigos para seleccionar unidades específicas.');
      return;
    }

    // ⭐ CONFIRMAR ACCIÓN CON DIÁLOGO SIMPLE
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.agriculture, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              const Text('Confirmar Creación de Planes'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Desea crear planes para las siguientes unidades en $_selectedUbicacion?',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${unidadesParaPlanificar.length} unidades seleccionadas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Códigos: ${unidadesParaPlanificar.map((u) => u.codigo).take(5).join(', ')}${unidadesParaPlanificar.length > 5 ? '...' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
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
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Crear ${unidadesParaPlanificar.length} Planes'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    // ⭐ CREAR PLANES DIRECTAMENTE
    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _pmPlanService.createPlanesFromUnidades(
        unidades: unidadesParaPlanificar,
        ubicacion: _selectedUbicacion!,
        creadoPor: 1,
      );

      if (success && mounted) {
        _showMessage(
            '${unidadesParaPlanificar.length} planes creados correctamente para $_selectedUbicacion');

        // Limpiar filtros después de crear
        setState(() {
          _selectedCodigos.clear();
        });

        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al crear planes: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Método para mostrar el menú de filtro de códigos
  void _showCodigoFilterMenu() {
    if (_filteredCodigos.isEmpty && _availableCodigos.isNotEmpty) {
      _filteredCodigos = List.from(_availableCodigos);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setMenuState) {
            return AlertDialog(
              // ⭐ TÍTULO HERMOSO
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Seleccionar Invernaderos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: 500,
                height: 600,
                child: Column(
                  children: [
                    // ⭐ HEADER CON INFORMACIÓN Y CONTROLES
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Información
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Seleccione los invernaderos para crear planes en $_selectedUbicacion:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Campo de búsqueda
                          SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _codigoSearchController,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: primaryColor, width: 2),
                                ),
                                hintText: 'Buscar por código...',
                                hintStyle: const TextStyle(fontSize: 14),
                                prefixIcon: Icon(Icons.search,
                                    size: 20, color: Colors.grey.shade600),
                                suffixIcon:
                                    _codigoSearchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear,
                                                size: 18,
                                                color: Colors.grey.shade600),
                                            onPressed: () {
                                              _codigoSearchController.clear();
                                              _filteredCodigos =
                                                  List.from(_availableCodigos);
                                              setMenuState(() {});
                                            },
                                          )
                                        : null,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onChanged: (value) {
                                if (value.isEmpty) {
                                  _filteredCodigos =
                                      List.from(_availableCodigos);
                                } else {
                                  _filteredCodigos = _availableCodigos
                                      .where((codigo) => codigo
                                          .toLowerCase()
                                          .contains(value.toLowerCase()))
                                      .toList();
                                }
                                setMenuState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Controles de selección
                          Row(
                            children: [
                              // Checkbox de seleccionar todo
                              InkWell(
                                onTap: () {
                                  final allSelected = _selectedCodigos.length ==
                                          _filteredCodigos.length &&
                                      _filteredCodigos.isNotEmpty;
                                  if (allSelected) {
                                    for (final codigo in _filteredCodigos) {
                                      _selectedCodigos.remove(codigo);
                                    }
                                  } else {
                                    for (final codigo in _filteredCodigos) {
                                      if (!_selectedCodigos.contains(codigo)) {
                                        _selectedCodigos.add(codigo);
                                      }
                                    }
                                  }
                                  _applyCodigoFilter();
                                  setMenuState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _selectedCodigos
                                                    .where((s) =>
                                                        _filteredCodigos
                                                            .contains(s))
                                                    .isNotEmpty
                                                ? primaryColor
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          color: _selectedCodigos
                                                          .where((s) =>
                                                              _filteredCodigos
                                                                  .contains(s))
                                                          .length ==
                                                      _filteredCodigos.length &&
                                                  _filteredCodigos.isNotEmpty
                                              ? primaryColor
                                              : Colors.transparent,
                                        ),
                                        child: _selectedCodigos
                                                        .where((s) =>
                                                            _filteredCodigos
                                                                .contains(s))
                                                        .length ==
                                                    _filteredCodigos.length &&
                                                _filteredCodigos.isNotEmpty
                                            ? const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : _selectedCodigos
                                                    .where((s) =>
                                                        _filteredCodigos
                                                            .contains(s))
                                                    .isNotEmpty
                                                ? Container(
                                                    margin:
                                                        const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              1),
                                                    ),
                                                  )
                                                : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Seleccionar todos',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // Contador de seleccionados
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: primaryColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  '${_selectedCodigos.length} de ${_availableCodigos.length} seleccionados',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ⭐ LISTA DE CÓDIGOS
                    Expanded(
                      child: _availableCodigos.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay invernaderos disponibles',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _filteredCodigos.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No se encontraron invernaderos que coincidan',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredCodigos.length,
                                  itemBuilder: (context, index) {
                                    final codigo = _filteredCodigos[index];
                                    final isSelected =
                                        _selectedCodigos.contains(codigo);
                                    final unidad = _unidadData.firstWhere(
                                      (u) => u.codigo == codigo,
                                      orElse: () => UnidadCultivo(
                                        secuencia: 0,
                                        codigo: codigo,
                                        cantero: 'N/A',
                                        id: 0,
                                        estatus: 1,
                                      ),
                                    );

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor.withOpacity(0.1)
                                            : Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade200),
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isSelected
                                                  ? primaryColor
                                                  : Colors.grey.shade400,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.transparent,
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        title: Text(
                                          codigo,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Cantero: ${unidad.cantero}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        onTap: () {
                                          if (isSelected) {
                                            _selectedCodigos.remove(codigo);
                                          } else {
                                            _selectedCodigos.add(codigo);
                                          }
                                          _applyCodigoFilter();
                                          setMenuState(() {});
                                        },
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {});
                  },
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Widget para encabezado de tabla
  Widget _buildTableHeader() {
    final columns =
        _currentMode == 'Planificar' ? _unidadColumns : _planColumns;

    return Container(
      color: const Color(0xFFF9F9F9),
      child: Row(
        children: [
          if (_currentMode == 'Planificado')
            Container(
              width: 180,
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(columns.length, (index) {
                  final column = columns[index];
                  return GestureDetector(
                    onTap: column.title != 'Seleccionar'
                        ? () => _sortData(index)
                        : null,
                    child: Container(
                      width: column.width,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                          right: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (column.title == 'Seleccionar')
                            Checkbox(
                              value: _selectAll,
                              onChanged: _toggleSelectAll,
                              activeColor: primaryColor,
                            )
                          else
                            Text(
                              column.title,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          if (column.isSorted && column.title != 'Seleccionar')
                            Icon(
                              column.sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                              color: primaryColor,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para fila de unidad de cultivo (modo planificar)
  Widget _buildUnidadRow(UnidadCultivo unidad) {
    final isSelected = _selectedUnidades.contains(unidad);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_unidadColumns.length, (index) {
                final column = _unidadColumns[index];

                if (column.title == 'Acción') {
                  // ← CAMBIAR de 'Seleccionar' a 'Acción'
                  return Container(
                    width: column.width,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                        right: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.agriculture,
                        size: 20,
                        color: _selectedCodigos.contains(unidad.codigo)
                            ? primaryColor
                            : Colors.grey.shade400,
                      ),
                    ),
                  );
                } else if (column.title == 'Estado Invernadero') {
                  final value = column.valueExtractor(unidad);
                  return Container(
                    width: column.width,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                        right: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                } else {
                  return _buildDataCell(
                    column.valueExtractor(unidad),
                    column.width,
                    backgroundColor: isSelected ? Colors.blue.shade50 : null,
                  );
                }
              }),
            ),
          ),
        ),
      ],
    );
  }

  // Widget para fila de plan (modo planificado)
  Widget _buildPlanRow(PmPlan plan) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Columna de acciones
        Container(
          width: 180,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown para cambiar estado de planificación
              Expanded(
                flex: 2,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: plan.estadoPlanificacion,
                    isExpanded: true,
                    items: _estadosPlanificacion.map((String estado) {
                      return DropdownMenuItem<String>(
                        value: estado,
                        child: Text(
                          estado,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? nuevoEstado) {
                      if (nuevoEstado != null &&
                          nuevoEstado != plan.estadoPlanificacion) {
                        _updatePlanEstado(plan, nuevoEstado);
                      }
                    },
                    icon: Icon(Icons.arrow_drop_down,
                        size: 16, color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // ✅ TOGGLE VERDE/GRIS - PLAN (pmpl_estatus)
              InkWell(
                onTap: () => _togglePlanEstatus(plan),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    plan.estatus == 1 ? Icons.toggle_on : Icons.toggle_off,
                    size: 24,
                    color: plan.estatus == 1 ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // ✅ ZAFACÓN NARANJA - INVERNADERO (estatus de unidad)
              InkWell(
                onTap: () => _toggleInvernaderoEstatus(plan),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Datos del plan
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_planColumns.length, (index) {
                final column = _planColumns[index];
                final value = column.valueExtractor(plan);

                if (column.title == 'Estado Planificación') {
                  Color backgroundColor;
                  Color textColor;
                  Widget? tooltip;

                  switch (plan.estadoPlanificacion) {
                    case 'Planificado':
                      backgroundColor = const Color(0xFFE3F2FD);
                      textColor = const Color(0xFF1976D2);
                      break;
                    case 'En proceso':
                      backgroundColor = const Color(0xFFF3E5F5);
                      textColor = const Color(0xFF7B1FA2);
                      break;
                    case 'Ejecutado':
                      final colors = _getEjecutadoColors(plan.fechaEjecucion);
                      backgroundColor = colors['background']!;
                      textColor = colors['text']!;

                      final timeInfo = _getTimeElapsedInfo(plan.fechaEjecucion);
                      tooltip = Tooltip(
                        message: timeInfo,
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      );
                      break;
                    default:
                      backgroundColor = const Color(0xFFF5F5F5);
                      textColor = const Color(0xFF757575);
                  }

                  return Container(
                    width: column.width,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                        right: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              value,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (tooltip != null) ...[
                            const SizedBox(width: 4),
                            tooltip,
                          ],
                        ],
                      ),
                    ),
                  );
                } else if (column.title == 'Estado Plan') {
                  return Container(
                    width: column.width,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                        right: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                } else {
                  return _buildDataCell(value, column.width);
                }
              }),
            ),
          ),
        ),
      ],
    );
  }

  // Widget para tabs simples
  Widget _buildSimpleTab(String title, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // Widget para celda de datos
  Widget _buildDataCell(String text, double width, {Color? backgroundColor}) {
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Construir vista principal
  Widget _buildMainView() {
    return Container(
      color: lightGrey,
      padding: const EdgeInsets.all(16),
      child: Card(
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
                children: [
                  Row(
                    children: [
                      // 1. Ubicación
                      Expanded(
                        child: _buildFilterDropdown(
                          'Ubicación',
                          _ubicaciones.isEmpty
                              ? 'Cargando ubicaciones...'
                              : 'Seleccione ubicación',
                          _ubicaciones,
                          value: _selectedUbicacion,
                          isLoading: _isLoadingUbicaciones,
                          onChanged: _isLoadingUbicaciones
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedUbicacion = value;
                                    print('📍 Ubicación seleccionada: $value');

                                    // ⭐ LIMPIAR DATOS CUANDO CAMBIA LA UBICACIÓN
                                    if (_currentMode == 'Planificar') {
                                      _unidadData.clear();
                                    } else {
                                      _planData.clear();
                                    }
                                    _currentPage = 1;
                                    _totalItems = 0;
                                    _isLoading = false;
                                    _errorMessage = '';
                                  });

                                  // ⭐ RECARGAR DATOS CON LA NUEVA UBICACIÓN
                                  if (value != null && value.isNotEmpty) {
                                    _loadData();
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Campo de búsqueda para canteros
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Buscar por Cantero',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF505050),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 38,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                  hintText: 'Buscar cantero...',
                                  prefixIcon: Icon(Icons.search,
                                      size: 16, color: Colors.grey.shade600),
                                ),
                                onSubmitted: (_) => _searchData(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 3. Estado
                      Expanded(
                        child: _buildFilterDropdown(
                          'Estado',
                          'Seleccione estado',
                          ['Todos', 'Activo', 'Inactivo'],
                          value: _selectedEstado ?? 'Todos',
                          onChanged: (value) {
                            setState(() {
                              _selectedEstado = value == 'Todos' ? null : value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 4. Filtro de códigos
                      Expanded(
                        child: _buildCodigoFilterWidget(),
                      ),
                    ],
                  ),

                  // Segunda fila solo para modo planificado
                  if (_currentMode == 'Planificado') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            'Estado Planificación',
                            'Seleccione estado',
                            ['Todos', ..._estadosPlanificacion],
                            value: _selectedEstadoPlanificacion ?? 'Todos',
                            onChanged: (value) {
                              setState(() {
                                _selectedEstadoPlanificacion =
                                    value == 'Todos' ? null : value;
                              });
                              _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: Container()),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // Tabla de datos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _buildTableHeader(),
                            _sortedData.isEmpty
                                ? Expanded(
                                    child: Center(
                                      child: Text(
                                        _currentMode == 'Planificar'
                                            ? 'No hay unidades disponibles para planificar'
                                            : 'No hay planes para mostrar',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: _sortedData.map((item) {
                                          if (_currentMode == 'Planificar') {
                                            return _buildUnidadRow(
                                                item as UnidadCultivo);
                                          } else {
                                            return _buildPlanRow(
                                                item as PmPlan);
                                          }
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                            if (_totalItems > _itemsPerPage)
                              PaginationWidget(
                                totalItems: _totalItems,
                                itemsPerPage: _itemsPerPage,
                                currentPage: _currentPage,
                                onPageChanged: _onPageChanged,
                                primaryColor: primaryColor,
                                textColor: const Color(0xFF505050),
                                itemsLabel: _currentMode == 'Planificar'
                                    ? 'unidades'
                                    : 'planes',
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ✅ BARRA DE PESTAÑAS CON BOTONES OPTIMIZADOS
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 0),
            child: Row(
              children: [
                // Tabs a la izquierda
                Row(
                  children: [
                    _buildSimpleTab('Planificar', 0),
                    const SizedBox(width: 24),
                    _buildSimpleTab('Planificado', 1),
                  ],
                ),

                const Spacer(),

                // ⭐ INDICADOR DE UBICACIÓN EN LA BARRA SUPERIOR
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedUbicacion != null
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedUbicacion != null
                          ? Colors.green.shade300
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedUbicacion != null
                            ? Icons.location_on
                            : Icons.location_off,
                        size: 16,
                        color: _selectedUbicacion != null
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedUbicacion != null
                            ? 'Ubicación: $_selectedUbicacion'
                            : 'Sin ubicación seleccionada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedUbicacion != null
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // ✅ BOTONES OPTIMIZADOS
                Row(
                  children: [
                    // Información de selección (solo en modo planificar)
                    if (_currentMode == 'Planificar' &&
                        _selectedUnidades.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${_selectedUnidades.length} seleccionadas',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Botón de búsqueda
                    ElevatedButton.icon(
                      onPressed: _searchData,
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ✅ BOTÓN RECARGAR - SIMPLIFICADO
                    ElevatedButton.icon(
                      onPressed:
                          _isSubmitting ? null : _clearAllFiltersAndReload,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: const Text('Recargar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ✅ BOTÓN ACTUALIZACIÓN MASIVA - SOLO VISIBLE CUANDO HAY FILTROS
                    if (_currentMode == 'Planificado' &&
                        _hasFiltersAppliedOrSelection)
                      ElevatedButton.icon(
                        onPressed:
                            _isSubmitting ? null : _showMassiveUpdateDialog,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.update, size: 16),
                        label: const Text('Actualización Masiva'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),

                    // ✅ BOTÓN NUEVO - MEJORADO CON VALIDACIÓN
                    if (_currentMode == 'Planificar') ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: (_selectedUbicacion == null ||
                                _selectedUbicacion!.isEmpty)
                            ? null
                            : () => _showCreateMultiplePlanDialog(),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          (_selectedUbicacion == null ||
                                  _selectedUbicacion!.isEmpty)
                              ? 'Seleccione Ubicación'
                              : 'Nuevo',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_selectedUbicacion == null ||
                                  _selectedUbicacion!.isEmpty)
                              ? Colors.grey.shade400
                              : accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Línea divisoria
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),

          // Contenido principal
          Expanded(
            child: _buildMainView(),
          ),
        ],
      ),
    );
  }
// ⭐ ESTOS MÉTODOS DEBEN ESTAR DENTRO DE LA CLASE, NO FUERA:

  // Mostrar mensaje
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  // Widget para campo de filtro dropdown
  Widget _buildFilterDropdown(
    String label,
    String hint,
    List<String> options, {
    String? value,
    Function(String?)? onChanged,
    bool isLoading = false,
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
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownButtonHideUnderline(
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
                    icon: Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600),
                  ),
                ),
        ),
      ],
    );
  }

  // FILTRO DE CÓDIGOS
  Widget _buildCodigoFilterWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtro por Códigos',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF505050),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            _showCodigoFilterMenu();
          },
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.filter_list,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCodigos.isEmpty
                          ? 'Todos los códigos'
                          : '${_selectedCodigos.length} seleccionados',
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedCodigos.isEmpty
                            ? Colors.grey.shade600
                            : primaryColor,
                        fontWeight: _selectedCodigos.isEmpty
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedCodigos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_selectedCodigos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _codigoSearchController.dispose();
    _updateEditMode(false);
    super.dispose();
  }
} // ← CIERRE DE LA CLASE _PmPlanManagementScreenState
