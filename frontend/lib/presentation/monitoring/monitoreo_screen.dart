import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/monitoreo_model.dart';
import '../../services/monitoreo_service.dart';
import '../../services/intranet_service.dart';
import '../../services/cache_service.dart';
import '../../services/sincro_service.dart';
import '../../data/datasources/auth_service.dart';
import '../../screens/monitoreo/utils/constants.dart';
import '../../screens/monitoreo/utils/nivel_calculator.dart';
import '../../screens/monitoreo/tabs/consulta_tab.dart';
import '../../screens/monitoreo/tabs/registro_tab.dart';
import '../../screens/monitoreo/widgets/barcode_scanner.dart';
import '../../screens/monitoreo/widgets/monitoreo_details_dialog.dart';
import '../../screens/monitoreo/widgets/sync_status_bar.dart';
import '../../screens/monitoreo/widgets/friendly_error_dialog.dart';
import '../../core/routes/routes_manager.dart';

class MonitoreoScreen extends StatefulWidget {
  // Callback para notificar cambios en el modo de edición
  final Function(bool)? onEditModeChanged;

  const MonitoreoScreen({Key? key, this.onEditModeChanged}) : super(key: key);

  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controladores para los filtros de búsqueda
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fechaInicioController = TextEditingController();
  final TextEditingController _fechaFinController = TextEditingController();

  // Controladores para el formulario de registro
  final TextEditingController _codigoLoteController = TextEditingController();
  final TextEditingController _casaController = TextEditingController();
  final TextEditingController _canteroController = TextEditingController();
  final TextEditingController _responsableController = TextEditingController();
  final TextEditingController _comentariosController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _cantidadBotadaController =
      TextEditingController();

  // Controladores para muestras
  final TextEditingController _muestra1Controller = TextEditingController();
  final TextEditingController _muestra2Controller = TextEditingController();
  final TextEditingController _muestra3Controller = TextEditingController();

  // Datos para los dropdowns
  Map<String, dynamic> casasData = {'data': []};
  Map<String, String> _variedadesIdMap = {};

  // Variables para filtrado
  String? _selectedEstado;
  String? _selectedPlaga;
  // Nuevas variables con nombres modificados para evitar duplicidad
  String? _selectedCasaFiltro;
  String? _selectedCanteroFiltro;
  String? _selectedVariedadFiltro;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Variables para el formulario
  String? _selectedVariedad;
  List<String> _variedades = ['Variedad genérica'];
  Map<String, String> _responsablesPorVariedad = {};
  String? _selectedCasa;
  List<String> _casas = ['Casa genérica'];
  List<String> _plagas = [];

  // Variables para niveles de muestra manual
  String? _selectedNivelMuestra1;
  String? _selectedNivelMuestra2;
  String? _selectedNivelMuestra3;

  // Variables para almacenar valores originales del lote
  String? _loteCanterosOriginal;
  String? _loteContenedorOriginal;

  // Variables para almacenar límites obtenidos del servidor
  int? _limiteNivel1;
  int? _limiteNivel2;
  int? _limiteNivel3;

  // Control de estado
  bool _isManualEntry = false;
  Monitoreo? _currentMonitoreo;
  bool _isEditing = false;
  bool _isCreatingNew = false;
  bool _isPartialSave = false;
  bool _isFilteredByUser = false;
  bool _isInModeFiltrado = false;

  // NUEVAS VARIABLES PARA NAVEGACIÓN
  List<Monitoreo> _navigationData = []; // Lista para navegación
  int _currentNavigationIndex = -1; // Índice actual en la navegación
  String? _partialSaveCantero; // Cantero para restricción en guardado parcial
  String? _partialSaveCasa; // NUEVO: Casa para restricción en guardado parcial
  String? _partialSaveLote; // NUEVO: Lote para restricción en guardado parcial
  String?
      _partialSaveVariedad; // NUEVO: Variedad para restricción en guardado parcial
  DateTime? _partialSaveDay; // NUEVO: Día para restricción en guardado parcial
  bool _isInPartialSaveMode = false; // Bandera para modo guardado parcial

  // Variables para datos de la API
  List<Monitoreo> _monitoreoData = [];
  List<Monitoreo> _filteredMonitoreoData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Variables para paginación
  int _currentPage = 1;
  int _itemsPerPage = 25; // Por defecto 25 elementos por página
  int _totalItems = 0;
  int _totalPages = 1;

  // Variables para ordenamiento
  String? _sortColumn;
  bool _sortAscending = false;
  Map<String, double> _columnWidths = {};

  // Definición de columnas para la tabla
  List<Map<String, dynamic>> _columns = [];

  // Variables para estado de sincronización
  bool _isSyncing = false;
  int _pendingChangesCount = 0;
  String _lastSyncStatus = '';

  // Referencia guardada al servicio de intranet para usar en dispose
  IntranetService? _cachedIntranetService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Inicializar ordenamiento por ID descendente por defecto
    _sortColumn = 'ID';
    _sortAscending = false;

    // Inicializar los nuevos filtros
    _selectedCasaFiltro = null;
    _selectedCanteroFiltro = null;
    _selectedVariedadFiltro = null;

    // Inicializar columnas para la tabla con soporte para ordenamiento
    _columns = [
      {
        'title': 'ID',
        'width': 80.0,
        'valueExtractor': (monitoreo) => monitoreo.pmmo_secuencia.toString(),
        'isNumeric': true,
      },
      {
        'title': 'Lote',
        'width': 120.0,
        'valueExtractor': (monitoreo) => monitoreo.pmlt_codigo ?? '-',
      },
      {
        'title': 'Fecha',
        'width': 120.0,
        'valueExtractor': (monitoreo) => monitoreo.pmmo_fecha != null
            ? DateFormat('dd/MM/yyyy').format(monitoreo.pmmo_fecha!)
            : '-',
      },
      {
        'title': 'Casa',
        'width': 100.0,
        'valueExtractor': (monitoreo) => monitoreo.pmmo_casa ?? '-',
      },
      {
        'title': 'Cantero',
        'width': 100.0,
        'valueExtractor': (monitoreo) => monitoreo.pmmo_cantero ?? '-',
      },
      {
        'title': 'Variedad',
        'width': 150.0,
        'valueExtractor': (monitoreo) =>
            monitoreo.pmmo_variedad ?? monitoreo.pmva_descripcion ?? '-',
      },
      {
        'title': 'Plaga',
        'width': 150.0,
        'valueExtractor': (monitoreo) => monitoreo.pmni_nombrecomun ?? '-',
      },
      {
        'title': 'Cantidad',
        'width': 100.0,
        'valueExtractor': (monitoreo) =>
            monitoreo.pmmo_cantidad?.toString() ?? '-',
        'isNumeric': true,
      },
      {
        'title': 'Nivel M1',
        'width': 80.0,
        'valueExtractor': (monitoreo) =>
            monitoreo.pmmo_nivmuestram1?.toString() ?? '-',
        'isNumeric': true,
      },
      {
        'title': 'Nivel M2',
        'width': 80.0,
        'valueExtractor': (monitoreo) =>
            monitoreo.pmmo_nivmuestram2?.toString() ?? '-',
        'isNumeric': true,
      },
      {
        'title': 'Nivel M3',
        'width': 80.0,
        'valueExtractor': (monitoreo) =>
            monitoreo.pmmo_nivmuestram3?.toString() ?? '-',
        'isNumeric': true,
      },
      {
        'title': 'Estado',
        'width': 100.0,
        'valueExtractor': (monitoreo) {
          // Indicador especial para registros offline
          if (monitoreo.isTemporary() ||
              (monitoreo.isOfflineCreated ?? false)) {
            return 'Pendiente de sincronizar';
          }
          return monitoreo.pmmo_estatus == 1 ? 'Activo' : 'Inactivo';
        },
      },
    ];

    // Escuchar cambios de tab
    _tabController.addListener(() {
      if (mounted && _tabController.index == 0) {
        _clearForm();
      }
    });

    // Cargar datos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Verificar si estamos en modo filtrado por usuario al iniciar
        final authService = Provider.of<AuthService>(context, listen: false);
        setState(() {
          _isFilteredByUser = authService.mustFilterByUser;
          _isInModeFiltrado = authService.isMonitoreador;
        });

        // Añadir columna "Creado por" si el usuario es admin
        if (authService.isAdmin) {
          setState(() {
            _columns.add({
              'title': 'Creado por',
              'width': 120.0,
              'valueExtractor': (monitoreo) =>
                  monitoreo.pmmo_creadopor?.toString() ?? '-',
            });
          });
        }

        // Añadir listener para cambios de conectividad
        _cachedIntranetService =
            Provider.of<IntranetService>(context, listen: false);
        _cachedIntranetService!.isConnected
            .addListener(_handleConnectivityChange);

        // Verificar cambios pendientes al inicio
        _updatePendingChangesCount();

        _loadCasas();
        _loadVariedades();
        _loadNivelesLimites();
        _loadPlagas();
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardar una referencia segura al servicio
    _cachedIntranetService =
        Provider.of<IntranetService>(context, listen: false);
  }

  // NUEVOS MÉTODOS PARA NAVEGACIÓN ENTRE REGISTROS

  // Preparar datos para navegación - CORREGIDO PARA MODO PARCIAL
  void _prepareNavigationData() {
    if (_isInPartialSaveMode && _partialSaveCantero != null) {
      // CORRECCIÓN: En modo guardado parcial, filtrar por cantero + casa + lote + variedad + día
      final DateTime? referenciaDay = _partialSaveDay;

      // Si tenemos día de referencia, filtrar por el mismo día
      if (referenciaDay != null) {
        final DateTime inicioDelDia = DateTime(
            referenciaDay.year, referenciaDay.month, referenciaDay.day);
        final DateTime finDelDia = DateTime(referenciaDay.year,
            referenciaDay.month, referenciaDay.day, 23, 59, 59);

        _navigationData = _monitoreoData
            .where((m) =>
                m.pmmo_cantero == _partialSaveCantero &&
                m.pmmo_casa == _partialSaveCasa &&
                m.pmlt_codigo == _partialSaveLote &&
                m.pmmo_variedad == _partialSaveVariedad &&
                m.pmmo_fecha != null &&
                m.pmmo_fecha!.isAfter(inicioDelDia) &&
                m.pmmo_fecha!.isBefore(finDelDia))
            .toList();
      } else {
        // Si no tenemos día de referencia, usar el día actual
        final DateTime hoy = DateTime.now();
        final DateTime inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
        final DateTime finDelDia =
            DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

        _navigationData = _monitoreoData
            .where((m) =>
                m.pmmo_cantero == _partialSaveCantero &&
                m.pmmo_casa == _partialSaveCasa &&
                m.pmlt_codigo == _partialSaveLote &&
                m.pmmo_variedad == _partialSaveVariedad &&
                m.pmmo_fecha != null &&
                m.pmmo_fecha!.isAfter(inicioDelDia) &&
                m.pmmo_fecha!.isBefore(finDelDia))
            .toList();
      }
    } else {
      // Si estamos en modo edición normal, usar todos los datos
      _navigationData = List.from(_monitoreoData);
    }

    // Ordenar por ID para mantener consistencia
    _navigationData.sort(
        (a, b) => (a.pmmo_secuencia ?? 0).compareTo(b.pmmo_secuencia ?? 0));
  }

  // Navegar al siguiente registro
  void _navigateNext() {
    if (_navigationData.isEmpty) return;

    int nextIndex = _currentNavigationIndex + 1;
    if (nextIndex >= _navigationData.length) {
      _showMessage('Ya está en el último registro');
      return;
    }

    _navigateToIndex(nextIndex);
  }

  // Navegar al registro anterior
  void _navigatePrevious() {
    if (_navigationData.isEmpty) return;

    int prevIndex = _currentNavigationIndex - 1;
    if (prevIndex < 0) {
      _showMessage('Ya está en el primer registro');
      return;
    }

    _navigateToIndex(prevIndex);
  }

  // Navegar a un índice específico
  void _navigateToIndex(int index) {
    if (index < 0 || index >= _navigationData.length) return;

    setState(() {
      _currentNavigationIndex = index;
    });

    final monitoreo = _navigationData[index];
    _editMonitoreo(monitoreo, fromNavigation: true);
  }

  // Obtener información de navegación para mostrar al usuario - MEJORADO
  String _getNavigationInfo() {
    if (_navigationData.isEmpty) return '';

    final current = _currentNavigationIndex + 1;
    final total = _navigationData.length;

    if (_isInPartialSaveMode && _partialSaveCantero != null) {
      // Mostrar información más específica para modo parcial
      return 'Casa $_partialSaveCasa, Cantero $_partialSaveCantero: $current de $total';
    } else {
      return 'Registro $current de $total';
    }
  }

  // Verificar si puede navegar hacia adelante
  bool _canNavigateNext() {
    return _navigationData.isNotEmpty &&
        _currentNavigationIndex < _navigationData.length - 1;
  }

  // Verificar si puede navegar hacia atrás
  bool _canNavigatePrevious() {
    return _navigationData.isNotEmpty && _currentNavigationIndex > 0;
  }

  // Método para cerrar sesión
  void _logout() {
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
                RoutesManager.login,
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

  // Método para actualizar el contador de cambios pendientes
  Future<void> _updatePendingChangesCount() async {
    if (!mounted) return;

    final cacheService = Provider.of<CacheService>(context, listen: false);
    final pendingChanges =
        await cacheService.loadData('pending_monitoreos') ?? [];

    setState(() {
      _pendingChangesCount = pendingChanges is List ? pendingChanges.length : 0;
    });
  }

  // Manejar cambios de conectividad
  void _handleConnectivityChange() async {
    if (!mounted) return;

    final intranetService = _cachedIntranetService;
    if (intranetService == null) return;

    // Si recuperamos conexión y hay cambios pendientes, preguntar si sincronizar
    if (intranetService.isConnected.value && _pendingChangesCount > 0) {
      // Actualizar UI primero
      setState(() {});

      // Mostrar diálogo preguntando si sincronizar
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Conexión restablecida'),
            content: Text(
                'Se detectaron $_pendingChangesCount cambios pendientes. ¿Desea sincronizar ahora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Más tarde'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _sincronizarCambiosPendientes();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  foregroundColor: const Color.fromARGB(255, 94, 94, 94),
                ),
                child: const Text('Sincronizar ahora'),
              ),
            ],
          ),
        );
      }
    } else {
      // Simplemente actualizar la UI para reflejar el cambio de estado
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Sincronizar cambios pendientes
  Future<void> _sincronizarCambiosPendientes() async {
    if (!mounted) return;

    final intranetService = _cachedIntranetService;
    if (intranetService == null) return;

    // Solo sincronizar si hay conexión
    if (!intranetService.isConnected.value) {
      _showMessage(
          'No hay conexión a la intranet. No se pueden sincronizar cambios.');
      return;
    }

    // Actualizar estado para mostrar progreso
    setState(() {
      _isSyncing = true;
      _lastSyncStatus = 'Iniciando sincronización...';
    });

    try {
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);

      // Obtener cambios pendientes
      final cachedPending = await cacheService.loadData('pending_monitoreos');
      if (cachedPending == null ||
          !(cachedPending is List) ||
          cachedPending.isEmpty) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = 'No hay cambios pendientes';
        });
        return;
      }

      List<dynamic> pendingChanges = cachedPending as List;
      List<dynamic> failedChanges = [];
      int successCount = 0;

      // Actualizar estado de sincronización
      setState(() {
        _lastSyncStatus = 'Sincronizando ${pendingChanges.length} cambios...';
      });

      // Procesar cada cambio pendiente
      for (final change in pendingChanges) {
        try {
          final operation = change['operation'];
          final monitoreoJson = change['monitoreo'];
          final monitoreo = Monitoreo.fromJson(monitoreoJson);

          if (operation == 'create') {
            // Si tiene ID temporal negativo, crear nuevo sin ID
            if (monitoreo.isTemporary()) {
              // Crear copia sin ID para que el servidor asigne uno nuevo
              final nuevoMonitoreo = monitoreo.copyWith(
                pmmo_secuencia: null,
                isOfflineCreated: false,
                offlineModifiedAt: null,
              );
              await monitoreoService.crearMonitoreo(nuevoMonitoreo);
            } else {
              await monitoreoService.crearMonitoreo(monitoreo);
            }
            successCount++;
          } else if (operation == 'update') {
            // Si tiene ID temporal, crearlo como nuevo en lugar de actualizarlo
            if (monitoreo.isTemporary()) {
              final nuevoMonitoreo = monitoreo.copyWith(
                pmmo_secuencia: null,
                isOfflineCreated: false,
                offlineModifiedAt: null,
              );
              await monitoreoService.crearMonitoreo(nuevoMonitoreo);
            } else {
              await monitoreoService.actualizarMonitoreo(monitoreo);
            }
            successCount++;
          } else if (operation == 'delete') {
            // Solo eliminar si tiene ID positivo (existe en el servidor)
            if (!monitoreo.isTemporary()) {
              await monitoreoService
                  .eliminarMonitoreo(monitoreo.pmmo_secuencia!);
            }
            successCount++;
          }

          // Actualizar estado de progreso cada 5 operaciones
          if (successCount % 5 == 0 && mounted) {
            setState(() {
              _lastSyncStatus =
                  'Sincronizando... $successCount/${pendingChanges.length}';
            });
          }
        } catch (e) {
          print('Error al sincronizar cambio: $e');
          failedChanges.add(change);
        }
      }

      // Guardar sólo los cambios que fallaron
      await cacheService.saveData('pending_monitoreos', failedChanges);

      // Actualizar contador de cambios pendientes
      await _updatePendingChangesCount();

      // Recargar datos desde el servidor
      await _loadData();

      // Actualizar estado final
      if (mounted) {
        setState(() {
          _isSyncing = false;
          if (failedChanges.isEmpty) {
            _lastSyncStatus = 'Sincronización completa: $successCount cambios';
          } else {
            _lastSyncStatus =
                'Sincronización parcial: $successCount de ${pendingChanges.length} cambios';
          }
        });
      }

      // Mostrar mensaje de resumen
      if (failedChanges.isEmpty && mounted) {
        _showMessage('Sincronización completada correctamente');
      } else if (mounted) {
        _showMessage(
            'Sincronización parcial: ${pendingChanges.length - failedChanges.length} de ${pendingChanges.length} cambios completados');
      }
    } catch (e) {
      print('Error durante la sincronización: $e');

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = 'Error: $e';
        });
        _showMessage('Error durante la sincronización: $e');
      }
    }
  }

  // Método para ordenar los datos
  void _handleSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;

      // Encontrar la columna por el título
      final Map<String, dynamic>? columnDef = _columns.firstWhere(
        (col) => col['title'] == column,
        orElse: () => <String, dynamic>{},
      );

      if (columnDef != null &&
          columnDef.containsKey('valueExtractor') &&
          columnDef['valueExtractor'] != null) {
        final valueExtractor = columnDef['valueExtractor'] as Function;
        final isNumeric = columnDef['isNumeric'] == true;

        // Ordenar los datos según el tipo de columna
        _filteredMonitoreoData.sort((a, b) {
          var aValue = valueExtractor(a);
          var bValue = valueExtractor(b);

          // Manejar valores numéricos
          if (isNumeric) {
            final aNum = int.tryParse(aValue) ?? 0;
            final bNum = int.tryParse(bValue) ?? 0;
            return ascending ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
          }

          // Manejar valores de texto
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        });
      }
    });
  }

  // Método para redimensionar columnas
  void _handleColumnResize(String columnTitle, double newWidth) {
    if (mounted) {
      setState(() {
        _columnWidths[columnTitle] = newWidth;

        // Actualizar el ancho en la definición de columnas
        for (var column in _columns) {
          if (column['title'] == columnTitle) {
            column['width'] = newWidth;
            break;
          }
        }
      });
    }
  }

  // Método para exportar a Excel
  Future<void> _exportToExcel(String fileName, bool onlyFiltered) async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);

      // Determinar qué datos exportar
      final List<Monitoreo> dataToExport =
          onlyFiltered ? _filteredMonitoreoData : _monitoreoData;

      // Llamar al servicio para exportar
      final success = await monitoreoService.exportarMonitoreosExcel(
        dataToExport,
        fileName,
        _columns,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          _showMessage('Datos exportados correctamente a Excel.');
        } else {
          _showMessage('Error al exportar datos a Excel.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessage('Error en la exportación: $e');
      }
    }
  }

  // Método para cambiar de página
  void _handlePageChange(int page) {
    if (page > 0 && page <= _totalPages && mounted) {
      setState(() {
        _currentPage = page;
        _applyPagination();
      });
    }
  }

  // Método para aplicar paginación
  void _applyPagination() {
    if (!mounted) return;

    // Calcular total de páginas
    _totalItems = _monitoreoData.length;
    _totalPages = (_totalItems / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1; // Asegurar al menos una página

    // Ajustar página actual si es necesario
    if (_currentPage > _totalPages && _totalPages > 0) {
      _currentPage = _totalPages;
    }

    // Aplicar el ordenamiento antes de la paginación
    if (_sortColumn != null) {
      final Map<String, dynamic>? columnDef = _columns.firstWhere(
        (col) => col['title'] == _sortColumn,
        orElse: () => <String, dynamic>{},
      );

      if (columnDef != null &&
          columnDef.containsKey('valueExtractor') &&
          columnDef['valueExtractor'] != null) {
        final valueExtractor = columnDef['valueExtractor'] as Function;
        final isNumeric = columnDef['isNumeric'] == true;

        _monitoreoData.sort((a, b) {
          var aValue = valueExtractor(a);
          var bValue = valueExtractor(b);

          if (isNumeric) {
            final aNum = int.tryParse(aValue) ?? 0;
            final bNum = int.tryParse(bValue) ?? 0;
            return _sortAscending ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
          }

          return _sortAscending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        });
      }
    }

    // Calcular índices para la paginación
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > _totalItems) {
      endIndex = _totalItems;
    }

    // Obtener datos de la página actual
    if (_monitoreoData.isNotEmpty && startIndex < _monitoreoData.length) {
      _filteredMonitoreoData = _monitoreoData.sublist(
        startIndex,
        endIndex < _monitoreoData.length ? endIndex : _monitoreoData.length,
      );
    } else {
      _filteredMonitoreoData = [];
    }
  }

  // Método para cambiar elementos por página
  void _handleItemsPerPageChange(int newItemsPerPage) {
    if (mounted) {
      setState(() {
        _itemsPerPage = newItemsPerPage;
        _currentPage = 1; // Volver a la primera página
        _applyPagination();
      });
    }
  }

  // Método para mostrar mensajes de manera segura
  void _showMessage(String message) {
    if (!mounted) return;

    // Usar un postFrameCallback para asegurar que no estamos en medio de una actualización
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          debugPrint('Error al mostrar mensaje: $e');
        }
      }
    });
  }

  // Método para cargar información de plagas
  Future<void> _loadInfoPlagaAction(String nombrePlaga) async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final nivelesData = await monitoreoService.getNivelesPlaga(nombrePlaga);

      if (mounted && nivelesData.isNotEmpty) {
        setState(() {
          _limiteNivel1 = nivelesData['lmsupniv1'] ?? 10;
          _limiteNivel2 = nivelesData['lmsupniv2'] ?? 20;
          _limiteNivel3 = nivelesData['lmsupniv3'] ?? 30;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar info de plaga: $e');
      _loadNivelesLimites();
    }
  }

  // Método para obtener un código de lote existente
  String _getDefaultLoteCode() {
    return "15207"; // Reemplazar con un código real existente
  }

  // Método para cargar las variedades disponibles
  Future<void> _loadVariedades() async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      Map<String, dynamic> variedadesData;

      // Verificar si hay conexión a la intranet
      if (intranetService.isConnected.value) {
        // Obtener las variedades desde el servidor
        variedadesData =
            await monitoreoService.getDatosAuxiliares('variedades');

        // Guardar en caché
        await cacheService.saveData('variedades_data', variedadesData);
      } else {
        // Intentar cargar desde caché
        final cachedData = await cacheService.loadData('variedades_data');
        if (cachedData != null) {
          variedadesData = cachedData;
          print('Variedades cargadas desde caché');
        } else {
          // Si no hay datos en caché, usar un conjunto de datos mínimo
          variedadesData = {
            'data': [
              {
                'descripcion': 'Variedad genérica',
                'id': '0',
                'responsable': 'Responsable genérico'
              }
            ]
          };
          print('No hay variedades en caché, usando datos por defecto');
        }
      }

      if (mounted && variedadesData['data'] != null) {
        // Asegurar que data es una lista antes de continuar
        if (variedadesData['data'] is List) {
          final List<dynamic> variedadesList = variedadesData['data'];

          // Crear un mapa temporal para almacenar los responsables por variedad
          Map<String, String> nuevoMapa = {};
          Map<String, String> nuevoMapaIds =
              {}; // Para mapear descripción -> id

          setState(() {
            // Mantener "Variedad genérica" y añadir las demás
            _variedades = ['Variedad genérica'];

            // Añadir las variedades del servidor y mapear responsables
            for (var variedad in variedadesList) {
              if (variedad is Map && variedad['descripcion'] != null) {
                String descripcion = variedad['descripcion'];
                if (!_variedades.contains(descripcion)) {
                  _variedades.add(descripcion);
                }

                // Guardar el responsable en el mapa si existe
                if (variedad['responsable'] != null) {
                  nuevoMapa[descripcion] = variedad['responsable'];
                }

                // Guardar el ID correspondiente a esta descripción
                if (variedad['id'] != null) {
                  nuevoMapaIds[descripcion] = variedad['id'].toString();
                }
              }
            }

            // Actualizar los mapas
            _responsablesPorVariedad = nuevoMapa;
            _variedadesIdMap = nuevoMapaIds; // Guardar el mapa de IDs
          });
        } else {
          debugPrint(
              'El campo data no es una lista: ${variedadesData['data']}');
        }
      }
    } catch (e) {
      debugPrint('Error al cargar variedades: $e');
      if (mounted) {
        setState(() {
          // Asegurar que al menos tenemos la variedad genérica
          _variedades = ['Variedad genérica'];
        });
      }
    }
  }

  // Método para obtener el ID de la variedad a partir de la descripción
  String _obtenerIdVariedad(String? descripcionVariedad) {
    if (descripcionVariedad == null) return '';
    if (descripcionVariedad == 'Variedad genérica')
      return '0'; // ID por defecto

    return _variedadesIdMap[descripcionVariedad] ?? '';
  }

  // Método para cargar las casas disponibles
  Future<void> _loadCasas() async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      Map<String, dynamic> response;

      if (intranetService.isConnected.value) {
        // Cargar desde la API
        response = await monitoreoService.getDatosAuxiliares('casas');

        // Guardar en caché
        await cacheService.saveData('casas_data', response);
      } else {
        // Cargar desde caché
        final cachedData = await cacheService.loadData('casas_data');
        if (cachedData != null) {
          response = cachedData;
          print('Casas cargadas desde caché');
        } else {
          // Datos por defecto si no hay caché
          response = {
            'data': [
              {'codigo': 'Casa genérica'}
            ]
          };
          print('No hay casas en caché, usando datos por defecto');
        }
      }

      if (mounted && response['data'] != null && response['data'] is List) {
        setState(() {
          // Actualizar casasData antes de usarlo en _loadVariedades
          casasData = response;

          // Inicializar la lista con la opción genérica
          _casas = ['Casa genérica'];

          // Añadir las casas desde la respuesta
          for (var casa in response['data']) {
            if (casa is Map && casa['codigo'] != null) {
              String codigo = casa['codigo'].toString();
              if (!_casas.contains(codigo)) {
                _casas.add(codigo);
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar casas: $e');
      setState(() {
        _casas = [
          'Casa genérica'
        ]; // Mantener la opción por defecto en caso de error
      });
    }
  }

  // Método para cargar plagas activas
  Future<void> _loadPlagas() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<String> plagasNombres = [];

      if (intranetService.isConnected.value) {
        // Usar el método que devuelve directamente los nombres de plagas desde la API
        plagasNombres = await monitoreoService.getPlagasActivasNombres();

        // Guardar en caché
        await cacheService.saveData('plagas_nombres', plagasNombres);
      } else {
        // Intentar cargar desde caché
        final cachedData = await cacheService.loadData('plagas_nombres');
        if (cachedData != null && cachedData is List) {
          plagasNombres = List<String>.from(cachedData);
          print('Plagas cargadas desde caché: ${plagasNombres.length}');
        } else {
          // Si no hay datos en caché, usar plaga genérica
          plagasNombres = ['Plaga genérica'];
          print('No hay plagas en caché, usando plaga genérica');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _plagas = plagasNombres;

          // Imprimir para depuración
          print('Plagas cargadas: ${_plagas.length}');
          if (_plagas.isNotEmpty) {
            print('Plagas: ${_plagas.join(", ")}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _plagas = [
            'Plaga genérica'
          ]; // Usar una plaga genérica en caso de error
          print('Error al cargar plagas, usando plaga genérica: $e');
        });
      }
    }
  }

  // Método para cargar límites de niveles de plagas
  Future<void> _loadNivelesLimites() async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      Map<String, dynamic> nivelesData;

      if (intranetService.isConnected.value) {
        // Obtener los niveles desde el servidor
        nivelesData = await monitoreoService.getDatosAuxiliares('niveles');

        // Guardar en caché
        await cacheService.saveData('niveles_limites', nivelesData);
      } else {
        // Intentar cargar desde caché
        final cachedData = await cacheService.loadData('niveles_limites');
        if (cachedData != null) {
          nivelesData = cachedData;
          print('Niveles límites cargados desde caché');
        } else {
          // Si no hay datos en caché, usar valores por defecto
          nivelesData = {
            'data': {'lmsupniv1': 10, 'lmsupniv2': 20, 'lmsupniv3': 30}
          };
          print('No hay niveles límites en caché, usando valores por defecto');
        }
      }

      if (mounted && nivelesData['data'] != null) {
        // Asumir que se recibe una estructura con los límites
        setState(() {
          _limiteNivel1 = nivelesData['data']['lmsupniv1'] ??
              10; // Valores por defecto como ejemplo
          _limiteNivel2 = nivelesData['data']['lmsupniv2'] ?? 20;
          _limiteNivel3 = nivelesData['data']['lmsupniv3'] ?? 30;
        });
      }
    } catch (e) {
      print('Error al cargar niveles: $e');
      // Mantener valores predeterminados en caso de error
    }
  }

  // Método para notificar el cambio en el modo de edición de manera segura
  void _updateEditMode(bool isEditing) {
    if (widget.onEditModeChanged != null && mounted) {
      if (WidgetsBinding.instance.schedulerPhase !=
          SchedulerPhase.persistentCallbacks) {
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onEditModeChanged!(isEditing);
            }
          });
        } catch (e) {
          print('Ignorando actualización de modo de edición: $e');
        }
      }
    }
  }

  // Método para obtener canteros únicos de los monitoreos
  List<String> _obtenerListaCanteros() {
    Set<String> canteros = Set<String>();

    // Agregar una opción por defecto
    canteros.add('Todos');

    // Extraer valores únicos de cantero de los monitoreos
    for (var monitoreo in _monitoreoData) {
      if (monitoreo.pmmo_cantero != null &&
          monitoreo.pmmo_cantero!.isNotEmpty &&
          monitoreo.pmmo_cantero != 'Todos') {
        canteros.add(monitoreo.pmmo_cantero!);
      }
    }

    // Convertir a lista ordenada
    List<String> resultado = canteros.toList();
    resultado.sort((a, b) => a == 'Todos'
        ? -1
        : b == 'Todos'
            ? 1
            : a.compareTo(b));

    return resultado;
  }

  // Cargar datos de monitoreos desde la API o caché
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Obtener servicios usando Provider
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      final authService = Provider.of<AuthService>(context, listen: false);

      List<Monitoreo> monitoreos = [];

      // Verificar si hay conexión a la intranet
      if (intranetService.isConnected.value) {
        try {
          // Si hay conexión, cargar desde la API
          monitoreos = await monitoreoService.getMonitoreos();

          // Guardar en caché para uso offline
          await cacheService.saveData(
              'monitoreos_data', monitoreos.map((m) => m.toJson()).toList());
          await cacheService.saveData(
              'last_online_sync', DateTime.now().toIso8601String());

          print(
              'Datos cargados desde API y guardados en caché: ${monitoreos.length} registros');
        } catch (e) {
          print('Error al cargar datos desde la API: $e');
          // En caso de error con la API, intentar usar caché como fallback
          final cachedData = await cacheService.loadData('monitoreos_data');

          if (cachedData != null && cachedData is List) {
            monitoreos = cachedData
                .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                .toList();
            print(
                'Error de API, usando datos de caché como fallback: ${monitoreos.length} registros');
          }
        }
      } else {
        // Si no hay conexión, intentar cargar desde caché
        final cachedData = await cacheService.loadData('monitoreos_data');

        if (cachedData != null && cachedData is List) {
          monitoreos = cachedData
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();

          // Cargar la última fecha de sincronización para informar al usuario
          final lastSyncStr = await cacheService.loadData('last_online_sync');
          String offlineMessage = 'Mostrando datos almacenados localmente.';

          if (lastSyncStr != null) {
            final lastSync = DateTime.parse(lastSyncStr);
            final now = DateTime.now();
            final difference = now.difference(lastSync);

            if (difference.inDays > 0) {
              offlineMessage +=
                  ' Última sincronización: hace ${difference.inDays} días';
            } else if (difference.inHours > 0) {
              offlineMessage +=
                  ' Última sincronización: hace ${difference.inHours} horas';
            } else {
              offlineMessage +=
                  ' Última sincronización: hace ${difference.inMinutes} minutos';
            }
          }

          // Mostrar mensaje de modo offline
          _showMessage(offlineMessage);
          print('Datos cargados desde caché: ${monitoreos.length} registros');
        } else {
          print('No hay datos en caché');
          _showMessage(
              'No hay datos disponibles en modo sin conexión. Conéctese a la intranet para cargar datos.');
        }
      }

      // Si está habilitado el filtrado por usuario, aplicarlo
      if (authService.mustFilterByUser &&
          authService.getCurrentUserId() != null) {
        final userId = authService.getCurrentUserId();
        monitoreos =
            monitoreos.where((m) => m.pmmo_creadopor == userId).toList();
        print('Filtrando por usuario $userId: ${monitoreos.length} registros');
      }

      // Actualizar estado
      if (mounted) {
        setState(() {
          _monitoreoData = monitoreos;
          _currentPage = 1; // Resetear a primera página
          _applyPagination(); // Aplicar paginación para obtener los elementos filtrados
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos: $e';
        });
        _showMessage('Error al cargar datos: $e');
      }
    }
  }

  // Método para buscar monitoreos con filtros
  Future<void> _searchMonitoreos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Convertir estado a valor numérico
      int? estatus;
      if (_selectedEstado == 'Activo') {
        estatus = 1;
      } else if (_selectedEstado == 'Inactivo') {
        estatus = 0;
      }

      // Obtener servicios mediante Provider
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<Monitoreo> monitoreos = [];

      // Verificar si hay conexión a la intranet
      if (intranetService.isConnected.value) {
        // Si hay conexión, buscar desde la API
        monitoreos = await monitoreoService.getMonitoreos(
          lote: _searchController.text,
          plaga: _selectedPlaga,
          casa: _selectedCasaFiltro, // Modificado
          cantero: _selectedCanteroFiltro, // Modificado
          variedad: _selectedVariedadFiltro, // Modificado
          estatus: estatus,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
        );

        // Guardar resultados de búsqueda en caché
        final searchParams = {
          'lote': _searchController.text,
          'plaga': _selectedPlaga,
          'casa': _selectedCasaFiltro, // Modificado
          'cantero': _selectedCanteroFiltro, // Modificado
          'variedad': _selectedVariedadFiltro, // Modificado
          'estatus': estatus,
          'fechaInicio': _fechaInicio?.toIso8601String(),
          'fechaFin': _fechaFin?.toIso8601String(),
        };

        // Guardar los parámetros y resultados
        await cacheService.saveData('last_search_params', searchParams);
        await cacheService.saveData(
            'last_search_results', monitoreos.map((m) => m.toJson()).toList());

        print('Búsqueda realizada desde API: ${monitoreos.length} resultados');
      } else {
        // Si no hay conexión, intentar usar resultados de búsqueda en caché
        final cachedParams = await cacheService.loadData('last_search_params');
        final cachedResults =
            await cacheService.loadData('last_search_results');

        if (cachedResults != null && cachedResults is List) {
          monitoreos = cachedResults
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();

          // Opcional: Aplicar filtros manualmente a los datos en caché
          // para aproximar los resultados que la API habría devuelto
          monitoreos = monitoreos.where((m) {
            bool match = true;

            // Filtrar por lote
            if (_searchController.text.isNotEmpty) {
              match = match &&
                  (m.pmlt_codigo?.contains(_searchController.text) ?? false);
            }

            // Filtrar por plaga
            if (_selectedPlaga != null && _selectedPlaga!.isNotEmpty) {
              match = match && (m.pmni_nombrecomun == _selectedPlaga);
            }

            // Filtrar por casa (modificado)
            if (_selectedCasaFiltro != null &&
                _selectedCasaFiltro!.isNotEmpty &&
                _selectedCasaFiltro != 'Todas') {
              match = match && (m.pmmo_casa == _selectedCasaFiltro);
            }

            // Filtrar por cantero (modificado)
            if (_selectedCanteroFiltro != null &&
                _selectedCanteroFiltro!.isNotEmpty &&
                _selectedCanteroFiltro != 'Todos') {
              match = match && (m.pmmo_cantero == _selectedCanteroFiltro);
            }

            // Filtrar por variedad (modificado)
            if (_selectedVariedadFiltro != null &&
                _selectedVariedadFiltro!.isNotEmpty &&
                _selectedVariedadFiltro != 'Todas') {
              match = match &&
                  ((m.pmmo_variedad == _selectedVariedadFiltro) ||
                      (m.pmva_descripcion == _selectedVariedadFiltro));
            }

            // Filtrar por estado
            if (estatus != null) {
              match = match && (m.pmmo_estatus == estatus);
            }

            // Filtrar por fechas (simplificado)
            if (_fechaInicio != null && m.pmmo_fecha != null) {
              match = match && !m.pmmo_fecha!.isBefore(_fechaInicio!);
            }
            if (_fechaFin != null && m.pmmo_fecha != null) {
              match = match && !m.pmmo_fecha!.isAfter(_fechaFin!);
            }

            return match;
          }).toList();

          print(
              'Búsqueda aplicada a datos en caché: ${monitoreos.length} resultados');
        } else {
          // Si no hay resultados en caché, mostrar mensaje
          print('No hay resultados de búsqueda en caché');
        }
      }

      if (mounted) {
        setState(() {
          _monitoreoData = monitoreos;
          _currentPage = 1; // Resetear a primera página al buscar
          _applyPagination(); // Aplicar paginación a los resultados
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al buscar monitoreos: $e';
        });
        _showMessage('Error al buscar monitoreos: $e');
      }
    }
  }

  @override
  void dispose() {
    // Usar la referencia almacenada para quitar listeners
    if (_cachedIntranetService != null) {
      _cachedIntranetService!.isConnected
          .removeListener(_handleConnectivityChange);
    }

    // Liberar controladores
    _tabController.dispose();
    _searchController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    _codigoLoteController.dispose();
    _casaController.dispose();
    _canteroController.dispose();
    _responsableController.dispose();
    _comentariosController.dispose();
    _cantidadController.dispose();
    _cantidadBotadaController.dispose();
    _muestra1Controller.dispose();
    _muestra2Controller.dispose();
    _muestra3Controller.dispose();

    super.dispose();
  }

  // Limpiar el formulario completo
  void _clearForm() {
    if (!mounted) return;

    // Limpiar controladores existentes
    _codigoLoteController.clear();
    _casaController.clear();
    _canteroController.clear();
    _responsableController.clear();
    _comentariosController.clear();
    _cantidadController.clear();
    _cantidadBotadaController.clear();

    // Limpiar nuevos controladores
    _muestra1Controller.clear();
    _muestra2Controller.clear();
    _muestra3Controller.clear();

    // Actualizar estado
    if (mounted) {
      try {
        setState(() {
          _selectedVariedad = null;
          _selectedPlaga = null;
          _currentMonitoreo = null;
          _isEditing = false;
          _isCreatingNew = false;
          _isManualEntry = false;
          _errorMessage = '';
          _loteCanterosOriginal = null; // Limpiar valor original de canteros

          // Solo limpiar el contenedor cuando realmente sea necesario
          if (!_isEditing) {
            _loteContenedorOriginal =
                null; // Limpiar valor original de contenedor
            print('Contenedor limpiado en _clearForm()');
          }

          // Resetear niveles de muestra manual
          _selectedNivelMuestra1 = null;
          _selectedNivelMuestra2 = null;
          _selectedNivelMuestra3 = null;

          // Establecer valores por defecto para cantidad observada
          _cantidadController.text = '0';

          // NUEVO: Limpiar variables de navegación y modo parcial
          _navigationData.clear();
          _currentNavigationIndex = -1;
          _partialSaveCantero = null;
          _partialSaveCasa = null;
          _partialSaveLote = null;
          _partialSaveVariedad = null;
          _partialSaveDay = null;
          _isInPartialSaveMode = false;
        });

        if (mounted &&
            WidgetsBinding.instance.schedulerPhase !=
                SchedulerPhase.persistentCallbacks) {
          _updateEditMode(false);
        }
      } catch (e) {
        print('Error al limpiar formulario: $e');
      }
    }
  }

  // Limpiar solo los datos de monitoreo, manteniendo los datos del lote
  void _clearMonitoreoData() {
    if (!mounted) return;

    // Limpiar solo los controladores relacionados con el monitoreo
    _comentariosController.clear();
    _cantidadController.clear();
    _cantidadBotadaController.clear();
    _muestra1Controller.clear();
    _muestra2Controller.clear();
    _muestra3Controller.clear();

    // Actualizar estado
    if (mounted) {
      setState(() {
        _selectedPlaga = null;
        _currentMonitoreo = null;
        _errorMessage = '';

        // Resetear niveles de muestra manual
        _selectedNivelMuestra1 = null;
        _selectedNivelMuestra2 = null;
        _selectedNivelMuestra3 = null;

        // Establecer valores por defecto para cantidad observada
        _cantidadController.text = '0';
      });
    }
  }

  // Método para iniciar la creación de un nuevo monitoreo - CON VALIDACIÓN DE SESIÓN
  void _nuevoMonitoreo() {
    // Verificar que hay una sesión válida antes de crear monitoreo
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isAuthenticated) {
      FriendlyErrorDialog.show(
        context,
        title: 'Sesión expirada',
        message: 'Su sesión ha expirado. Por favor inicie sesión nuevamente.',
        actionText: 'Ir a login',
        onAction: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            RoutesManager.login,
            (route) => false,
          );
        },
        icon: Icons.logout,
        iconColor: Colors.red,
      );
      return;
    }

    final userId = authService.getCurrentUserId();
    if (userId == null || userId == 1) {
      FriendlyErrorDialog.show(
        context,
        title: 'Usuario no válido',
        message:
            'No se puede crear el monitoreo con el usuario actual. Por favor inicie sesión nuevamente.',
        actionText: 'Ir a login',
        onAction: () {
          // Limpiar sesión y redirigir
          authService.logout();
          Navigator.of(context).pushNamedAndRemoveUntil(
            RoutesManager.login,
            (route) => false,
          );
        },
        icon: Icons.person_off,
        iconColor: Colors.orange,
      );
      return;
    }

    // Si llegamos aquí, la sesión es válida, proceder normalmente
    _clearForm();
    if (!mounted) return;

    setState(() {
      _isCreatingNew = true;
      _isEditing = true;
      _isManualEntry = false;

      // Inicializar con valor por defecto
      _cantidadController.text = '0';

      // Establecer un contenedor por defecto para nuevo monitoreo
      _loteContenedorOriginal = 'CONT_GENERAL';
      print(
          'Creando nuevo monitoreo con contenedor por defecto: $_loteContenedorOriginal');
    });

    // Cambiar a la pestaña de registro
    _tabController.animateTo(1);

    // Notificar que estamos en modo edición
    _updateEditMode(true);
  }

  // Método para escanear código de barras - MEJORADO
  Future<void> _scanBarcode() async {
    final String? scannedCode = await BarcodeScanner.scanBarcode(context);

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      setState(() {
        _codigoLoteController.text = scannedCode;
        _isManualEntry = false;
        _errorMessage = ''; // Limpiar errores previos
      });

      // Mostrar indicador de carga mientras se valida el lote
      setState(() {
        _isLoading = true;
      });

      // Cargar datos del lote y manejar errores específicos
      await _loadLoteData(scannedCode);
    }
  }

  // ===== MÉTODO CORREGIDO PARA CARGAR DATOS DEL LOTE =====
// CAMBIO PRINCIPAL: Consolidar todas las actualizaciones en UN SOLO setState()
  Future<void> _loadLoteData(String codigoLote) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener servicios a través de Provider
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      dynamic loteInfo;

      if (intranetService.isConnected.value) {
        // Obtener datos del lote desde la API
        loteInfo = await monitoreoService.getLoteInfo(codigoLote);

        // Guardar en caché
        await cacheService.saveData('lote_info_$codigoLote', loteInfo);
      } else {
        // Intentar cargar desde caché
        loteInfo = await cacheService.loadData('lote_info_$codigoLote');

        if (loteInfo == null) {
          // Si no hay datos en caché, usar información por defecto
          loteInfo = {
            'pmlt_contenedor': 'CONT_GENERAL',
            'pmlt_variedad': 'Variedad genérica',
            'pmva_descripcion': null,
            'pmlt_idvariedad': '0',
            'pmlt_casa': 'Casa genérica',
            'pmlt_cantero': 'Cantero genérico',
            'pmlt_canteros': 'Canteros genéricos',
            'pmva_responsable': 'Responsable genérico',
            'pmlt_grower': 'Grower genérico'
          };
          print(
              'No hay información del lote en caché, usando datos por defecto');
        } else {
          print('Información de lote cargada desde caché');
        }
      }

      print("Información del lote recibida: $loteInfo"); // Para depuración

      // ===== PREPARAR TODOS LOS DATOS ANTES DEL setState() =====
      // 🔧 CORRECCIÓN CLAVE: Leer pmlt_variedad PRIMERO, luego pmva_descripcion como fallback
      String? variedadDescripcion =
          loteInfo['pmlt_variedad'] ?? loteInfo['pmva_descripcion'];
      String? casaLote = loteInfo['pmlt_casa'];
      String? canteroLote = loteInfo['pmlt_cantero'];
      String? canterosLote = loteInfo['pmlt_canteros'];
      String? responsableLote =
          loteInfo['pmva_responsable'] ?? loteInfo['pmlt_grower'];
      String? idVariedad = loteInfo['pmlt_idvariedad']?.toString();

      print('✅ Valores extraídos del lote:');
      print('   - pmlt_variedad: ${loteInfo['pmlt_variedad']}');
      print('   - pmva_descripcion: ${loteInfo['pmva_descripcion']}');
      print('   - variedadDescripcion final: $variedadDescripcion');
      print('   - casaLote: $casaLote');
      print('   - responsableLote: $responsableLote');
      print('   - idVariedad: $idVariedad');

      // Extraer contenedor del lote
      String? contenedorLote = loteInfo['pmlt_contenedor'];

      // Verificar contenedor y asignar valor por defecto si es necesario
      if (contenedorLote == null || contenedorLote.isEmpty) {
        contenedorLote = 'CONT_GENERAL';
        print(
            'Contenedor vacío en datos de lote, usando valor por defecto: $contenedorLote');
      } else {
        print('Contenedor obtenido de datos de lote: $contenedorLote');
      }

      // Preparar listas actualizadas
      List<String> variedadesActualizadas = List.from(_variedades);
      List<String> casasActualizadas = List.from(_casas);
      Map<String, String> variedadesIdMapActualizado =
          Map.from(_variedadesIdMap);
      Map<String, String> responsablesActualizado =
          Map.from(_responsablesPorVariedad);

      // Actualizar lista de variedades si es necesario
      if (variedadDescripcion != null && variedadDescripcion.isNotEmpty) {
        if (!variedadesActualizadas.contains(variedadDescripcion)) {
          // Añadir la variedad al inicio de la lista (después de genérica)
          variedadesActualizadas.insert(1, variedadDescripcion);
          print('✅ Variedad añadida a la lista: $variedadDescripcion');
        }

        // Actualizar mapa de IDs si tenemos el ID
        if (idVariedad != null) {
          variedadesIdMapActualizado[variedadDescripcion] = idVariedad;
          print(
              '✅ ID de variedad mapeado: $variedadDescripcion -> $idVariedad');
        }

        // Actualizar mapa de responsables
        if (responsableLote != null && responsableLote.isNotEmpty) {
          responsablesActualizado[variedadDescripcion] = responsableLote;
          print(
              '✅ Responsable mapeado: $variedadDescripcion -> $responsableLote');
        }
      }

      // Actualizar lista de casas si es necesario
      if (casaLote != null && casaLote.isNotEmpty) {
        if (!casasActualizadas.contains(casaLote)) {
          // Añadir la casa al inicio de la lista (después de genérica)
          casasActualizadas.insert(1, casaLote);
          print('✅ Casa añadida a la lista: $casaLote');
        }
      }

      // ===== APLICAR TODOS LOS CAMBIOS EN UN SOLO setState() =====
      if (mounted) {
        setState(() {
          // Actualizar listas PRIMERO
          _variedades = variedadesActualizadas;
          _casas = casasActualizadas;
          _variedadesIdMap = variedadesIdMapActualizado;
          _responsablesPorVariedad = responsablesActualizado;

          // Actualizar valores seleccionados DESPUÉS (cuando ya están en las listas)
          _selectedVariedad = variedadDescripcion;
          _selectedCasa = casaLote;

          // Actualizar controladores
          _casaController.text = casaLote ?? '';
          _canteroController.text = canteroLote ?? '';
          _responsableController.text = responsableLote ?? '';
          _cantidadController.text = '0';

          // Guardar valores originales del lote
          _loteCanterosOriginal = canterosLote;
          _loteContenedorOriginal = contenedorLote;

          // Finalizar carga
          _isLoading = false;
        });

        print('✅ setState() aplicado - Datos del lote cargados correctamente:');
        print('   - Lista _variedades: $_variedades');
        print('   - Variedad seleccionada: $_selectedVariedad');
        print('   - Casa seleccionada: $_selectedCasa');
        print('   - Contenedor establecido: $_loteContenedorOriginal');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos del lote: $e';
        });
        _showMessage(
            'Error al cargar datos del lote. Por favor intente nuevamente.');

        // En caso de error, usar datos de ejemplo y ESTABLECER UN CONTENEDOR POR DEFECTO
        _casaController.text = 'Casa A';
        _selectedCasa = 'Casa A'; // También actualizar el dropdown
        _canteroController.text = 'C-123';
        _selectedVariedad = _variedades.isNotEmpty ? _variedades.first : null;
        _responsableController.text = 'Juan Pérez';
        _cantidadController.text = '0';

        // Establecer un contenedor por defecto en caso de error
        _loteContenedorOriginal = 'CONT_GENERAL';
        print(
            'Error al cargar datos del lote. Estableciendo contenedor por defecto: $_loteContenedorOriginal');
      }
    }
  }

  // Método para cambiar entre entrada manual y automática
  void _toggleEntryMode() {
    if (!mounted) return;

    setState(() {
      _isManualEntry = !_isManualEntry;

      // Si cambiamos a modo manual, limpiamos los campos para que el usuario los llene
      if (_isManualEntry) {
        _codigoLoteController.clear();
        _casaController.clear();
        _canteroController.clear();
        _selectedVariedad = null;
        _responsableController.clear();
        // Establecer un valor predeterminado para el contenedor
        _loteContenedorOriginal = 'CONT_GENERAL';
        print(
            'Cambiando a modo manual. Estableciendo contenedor por defecto: $_loteContenedorOriginal');
      }

      // Asegurar que siempre haya un valor por defecto
      _cantidadController.text = '0';

      _updateEditMode(true);
    });
  }

  // Método para actualizar el responsable al cambiar la variedad
  void _updateResponsable(String? variedad) {
    if (variedad == null) return;

    // Si es variedad genérica, dejamos el campo vacío
    if (variedad == 'Variedad genérica') {
      _responsableController.clear();
    } else {
      // Usar el mapa dinámico de responsables que hemos cargado
      if (_responsablesPorVariedad.containsKey(variedad)) {
        setState(() {
          _responsableController.text =
              _responsablesPorVariedad[variedad] ?? '';
        });
      } else {
        // Si no está en el mapa, intentamos con el mapa estático como fallback
        Map<String, String> responsablesFallback = {
          'Variedad 1': 'Juan Pérez',
          'Variedad 2': 'María Gómez',
          'Variedad 3': 'Carlos López',
        };

        _responsableController.text = responsablesFallback[variedad] ?? '';
      }
    }
  }

  // Cálculo total de muestras para cantidad observada
  int _calcularCantidadTotal() {
    int muestra1 = int.tryParse(_muestra1Controller.text) ?? 0;
    int muestra2 = int.tryParse(_muestra2Controller.text) ?? 0;
    int muestra3 = int.tryParse(_muestra3Controller.text) ?? 0;

    // La cantidad total es la suma de las tres muestras
    return muestra1 + muestra2 + muestra3;
  }

  // Actualizar el campo de cantidad con la suma de muestras
  void _actualizarCantidadObservada() {
    if (mounted) {
      setState(() {
        // La cantidad observada es la suma de las muestras
        _cantidadController.text = _calcularCantidadTotal().toString();
      });
    }
  }

  // Guardar parcialmente un monitoreo y limpiar solo datos de monitoreo - CORREGIDO
  Future<void> _saveMonitoreoParcial() async {
    // CORRECCIÓN: Establecer el modo de guardado parcial con TODOS los datos de contexto
    setState(() {
      _isPartialSave = true;
      // NUEVO: Activar modo guardado parcial y guardar TODOS los datos de contexto
      _isInPartialSaveMode = true;
      _partialSaveCantero = _canteroController.text;
      _partialSaveCasa = _casaController.text; // NUEVO
      _partialSaveLote = _codigoLoteController.text; // NUEVO
      _partialSaveVariedad = _selectedVariedad; // NUEVO
      _partialSaveDay = DateTime.now(); // NUEVO
    });

    // Usar el método de guardado existente
    await _saveMonitoreo();

    // Si el guardado fue exitoso, limpiar solo los datos de monitoreo
    if (!_isSubmitting && _errorMessage.isEmpty) {
      _clearMonitoreoData();

      // NUEVO: Preparar datos de navegación para el contexto específico (casa + cantero + lote + variedad + día)
      _prepareNavigationData();

      // NUEVO: Establecer el índice actual en la navegación
      if (_navigationData.isNotEmpty) {
        // Buscar el registro actual en los datos de navegación
        final currentIndex = _navigationData.indexWhere(
            (m) => m.pmmo_secuencia == _currentMonitoreo?.pmmo_secuencia);
        if (currentIndex >= 0) {
          setState(() {
            _currentNavigationIndex = currentIndex;
          });
        }
      }

      _showMessage(
          'Monitoreo guardado. Puede continuar con el siguiente registro en el mismo contexto.');
    }

    // Restaurar el modo de guardado normal
    setState(() {
      _isPartialSave = false;
    });
  }

  // Guardar un monitoreo
  Future<void> _saveMonitoreo() async {
    if (!mounted) return;

    // PRIMERO: Limpiar cualquier mensaje de error previo
    setState(() {
      _errorMessage = '';
    });

    // SEGUNDO: Validar SOLO campos requeridos (con asterisco *) con modales amigables ANTES de continuar
    if (_isManualEntry) {
      if (_canteroController.text.trim().isEmpty) {
        FriendlyErrorDialog.show(
          context,
          title: 'Campo requerido: Cantero',
          message:
              'Por favor ingrese el número del cantero antes de continuar.',
          icon: Icons.edit_note,
          iconColor: Colors.blue,
        );
        return;
      }

      if (_casaController.text.trim().isEmpty || _selectedCasa == null) {
        FriendlyErrorDialog.show(
          context,
          title: 'Campo requerido: Casa',
          message: 'Por favor seleccione la casa antes de continuar.',
          icon: Icons.home_outlined,
          iconColor: Colors.blue,
        );
        return;
      }

      if (_selectedVariedad == null ||
          _selectedVariedad == 'Variedad genérica') {
        FriendlyErrorDialog.show(
          context,
          title: 'Campo requerido: Variedad',
          message:
              'Por favor seleccione una variedad específica antes de continuar.',
          icon: Icons.grass,
          iconColor: Colors.blue,
        );
        return;
      }
    } else {
      if (_codigoLoteController.text.trim().isEmpty) {
        FriendlyErrorDialog.show(
          context,
          title: 'Código de lote requerido',
          message:
              'Por favor escanee un código de lote válido o cambie a entrada manual.',
          actionText: 'Escanear código',
          onAction: _scanBarcode,
          icon: Icons.qr_code_scanner,
          iconColor: Colors.blue,
        );
        return;
      }

      // Validar que los datos del lote se hayan cargado correctamente
      if (_selectedCasa == null || _selectedVariedad == null) {
        FriendlyErrorDialog.show(
          context,
          title: 'Datos del lote incompletos',
          message:
              'Los datos del lote escaneado no son válidos. Por favor escanee un código diferente.',
          actionText: 'Escanear otro',
          onAction: () {
            _codigoLoteController.clear();
            _scanBarcode();
          },
          icon: Icons.warning,
          iconColor: Colors.orange,
        );
        return;
      }
    }

    // VALIDAR PLAGA (obligatorio con *)
    if (_selectedPlaga == null ||
        _selectedPlaga!.isEmpty ||
        _selectedPlaga == 'Plaga genérica') {
      FriendlyErrorDialog.show(
        context,
        title: 'Seleccione una plaga',
        message:
            'Debe seleccionar qué plaga específica está monitoreando antes de guardar.',
        icon: Icons.bug_report,
        iconColor: Colors.red,
      );
      return;
    }

    // ELIMINAR VALIDACIÓN DE MUESTRAS - NO SON OBLIGATORIAS
    // Las muestras pueden estar vacías, no es obligatorio llenarlas

    // Verificar y asignar un valor predeterminado al contenedor si es necesario
    if (_loteContenedorOriginal == null || _loteContenedorOriginal!.isEmpty) {
      // Si no tenemos un contenedor, intentar obtenerlo del lote
      if (!_isManualEntry && _codigoLoteController.text.isNotEmpty) {
        try {
          final monitoreoService =
              Provider.of<MonitoreoService>(context, listen: false);
          final intranetService = _cachedIntranetService;
          if (intranetService != null && intranetService.isConnected.value) {
            final loteInfo =
                await monitoreoService.getLoteInfo(_codigoLoteController.text);
            _loteContenedorOriginal = loteInfo['pmlt_contenedor'];

            // Imprimir el valor obtenido para depuración
            print('Contenedor obtenido del lote: $_loteContenedorOriginal');
          } else {
            // Si no hay conexión, intentar leer desde caché
            final cacheService =
                Provider.of<CacheService>(context, listen: false);
            final loteInfo = await cacheService
                .loadData('lote_info_${_codigoLoteController.text}');

            if (loteInfo != null && loteInfo['pmlt_contenedor'] != null) {
              _loteContenedorOriginal = loteInfo['pmlt_contenedor'];
              print('Contenedor obtenido de caché: $_loteContenedorOriginal');
            }
          }
        } catch (e) {
          print('Error al obtener información del lote: $e');
        }
      }

      // Si después de todo no tenemos contenedor, usar uno por defecto
      if (_loteContenedorOriginal == null || _loteContenedorOriginal!.isEmpty) {
        _loteContenedorOriginal = 'CONT_GENERAL';
        print('Usando contenedor por defecto: $_loteContenedorOriginal');
      }
    }

    // Si estamos en modo manual y el código de lote está vacío, usar un código de lote por defecto
    if (_isManualEntry && _codigoLoteController.text.isEmpty) {
      _codigoLoteController.text = _getDefaultLoteCode();
      print('Usando código de lote predefinido: ${_codigoLoteController.text}');
    }

    // Imprimir el valor del contenedor antes de continuar (depuración)
    print(
        'Valor final del contenedor antes de guardar: $_loteContenedorOriginal');

    // Actualizar cantidad observada basada en muestras
    _actualizarCantidadObservada();

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      // Obtener los valores actuales de límites (con valores por defecto)
      final limiteNivel1 = _limiteNivel1 ?? 10;
      final limiteNivel2 = _limiteNivel2 ?? 20;
      final limiteNivel3 = _limiteNivel3 ?? 30;

      // Obtener servicios mediante Provider
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Servicio de conexión no disponible';
        });
        _showMessage('Error: Servicio de conexión no disponible');
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);

      // Obtener ID del usuario si está autenticado
      final userId = authService.getCurrentUserId();

      // Convertir valores de texto a enteros para muestras
      final muestra1 = int.tryParse(_muestra1Controller.text) ?? 0;
      final muestra2 = int.tryParse(_muestra2Controller.text) ?? 0;
      final muestra3 = int.tryParse(_muestra3Controller.text) ?? 0;

      // Calcular niveles automáticos
      final nivelAuto1 = NivelCalculator.calcularNivelAutomatico(
          muestra1, limiteNivel1, limiteNivel2);
      final nivelAuto2 = NivelCalculator.calcularNivelAutomatico(
          muestra2, limiteNivel1, limiteNivel2);
      final nivelAuto3 = NivelCalculator.calcularNivelAutomatico(
          muestra3, limiteNivel1, limiteNivel2);

      // Obtener niveles manuales
      final nivelManual1 = int.tryParse(_selectedNivelMuestra1 ?? '') ?? 0;
      final nivelManual2 = int.tryParse(_selectedNivelMuestra2 ?? '') ?? 0;
      final nivelManual3 = int.tryParse(_selectedNivelMuestra3 ?? '') ?? 0;

      // Asegurar que la cantidad observada tenga un valor (suma de muestras o 0)
      int cantidadObservada = int.tryParse(_cantidadController.text) ?? 0;
      int cantidadBotada = int.tryParse(_cantidadBotadaController.text) ?? 0;

      // Obtener el ID de la variedad a partir de la descripción
      String idVariedad = _obtenerIdVariedad(_selectedVariedad);

      // Valor para rastrear si se está creando offline
      final bool creatingOffline = !intranetService.isConnected.value;

      // Marca de tiempo para cambios offline
      final DateTime now = DateTime.now();

      // Crear objeto de monitoreo
      Monitoreo monitoreo;
      String operacion;

      if (_isEditing && !_isCreatingNew && _currentMonitoreo != null) {
        // Si estamos editando, partir del monitoreo actual
        operacion = 'update';
        monitoreo = _currentMonitoreo!.copyWith(
          // Campos base
          pmlt_codigo: _codigoLoteController.text.trim(),
          pmmo_casa: _casaController.text.trim(),
          pmmo_cantero: _canteroController.text
              .trim(), // Solo actualizamos cantero, NO canteros
          // Preservar pmmo_canteros, usando el valor original
          pmmo_canteros: _currentMonitoreo!.pmmo_canteros,
          // Establecer explícitamente el contenedor para asegurar que no se pierda
          pmmo_contenedor: _loteContenedorOriginal,
          pmmo_variedad: _selectedVariedad,
          pmmo_idvariedad: idVariedad, // ID de variedad, no descripción
          pmmo_grower: _responsableController.text.trim(),
          pmni_nombrecomun: _selectedPlaga,
          pmmo_cantidad: cantidadObservada,
          pmmo_cant_botada: cantidadBotada,
          pmmo_comentarios: _comentariosController.text.trim(),
          pmmo_automatico: !_isManualEntry,

          // Muestras
          pmmo_muestra1: muestra1,
          pmmo_muestra2: muestra2,
          pmmo_muestra3: muestra3,

          // Niveles automáticos
          pmmo_nivmuestraa1: nivelAuto1,
          pmmo_nivmuestraa2: nivelAuto2,
          pmmo_nivmuestraa3: nivelAuto3,

          // Niveles manuales
          pmmo_nivmuestram1: nivelManual1,
          pmmo_nivmuestram2: nivelManual2,
          pmmo_nivmuestram3: nivelManual3,

          // Límites - asegurar que estos se envíen siempre
          lmsupniv1: limiteNivel1,
          lmsupniv2: limiteNivel2,
          lmsupniv3: limiteNivel3,

          // Información de modificación
          pmmo_modificadopor: userId,
          pmmo_fechamodificacion: now,

          // Campos de offline
          offlineModifiedAt: creatingOffline ? now : null,
        );
      } else {
        // Si estamos creando uno nuevo
        operacion = 'create';
        monitoreo = Monitoreo(
          // Campos base
          pmmo_fecha: now,
          pmmo_estatus: 1,
          pmlt_codigo: _codigoLoteController.text.trim(),
          pmmo_casa: _casaController.text.trim(),
          pmmo_cantero:
              _canteroController.text.trim(), // Usuario ingresa el cantero
          // Usamos el valor original de canteros del lote, NO lo modificamos
          pmmo_canteros: _loteCanterosOriginal, // Valor original del lote
          pmmo_variedad: _selectedVariedad,
          pmmo_idvariedad: idVariedad, // ID de variedad, no descripción
          pmmo_grower: _responsableController.text.trim(),
          pmni_nombrecomun: _selectedPlaga,
          pmmo_cantidad: cantidadObservada,
          pmmo_cant_botada: cantidadBotada,
          pmmo_comentarios: _comentariosController.text.trim(),
          pmmo_automatico: !_isManualEntry,
          // Asegurar que el contenedor tenga un valor válido
          pmmo_contenedor: _loteContenedorOriginal ?? 'CONT_GENERAL',

          // Muestras
          pmmo_muestra1: muestra1,
          pmmo_muestra2: muestra2,
          pmmo_muestra3: muestra3,

          // Niveles automáticos
          pmmo_nivmuestraa1: nivelAuto1,
          pmmo_nivmuestraa2: nivelAuto2,
          pmmo_nivmuestraa3: nivelAuto3,

          // Niveles manuales
          pmmo_nivmuestram1: nivelManual1,
          pmmo_nivmuestram2: nivelManual2,
          pmmo_nivmuestram3: nivelManual3,

          // Límites - asegurar que estos se envíen siempre
          lmsupniv1: limiteNivel1,
          lmsupniv2: limiteNivel2,
          lmsupniv3: limiteNivel3,

          // Información de creación
          pmmo_creadopor: userId,
          pmmo_fechacreacion: now,

          // Campos para soporte offline
          isOfflineCreated: creatingOffline,
          offlineModifiedAt: creatingOffline ? now : null,
        );
      }

      // Imprimir el objeto para verificar antes de enviarlo (debug)
      print('Enviando monitoreo con contenedor: ${monitoreo.pmmo_contenedor}');
      print('Enviando monitoreo: ${monitoreo.toJson()}');

      // Guardar el monitoreo, diferenciando entre online y offline
      if (intranetService.isConnected.value) {
        // MODO ONLINE: Enviar directamente al servidor
        if (operacion == 'create') {
          await monitoreoService.crearMonitoreo(monitoreo);
          print('Monitoreo creado en el servidor');
        } else {
          await monitoreoService.actualizarMonitoreo(monitoreo);
          print('Monitoreo actualizado en el servidor');
        }

        // Recargar datos desde el servidor
        await _loadData();

        if (mounted) {
          _showMessage(operacion == 'create'
              ? 'Monitoreo creado correctamente'
              : 'Monitoreo actualizado correctamente');
        }
      } else {
        // MODO OFFLINE: Guardar localmente para sincronización posterior

        // 1. Registrar en la lista de cambios pendientes
        List<dynamic> pendingChanges = [];
        final cachedPending = await cacheService.loadData('pending_monitoreos');
        if (cachedPending != null && cachedPending is List) {
          pendingChanges = cachedPending;
        }

        // Si estamos creando un nuevo monitoreo offline, asignar ID temporal negativo
        if (operacion == 'create') {
          // Generar un ID negativo único basado en timestamp para identificar registros nuevos
          monitoreo.pmmo_secuencia = -(DateTime.now().millisecondsSinceEpoch);
        }

        // Añadir a la lista de operaciones pendientes
        pendingChanges.add({
          'operation': operacion,
          'monitoreo': monitoreo.toJson(),
          'timestamp': now.toIso8601String(),
        });

        // Guardar la lista actualizada de operaciones pendientes
        await cacheService.saveData('pending_monitoreos', pendingChanges);

        // 2. Actualizar la lista local de monitoreos para mostrar al usuario
        List<Monitoreo> monitoreos = [];
        final cachedData = await cacheService.loadData('monitoreos_data');
        if (cachedData != null && cachedData is List) {
          monitoreos = cachedData
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();
        }

        if (operacion == 'update') {
          // Actualizar monitoreo existente en la lista local
          final index = monitoreos
              .indexWhere((m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
          if (index >= 0) {
            monitoreos[index] = monitoreo;
          } else {
            // Si no se encuentra, añadirlo a la lista
            monitoreos.add(monitoreo);
          }
        } else {
          // Añadir el nuevo monitoreo a la lista local
          monitoreos.add(monitoreo);
        }

        // Guardar la lista actualizada de monitoreos
        await cacheService.saveData(
            'monitoreos_data', monitoreos.map((m) => m.toJson()).toList());

        // Actualizar el contador de cambios pendientes
        await _updatePendingChangesCount();

        // Recargar datos desde la caché
        await _loadData();

        if (mounted) {
          _showMessage(operacion == 'create'
              ? 'Monitoreo guardado localmente. Se sincronizará cuando haya conexión.'
              : 'Monitoreo actualizado localmente. Se sincronizará cuando haya conexión.');
        }
      }

      // Si es un guardado parcial, no limpiar todo el formulario ni volver a la lista
      if (!_isPartialSave) {
        // Limpiar formulario y volver a la lista
        _clearForm();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al guardar: $e';
        });

        // Mostrar error amigable en lugar del mensaje técnico
        String title = 'Error al guardar';
        String message =
            'No se pudo guardar el monitoreo. Por favor intente nuevamente.';

        if (e.toString().contains('connection')) {
          title = 'Sin conexión';
          message =
              'No se puede guardar sin conexión a la intranet. El monitoreo se guardará localmente para sincronizar después.';
        } else if (e.toString().contains('timeout')) {
          title = 'Tiempo agotado';
          message =
              'La operación está tardando mucho. Verifique su conexión e intente nuevamente.';
        } else if (e.toString().contains('permission')) {
          title = 'Sin permisos';
          message =
              'No tiene permisos para realizar esta operación. Contacte al administrador.';
        }

        FriendlyErrorDialog.show(
          context,
          title: title,
          message: message,
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );

        print('Error al guardar monitoreo: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        // Notificar que ya no estamos en modo edición si no es guardado parcial
        if (!_isPartialSave) {
          _updateEditMode(false);
        }
      }
    }
  }

  // Cargar monitoreo para editar
  Future<void> _editMonitoreo(Monitoreo monitoreo,
      {bool fromNavigation = false}) async {
    if (!mounted) return;

    // Verificar si el usuario tiene permiso para editar este monitoreo
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);

    if (!monitoreoService.canEditMonitoreo(monitoreo)) {
      _showMessage(
          'No tienes permiso para editar este monitoreo. Solo puedes editar tus propios registros.');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _isCreatingNew = false;
      });

      // Obtener servicios
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Servicio de conexión no disponible';
        });
        _showMessage('Error: Servicio de conexión no disponible');
        return;
      }

      Monitoreo completeMonitoreo;

      if (intranetService.isConnected.value) {
        // Cargar detalles completos del monitoreo desde la API
        completeMonitoreo =
            await monitoreoService.getMonitoreoById(monitoreo.pmmo_secuencia!);

        // Guardar en caché
        await cacheService.saveData('monitoreo_${monitoreo.pmmo_secuencia}',
            completeMonitoreo.toJson());
      } else {
        // Intentar cargar desde caché
        final cachedData = await cacheService
            .loadData('monitoreo_${monitoreo.pmmo_secuencia}');
        if (cachedData != null) {
          completeMonitoreo = Monitoreo.fromJson(cachedData);
          print('Monitoreo cargado desde caché');
        } else {
          // Si no está en caché, usar el monitoreo proporcionado
          completeMonitoreo = monitoreo;
          print('Usando monitoreo proporcionado, no está en caché');
        }
      }

      // Imprimir el contenedor del monitoreo para depuración
      print(
          'Contenedor del monitoreo cargado: ${completeMonitoreo.pmmo_contenedor}');

      // Si el monitoreo no tiene un contenedor válido, asignar uno por defecto
      if (completeMonitoreo.pmmo_contenedor == null ||
          completeMonitoreo.pmmo_contenedor!.isEmpty) {
        // Intentar obtener el contenedor del lote si tenemos el código
        if (completeMonitoreo.pmlt_codigo != null &&
            completeMonitoreo.pmlt_codigo!.isNotEmpty) {
          try {
            // Intentar cargar info del lote
            dynamic loteInfo;
            if (intranetService.isConnected.value) {
              loteInfo = await monitoreoService
                  .getLoteInfo(completeMonitoreo.pmlt_codigo!);
            } else {
              loteInfo = await cacheService
                  .loadData('lote_info_${completeMonitoreo.pmlt_codigo}');
            }

            if (loteInfo != null && loteInfo['pmlt_contenedor'] != null) {
              completeMonitoreo.pmmo_contenedor = loteInfo['pmlt_contenedor'];
              print(
                  'Obtenido contenedor del lote: ${completeMonitoreo.pmmo_contenedor}');
            }
          } catch (e) {
            print('Error al obtener contenedor del lote: $e');
          }
        }

        // Si aún no tenemos un contenedor, usar uno por defecto
        if (completeMonitoreo.pmmo_contenedor == null ||
            completeMonitoreo.pmmo_contenedor!.isEmpty) {
          completeMonitoreo.pmmo_contenedor = 'CONT_GENERAL';
          print(
              'Estableciendo contenedor por defecto para el monitoreo: ${completeMonitoreo.pmmo_contenedor}');
        }
      }

      if (mounted) {
        // ===== PREPARAR DATOS PARA EDICIÓN (Similar a _loadLoteData) =====
        String? variedadMonitoreo = completeMonitoreo.pmmo_variedad ??
            completeMonitoreo.pmva_descripcion;
        String? casaMonitoreo = completeMonitoreo.pmmo_casa;
        String? plagaMonitoreo = completeMonitoreo.pmni_nombrecomun;

        // Preparar listas actualizadas
        List<String> variedadesActualizadas = List.from(_variedades);
        List<String> casasActualizadas = List.from(_casas);
        List<String> plagasActualizadas = List.from(_plagas);
        Map<String, String> variedadesIdMapActualizado =
            Map.from(_variedadesIdMap);

        // Verificar y añadir la variedad si no está en la lista
        if (variedadMonitoreo != null &&
            variedadMonitoreo.isNotEmpty &&
            !variedadesActualizadas.contains(variedadMonitoreo)) {
          variedadesActualizadas.insert(1, variedadMonitoreo);

          // Si tenemos el ID de la variedad, añadirlo al mapa de IDs
          if (completeMonitoreo.pmmo_idvariedad != null) {
            variedadesIdMapActualizado[variedadMonitoreo] =
                completeMonitoreo.pmmo_idvariedad!;
          }
        }

        // Verificar y añadir la casa si no está en la lista
        if (casaMonitoreo != null &&
            casaMonitoreo.isNotEmpty &&
            !casasActualizadas.contains(casaMonitoreo)) {
          casasActualizadas.insert(1, casaMonitoreo);
        }

        // Verificar y añadir la plaga si no está en la lista
        if (plagaMonitoreo != null &&
            plagaMonitoreo.isNotEmpty &&
            !plagasActualizadas.contains(plagaMonitoreo)) {
          plagasActualizadas.insert(1, plagaMonitoreo);
        }

        // NUEVO: Si no es navegación, preparar datos de navegación normales
        if (!fromNavigation && !_isInPartialSaveMode) {
          _prepareNavigationData();
          final currentIndex = _navigationData.indexWhere(
              (m) => m.pmmo_secuencia == completeMonitoreo.pmmo_secuencia);
          if (currentIndex >= 0) {
            setState(() {
              _currentNavigationIndex = currentIndex;
            });
          }
        }

        // ===== APLICAR TODOS LOS CAMBIOS EN UN SOLO setState() =====
        setState(() {
          // Actualizar listas PRIMERO
          _variedades = variedadesActualizadas;
          _casas = casasActualizadas;
          _plagas = plagasActualizadas;
          _variedadesIdMap = variedadesIdMapActualizado;

          // Establecer monitoreo actual
          _currentMonitoreo = completeMonitoreo;
          _isEditing = true;

          // Datos del lote
          _codigoLoteController.text = completeMonitoreo.pmlt_codigo ?? '';
          _casaController.text = completeMonitoreo.pmmo_casa ?? '';
          _canteroController.text = completeMonitoreo.pmmo_cantero ?? '';
          _responsableController.text = completeMonitoreo.pmmo_grower ?? '';

          // Valores seleccionados (DESPUÉS de actualizar listas)
          _selectedVariedad = variedadMonitoreo;
          _selectedCasa = completeMonitoreo.pmmo_casa;
          _selectedPlaga = completeMonitoreo.pmni_nombrecomun;

          // Guardar el valor original de canteros y contenedor
          _loteCanterosOriginal = completeMonitoreo.pmmo_canteros;
          _loteContenedorOriginal = completeMonitoreo.pmmo_contenedor;

          // Datos del monitoreo
          _cantidadController.text =
              completeMonitoreo.pmmo_cantidad?.toString() ?? '0';
          _cantidadBotadaController.text =
              completeMonitoreo.pmmo_cant_botada?.toString() ?? '0';
          _comentariosController.text =
              completeMonitoreo.pmmo_comentarios ?? '';

          // Campos de muestras
          _muestra1Controller.text =
              completeMonitoreo.pmmo_muestra1?.toString() ?? '';
          _muestra2Controller.text =
              completeMonitoreo.pmmo_muestra2?.toString() ?? '';
          _muestra3Controller.text =
              completeMonitoreo.pmmo_muestra3?.toString() ?? '';

          // Niveles manuales
          _selectedNivelMuestra1 =
              completeMonitoreo.pmmo_nivmuestram1?.toString();
          _selectedNivelMuestra2 =
              completeMonitoreo.pmmo_nivmuestram2?.toString();
          _selectedNivelMuestra3 =
              completeMonitoreo.pmmo_nivmuestram3?.toString();

          // Modo de entrada
          _isManualEntry = completeMonitoreo.pmmo_automatico != true;

          _isLoading = false;
          _errorMessage = '';

          // Cambiar a la pestaña de registro
          _tabController.animateTo(1);
        });

        print('✅ Monitoreo cargado para edición:');
        print('   - Variedad seleccionada: $_selectedVariedad');
        print('   - Casa seleccionada: $_selectedCasa');
        print('   - Plaga seleccionada: $_selectedPlaga');
        print('   - Contenedor establecido: $_loteContenedorOriginal');

        // Notificar que estamos en modo edición
        _updateEditMode(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar el monitoreo: $e';
        });

        // Mostrar error amigable para cargar monitoreo
        FriendlyErrorDialog.show(
          context,
          title: 'Error al cargar',
          message:
              'No se pudo cargar el monitoreo seleccionado. Intente nuevamente.',
          icon: Icons.refresh,
          iconColor: Colors.orange,
        );

        // Establecer un contenedor por defecto en caso de error
        _loteContenedorOriginal = 'CONT_GENERAL';
        print(
            'Error al cargar el monitoreo. Estableciendo contenedor por defecto: $_loteContenedorOriginal');
      }
    }
  }

  // Eliminar monitoreo
  void _deleteMonitoreo(Monitoreo monitoreo) {
    // Verificar si el usuario tiene permiso para eliminar este monitoreo
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);

    if (!monitoreoService.canDeleteMonitoreo(monitoreo)) {
      _showMessage(
          'No tienes permiso para eliminar este monitoreo. Solo puedes eliminar tus propios registros.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Está seguro que desea eliminar el monitoreo #${monitoreo.pmmo_secuencia}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              if (!mounted) return;

              setState(() {
                _isLoading = true;
              });

              try {
                final cacheService =
                    Provider.of<CacheService>(context, listen: false);
                final intranetService = _cachedIntranetService;
                if (intranetService == null) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Servicio de conexión no disponible';
                  });
                  _showMessage('Error: Servicio de conexión no disponible');
                  return;
                }

                bool success = false;

                if (intranetService.isConnected.value) {
                  // MODO ONLINE: Si hay conexión, intentar eliminar de la API

                  // Solo enviar al servidor si es un registro con ID real (no temporal)
                  if (!monitoreo.isTemporary()) {
                    try {
                      success = await monitoreoService
                          .eliminarMonitoreo(monitoreo.pmmo_secuencia!);
                      print(
                          'Monitoreo eliminado del servidor: ID ${monitoreo.pmmo_secuencia}');
                    } catch (e) {
                      print('Error al eliminar monitoreo del servidor: $e');
                      success = false;
                    }
                  } else {
                    // Si es un registro temporal, se considera eliminado exitosamente
                    success = true;
                    print(
                        'Eliminando monitoreo temporal: ID ${monitoreo.pmmo_secuencia}');
                  }

                  // Registrar la operación como pendiente para asegurar que se procese en caso de fallo
                  List<dynamic> pendingChanges = [];
                  final cachedPending =
                      await cacheService.loadData('pending_monitoreos');
                  if (cachedPending != null && cachedPending is List) {
                    pendingChanges = cachedPending;
                  }

                  // Si el monitoreo tiene ID negativo (es temporal), verificar si ya está en cambios pendientes
                  if (monitoreo.isTemporary()) {
                    // Para registros temporales, simplemente eliminar cualquier operación anterior sobre él
                    pendingChanges.removeWhere((change) {
                      if (change['monitoreo'] != null &&
                          change['monitoreo']['pmmo_secuencia'] != null) {
                        return change['monitoreo']['pmmo_secuencia'] ==
                            monitoreo.pmmo_secuencia;
                      }
                      return false;
                    });
                  } else {
                    // Para registros con ID real, añadir operación de eliminación
                    pendingChanges.add({
                      'operation': 'delete',
                      'monitoreo': monitoreo.toJson(),
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  }

                  // Guardar la lista actualizada
                  await cacheService.saveData(
                      'pending_monitoreos', pendingChanges);

                  // Actualizar contador de cambios pendientes
                  await _updatePendingChangesCount();
                } else {
                  // MODO OFFLINE: Si no hay conexión

                  List<dynamic> pendingChanges = [];
                  final cachedPending =
                      await cacheService.loadData('pending_monitoreos');
                  if (cachedPending != null && cachedPending is List) {
                    pendingChanges = cachedPending;
                  }

                  // Si el monitoreo tiene ID negativo (creado offline), simplemente eliminar
                  // cualquier operación pendiente asociada a él
                  if (monitoreo.isTemporary()) {
                    pendingChanges.removeWhere((change) {
                      if (change['monitoreo'] != null &&
                          change['monitoreo']['pmmo_secuencia'] != null) {
                        return change['monitoreo']['pmmo_secuencia'] ==
                            monitoreo.pmmo_secuencia;
                      }
                      return false;
                    });
                  } else {
                    // Si tiene ID real, añadir operación de eliminación para sincronizar después
                    pendingChanges.add({
                      'operation': 'delete',
                      'monitoreo': monitoreo.toJson(),
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  }

                  // Guardar la lista actualizada
                  await cacheService.saveData(
                      'pending_monitoreos', pendingChanges);

                  // Actualizar contador de cambios pendientes
                  await _updatePendingChangesCount();

                  // Actualizar lista local eliminando el registro
                  List<Monitoreo> monitoreos = [];
                  final cachedData =
                      await cacheService.loadData('monitoreos_data');
                  if (cachedData != null && cachedData is List) {
                    monitoreos = cachedData
                        .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                        .toList();

                    // Filtrar para quitar el monitoreo eliminado
                    monitoreos.removeWhere(
                        (m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);

                    // Guardar la lista actualizada
                    await cacheService.saveData('monitoreos_data',
                        monitoreos.map((m) => m.toJson()).toList());

                    success = true;
                    print(
                        'Monitoreo marcado para eliminar offline: ID ${monitoreo.pmmo_secuencia}');
                  }
                }

                // Recargar datos
                await _loadData();

                if (success && mounted) {
                  _showMessage(intranetService.isConnected.value
                      ? 'Monitoreo eliminado correctamente'
                      : 'Monitoreo marcado para eliminar. Se sincronizará cuando haya conexión.');
                } else if (mounted) {
                  _showMessage('No se pudo eliminar el monitoreo');
                }
              } catch (e) {
                if (mounted) {
                  // Mostrar error amigable para eliminación
                  FriendlyErrorDialog.show(
                    context,
                    title: 'Error al eliminar',
                    message:
                        'No se pudo eliminar el monitoreo. Intente nuevamente.',
                    icon: Icons.delete_outline,
                    iconColor: Colors.red,
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Selector de fecha con DateRangePicker
  Future<void> _selectDateRange(BuildContext context) async {
    try {
      // Establecer fechas seguras predeterminadas
      final DateTime now = DateTime.now();
      final DateTime safeMinDate =
          DateTime(2025, 1, 1); // Fecha mínima predeterminada
      final DateTime safeMaxDate =
          DateTime(2030, 12, 31); // Fecha máxima segura

      // Variables para almacenar las fechas min/max de los datos
      DateTime dataMinDate = safeMinDate;
      DateTime dataMaxDate = now.isBefore(safeMaxDate) ? now : safeMaxDate;

      // Solo buscar en los datos si hay registros
      if (_monitoreoData.isNotEmpty) {
        // Inicializar con la primera fecha válida
        DateTime? tempMin;
        DateTime? tempMax;

        for (final monitoreo in _monitoreoData) {
          if (monitoreo.pmmo_fecha != null) {
            final fecha = monitoreo.pmmo_fecha!;

            // Solo considerar fechas que no estén en el futuro extremo (después de 2024-12-31)
            if (!fecha.isAfter(safeMaxDate)) {
              if (tempMin == null || fecha.isBefore(tempMin)) {
                tempMin = fecha;
              }
              if (tempMax == null || fecha.isAfter(tempMax)) {
                tempMax = fecha;
              }
            }
          }
        }

        // Actualizar las fechas min/max si encontramos datos válidos
        if (tempMin != null) dataMinDate = tempMin;
        if (tempMax != null) dataMaxDate = tempMax;
      }

      // Limpiar horas/minutos/segundos para evitar problemas
      dataMinDate =
          DateTime(dataMinDate.year, dataMinDate.month, dataMinDate.day);
      dataMaxDate =
          DateTime(dataMaxDate.year, dataMaxDate.month, dataMaxDate.day);

      // Ajustar fechas seleccionadas actuales para que estén dentro del rango válido
      DateTime selectedStart;
      DateTime selectedEnd;

      // Si hay fechas seleccionadas previamente, úsalas si son válidas
      if (_fechaInicio != null &&
          !_fechaInicio!.isBefore(dataMinDate) &&
          !_fechaInicio!.isAfter(dataMaxDate)) {
        selectedStart = _fechaInicio!;
      } else {
        // De lo contrario, usar un mes antes de la fecha máxima o la fecha mínima
        selectedStart = dataMaxDate.subtract(const Duration(days: 30));
        if (selectedStart.isBefore(dataMinDate)) {
          selectedStart = dataMinDate;
        }
      }

      if (_fechaFin != null &&
          !_fechaFin!.isBefore(dataMinDate) &&
          !_fechaFin!.isAfter(dataMaxDate)) {
        selectedEnd = _fechaFin!;
      } else {
        selectedEnd = dataMaxDate;
      }

      // Asegurar que el inicio no sea después del fin
      if (selectedStart.isAfter(selectedEnd)) {
        selectedStart = selectedEnd;
      }

      // Limpiar las horas para las fechas seleccionadas
      selectedStart =
          DateTime(selectedStart.year, selectedStart.month, selectedStart.day);
      selectedEnd =
          DateTime(selectedEnd.year, selectedEnd.month, selectedEnd.day);

      // Verificar nuevamente la lógica (debug)
      print('DEBUG: Rango de fechas para selector:');
      print('  firstDate: $dataMinDate');
      print('  lastDate: $dataMaxDate');
      print('  initialDateRange.start: $selectedStart');
      print('  initialDateRange.end: $selectedEnd');

      // Verificación final para garantizar que el rango es válido
      assert(!dataMaxDate.isBefore(dataMinDate),
          'La fecha máxima no puede ser anterior a la fecha mínima');
      assert(!selectedStart.isBefore(dataMinDate),
          'La fecha de inicio seleccionada no puede ser anterior a la fecha mínima');
      assert(!selectedStart.isAfter(dataMaxDate),
          'La fecha de inicio seleccionada no puede ser posterior a la fecha máxima');
      assert(!selectedEnd.isBefore(dataMinDate),
          'La fecha de fin seleccionada no puede ser anterior a la fecha mínima');
      assert(!selectedEnd.isAfter(dataMaxDate),
          'La fecha de fin seleccionada no puede ser posterior a la fecha máxima');

      // Mostrar el selector
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(
          start: selectedStart,
          end: selectedEnd,
        ),
        firstDate: dataMinDate,
        lastDate: dataMaxDate,
        saveText: 'Aplicar',
        cancelText: 'Cancelar',
        confirmText: 'Aplicar rango',
        helpText: 'Seleccione rango de fechas',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: MonitoreoStyles.primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: MonitoreoStyles.primaryColor,
                ),
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null && mounted) {
        setState(() {
          // Actualizar los valores seleccionados
          _fechaInicio = DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          );
          _fechaFin = DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23, 59, 59, // Añadir hora máxima para incluir todo el día
          );
          _fechaInicioController.text =
              DateFormat('dd/MM/yyyy').format(_fechaInicio!);
          _fechaFinController.text =
              DateFormat('dd/MM/yyyy').format(_fechaFin!);
        });
      }
    } catch (e) {
      // Capturar cualquier error y mostrar un mensaje útil
      print('ERROR DETALLADO en selector de fechas: $e');

      // Mostrar error amigable para selector de fechas
      if (mounted) {
        FriendlyErrorDialog.show(
          context,
          title: 'Error en selector de fechas',
          message:
              'Hubo un problema con el selector de fechas. Se aplicará un rango predeterminado.',
          icon: Icons.calendar_today,
          iconColor: Colors.orange,
        );
      }

      // Establecer fechas predeterminadas seguras en caso de error
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          final oneMonthAgo = now.subtract(const Duration(days: 30));

          _fechaInicio = oneMonthAgo;
          _fechaFin = now;
          _fechaInicioController.text =
              DateFormat('dd/MM/yyyy').format(oneMonthAgo);
          _fechaFinController.text = DateFormat('dd/MM/yyyy').format(now);
        });
      }
    }
  }

  // Limpiar fechas seleccionadas y filtros adicionales
  void _resetFechasFiltro() {
    if (mounted) {
      setState(() {
        _fechaInicio = null;
        _fechaFin = null;
        _fechaInicioController.clear();
        _fechaFinController.clear();

        // Reiniciar también los filtros adicionales
        _selectedCasaFiltro = null;
        _selectedCanteroFiltro = null;
        _selectedVariedadFiltro = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si es una pantalla pequeña
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    // Obtener el estado de conexión
    final intranetService = Provider.of<IntranetService>(context);
    final bool isConnected = intranetService.isConnected.value;

    // Obtener información del usuario actual y verificar autenticación
    final authService = Provider.of<AuthService>(context);
    final String username = authService.currentUser?.username ?? 'Usuario';
    final bool isAuthenticated = authService.isAuthenticated;
    final bool hasValidSession = isAuthenticated &&
        authService.getCurrentUserId() != null &&
        authService.getCurrentUserId() != 1;

    // MODIFICACIÓN: Usar Scaffold para poder incluir botón flotante y appBar con botón de nuevo monitoreo
    return Scaffold(
      // MODIFICACIÓN: AppBar para mostrar botón de nuevo monitoreo en pantallas grandes (SOLO SI HAY SESIÓN VÁLIDA)
      appBar: _tabController.index == 0 && !isSmallScreen && hasValidSession
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _nuevoMonitoreo,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MonitoreoStyles.accentColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            )
          : null,

      // Contenido principal
      body: Column(
        children: [
          // Barra de estado de sincronización
          SyncStatusBar(
            isConnected: isConnected,
            pendingChanges: _pendingChangesCount,
            isSyncing: _isSyncing,
            lastSyncStatus: _lastSyncStatus,
            onSyncPressed: _sincronizarCambiosPendientes,
          ),

          // NUEVO: Barra de navegación entre registros (solo visible en modo edición)
          if (_isEditing &&
              (_navigationData.isNotEmpty || _isInPartialSaveMode))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              child: Row(
                children: [
                  // Botón Anterior
                  IconButton(
                    onPressed:
                        _canNavigatePrevious() ? _navigatePrevious : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Registro anterior',
                    style: IconButton.styleFrom(
                      backgroundColor: _canNavigatePrevious()
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                      foregroundColor: _canNavigatePrevious()
                          ? Colors.blue.shade700
                          : Colors.grey.shade500,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Información de navegación
                  Expanded(
                    child: Text(
                      _getNavigationInfo(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Botón Siguiente
                  IconButton(
                    onPressed: _canNavigateNext() ? _navigateNext : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Registro siguiente',
                    style: IconButton.styleFrom(
                      backgroundColor: _canNavigateNext()
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                      foregroundColor: _canNavigateNext()
                          ? Colors.blue.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab de Consulta (Listado de Monitoreos)
                ConsultaTab(
                  monitoreos: _filteredMonitoreoData,
                  columns: _columns,
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  onEdit: _editMonitoreo,
                  onDelete: _deleteMonitoreo,
                  onDetails: (monitoreo) =>
                      MonitoreoDetailsDialog.showMonitoreoDetails(
                          context, monitoreo, () => _editMonitoreo(monitoreo)),
                  onSearch: _searchMonitoreos,
                  onReload: _loadData,
                  searchController: _searchController,
                  fechaInicioController: _fechaInicioController,
                  fechaFinController: _fechaFinController,
                  selectedEstado: _selectedEstado,
                  selectedPlaga: _selectedPlaga,
                  // Nuevos parámetros para los filtros adicionales
                  selectedCasa: _selectedCasaFiltro,
                  selectedCantero: _selectedCanteroFiltro,
                  selectedVariedad: _selectedVariedadFiltro,
                  fechaInicio: _fechaInicio,
                  fechaFin: _fechaFin,
                  plagas: _plagas,
                  // Nuevas listas para los filtros adicionales
                  casas: _casas,
                  canteros:
                      _obtenerListaCanteros(), // Método para obtener canteros únicos
                  variedades: _variedades,
                  onEstadoChanged: (value) {
                    setState(() {
                      _selectedEstado = value;
                    });
                  },
                  onPlagaChanged: (value) {
                    setState(() {
                      _selectedPlaga = value;
                    });
                  },
                  // Nuevos callbacks para los filtros adicionales
                  onCasaChanged: (value) {
                    setState(() {
                      _selectedCasaFiltro = value;
                    });
                  },
                  onCanteroChanged: (value) {
                    setState(() {
                      _selectedCanteroFiltro = value;
                    });
                  },
                  onVariedadChanged: (value) {
                    setState(() {
                      _selectedVariedadFiltro = value;
                    });
                  },
                  onSelectDateRange: _selectDateRange,
                  onFechaReset: _resetFechasFiltro,
                  onExportExcel: _exportToExcel,
                  // Parámetros para paginación
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  itemsPerPage: _itemsPerPage,
                  totalItems: _totalItems,
                  onPageChanged: _handlePageChange,
                  onItemsPerPageChanged: _handleItemsPerPageChange,
                  // Parámetros para ordenamiento
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  onSort: _handleSort,
                  onColumnResize: _handleColumnResize,
                  columnWidths: _columnWidths,
                  // Parámetro adicional para cambios pendientes
                  pendingChangesCount: _pendingChangesCount,
                  // Nuevo parámetro para indicar si es pantalla pequeña
                  isSmallScreen: isSmallScreen,
                  // MODIFICACIÓN: Solo pasar el callback si hay sesión válida
                  onNuevoMonitoreo: hasValidSession ? _nuevoMonitoreo : null,
                ),

                // Tab de Registro (Formulario de Monitoreo)
                RegistroTab(
                  currentMonitoreo: _currentMonitoreo,
                  isEditing: _isEditing,
                  isCreatingNew: _isCreatingNew,
                  isSubmitting: _isSubmitting,
                  errorMessage: _errorMessage,
                  isManualEntry: _isManualEntry,
                  codigoLoteController: _codigoLoteController,
                  casaController: _casaController,
                  canteroController: _canteroController,
                  responsableController: _responsableController,
                  comentariosController: _comentariosController,
                  cantidadController: _cantidadController,
                  cantidadBotadaController: _cantidadBotadaController,
                  muestra1Controller: _muestra1Controller,
                  muestra2Controller: _muestra2Controller,
                  muestra3Controller: _muestra3Controller,
                  selectedCasa: _selectedCasa,
                  selectedVariedad: _selectedVariedad,
                  selectedPlaga: _selectedPlaga,
                  selectedNivelMuestra1: _selectedNivelMuestra1,
                  selectedNivelMuestra2: _selectedNivelMuestra2,
                  selectedNivelMuestra3: _selectedNivelMuestra3,
                  casas: _casas,
                  variedades: _variedades,
                  plagas: _plagas,
                  limiteNivel1: _limiteNivel1,
                  limiteNivel2: _limiteNivel2,
                  limiteNivel3: _limiteNivel3,
                  onSave: _saveMonitoreo,
                  onSavePartial: _saveMonitoreoParcial,
                  onCancel: () {
                    _clearForm();
                    _tabController.animateTo(0);
                  },
                  onToggleEntryMode: _toggleEntryMode,
                  onScanBarcode: _scanBarcode,
                  onCasaChanged: (value) {
                    setState(() {
                      _selectedCasa = value;
                      _casaController.text = value ?? '';
                    });
                  },
                  onVariedadChanged: (value) {
                    setState(() {
                      _selectedVariedad = value;
                      _updateResponsable(value);
                    });
                  },
                  onPlagaChanged: (value) {
                    setState(() {
                      _selectedPlaga = value;
                      if (value != null && value.isNotEmpty) {
                        _loadInfoPlagaAction(value);
                      }
                    });
                  },
                  onNivelMuestra1Changed: (value) {
                    setState(() {
                      _selectedNivelMuestra1 = value;
                    });
                  },
                  onNivelMuestra2Changed: (value) {
                    setState(() {
                      _selectedNivelMuestra2 = value;
                    });
                  },
                  onNivelMuestra3Changed: (value) {
                    setState(() {
                      _selectedNivelMuestra3 = value;
                    });
                  },
                  onMuestra1Changed: (value) {
                    _actualizarCantidadObservada();
                  },
                  onMuestra2Changed: (value) {
                    _actualizarCantidadObservada();
                  },
                  onMuestra3Changed: (value) {
                    _actualizarCantidadObservada();
                  },
                  // Nuevo parámetro para indicar modo offline
                  isOfflineMode: !isConnected,
                  // Nuevo parámetro para indicar si es pantalla pequeña
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ],
      ),

      // MODIFICACIÓN: Botón flotante para nuevo monitoreo (solo en pantallas pequeñas y en la pestaña de consulta Y CON SESIÓN VÁLIDA)
      floatingActionButton:
          isSmallScreen && _tabController.index == 0 && hasValidSession
              ? FloatingActionButton(
                  onPressed: _nuevoMonitoreo,
                  backgroundColor: MonitoreoStyles.accentColor,
                  child: const Icon(Icons.add),
                  tooltip: 'Nuevo monitoreo',
                  mini: true, // Hace el botón más pequeño
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation
          .centerFloat, // Esta línea centra el botón
    );
  }
}
