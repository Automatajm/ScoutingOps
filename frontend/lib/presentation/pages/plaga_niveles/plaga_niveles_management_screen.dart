import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import '../../../models/plaga_model.dart';
import '../../../services/plaga_service.dart';
import '../../../models/nivel_infestacion_model.dart';
import '../../../services/nivel_infestacion_service.dart';
import '../../../core/config/flavor_config.dart';
import '../../widgets/pagination_widget.dart';

// Clase para manejar la información de las columnas
class ColumnInfo {
  final String title;
  double width;
  bool isSorted;
  bool sortAscending;
  final Function(Plaga) valueExtractor;

  ColumnInfo({
    required this.title,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    required this.valueExtractor,
  });
}

class PlagaNivelesScreen extends StatefulWidget {
  // Callback para notificar cambios en el modo de edición
  final Function(bool)? onEditModeChanged;

  const PlagaNivelesScreen({Key? key, this.onEditModeChanged})
      : super(key: key);

  @override
  State<PlagaNivelesScreen> createState() => _PlagaNivelesScreenState();
}

class _PlagaNivelesScreenState extends State<PlagaNivelesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Controladores para el formulario de plaga
  final TextEditingController _nombreComunController = TextEditingController();
  final TextEditingController _generoController = TextEditingController();
  final TextEditingController _familiaController = TextEditingController();
  final TextEditingController _tipoController = TextEditingController();

  // Controladores para niveles de infestación
  // Nivel 1
  final TextEditingController _nivel1RangoController = TextEditingController();
  final TextEditingController _nivel1LimInfController = TextEditingController();
  final TextEditingController _nivel1LimSupController = TextEditingController();
  final TextEditingController _nivel1ObservacionController = TextEditingController();
  final TextEditingController _nivel1CintaController = TextEditingController();
  final TextEditingController _nivel1TipoObsController = TextEditingController();

  // Nivel 2
  final TextEditingController _nivel2RangoController = TextEditingController();
  final TextEditingController _nivel2LimInfController = TextEditingController();
  final TextEditingController _nivel2LimSupController = TextEditingController();
  final TextEditingController _nivel2ObservacionController = TextEditingController();
  final TextEditingController _nivel2CintaController = TextEditingController();
  final TextEditingController _nivel2TipoObsController = TextEditingController();

  // Nivel 3
  final TextEditingController _nivel3RangoController = TextEditingController();
  final TextEditingController _nivel3LimInfController = TextEditingController();
  final TextEditingController _nivel3LimSupController = TextEditingController();
  final TextEditingController _nivel3ObservacionController = TextEditingController();
  final TextEditingController _nivel3CintaController = TextEditingController();
  final TextEditingController _nivel3TipoObsController = TextEditingController();

  // Variables para filtrado (separadas de las del formulario)
  String? _selectedTipoFiltro; // Para el dropdown de filtro de tipo
  String? _selectedEstadoFiltro; // Para el dropdown de filtro de estado

  // Variables para formulario de registro
  String? _selectedTipo;
  String? _selectedEstado;

  // Plaga actualmente en edición
  Plaga? _currentPlaga;
  List<NivelInfestacion> _nivelesSeleccionados = [];
  bool _isEditing = false;
  bool _isCreatingNew = false;

  // Colores del tema
  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color backgroundColor = Colors.white;
  final Color lightGrey = const Color(0xFFF5F5F5);

  // Variables para datos de la API
  List<Plaga> _plagaData = [];
  List<Plaga> _sortedPlagaData = [];
  Map<int, String> _tiposPlaga = {};
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // ApiConfig para centralización de URLs
  final ApiConfig _apiConfig = ApiConfig();

  // Servicios
  final PlagaService _plagaService = PlagaService();
  final NivelInfestacionService _nivelService = NivelInfestacionService();

  // Mapeo de estatus a nombres de estado
  final Map<int, String> _estatusMap = {
    1: 'Activo',
    0: 'Inactivo',
  };

  // Mapeo para estados en filtros
  final Map<String, String> _estatusFilterMap = {
    'Activo': '1',
    'Inactivo': '0',
  };

  // Variables para paginación
  int _paginaActual = 1;
  int _registrosPorPagina = 20;
  List<Plaga> _paginatedPlagaData = [];

  // Definición de columnas para la tabla
  late List<ColumnInfo> _columns;

  // Método para actualizar datos paginados
  void _updatePaginatedData() {
    if (_sortedPlagaData.isEmpty) {
      _paginatedPlagaData = [];
      return;
    }

    int startIndex = (_paginaActual - 1) * _registrosPorPagina;
    int endIndex = startIndex + _registrosPorPagina;

    if (endIndex > _sortedPlagaData.length) {
      endIndex = _sortedPlagaData.length;
    }

    _paginatedPlagaData = _sortedPlagaData.sublist(startIndex, endIndex);
  }

  // Método para cambiar de página
  void _cambiarPagina(int pagina) {
    setState(() {
      _paginaActual = pagina;
      _updatePaginatedData();
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Inicializar las columnas
    _columns = [
      ColumnInfo(
        title: 'ID',
        width: 80,
        valueExtractor: (plaga) => plaga.pmpl_id.toString(),
      ),
      ColumnInfo(
        title: 'Nombre Común',
        width: 200,
        valueExtractor: (plaga) => plaga.pmpl_nombrecomun ?? '-',
      ),
      ColumnInfo(
        title: 'Género',
        width: 150,
        valueExtractor: (plaga) => plaga.pmpl_genero ?? '-',
      ),
      ColumnInfo(
        title: 'Familia',
        width: 150,
        valueExtractor: (plaga) => plaga.pmpl_familia ?? '-',
      ),
      ColumnInfo(
        title: 'Tipo',
        width: 120,
        valueExtractor: (plaga) => plaga.pmpl_tipo ?? '-',
      ),
      ColumnInfo(
        title: 'Estado',
        width: 120,
        valueExtractor: (plaga) => _estatusMap[plaga.pmpl_estatus] ?? '-',
      ),
      ColumnInfo(
        title: 'Fecha Creación',
        width: 180,
        valueExtractor: (plaga) => plaga.pmpl_fechacreacion != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(plaga.pmpl_fechacreacion!)
            : '-',
      ),
    ];

    _tabController.addListener(() {
      if (mounted && _tabController.index == 0) {
        _clearForm();
      }
    });

    _apiConfig.addListener(_onApiConfigChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
        _loadTipos();
      }
    });
  }

  // Método para manejar cambios en la configuración de la API
  void _onApiConfigChanged() {
    if (mounted) {
      debugPrint("ApiConfig cambió. Recargando datos...");
      _loadData();
      _loadTipos();
    }
  }

  // Método para notificar el cambio en el modo de edición
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
          debugPrint('Ignorando actualización de modo de edición: $e');
        }
      }
    }
  }

  // Método para mostrar error de configuración
  void _showConfigurationError() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error de configuración'),
        content: const Text(
            'La API no está configurada correctamente. Por favor, configure la URL del servidor.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // Método CORREGIDO para cargar los tipos de plaga desde la API
  Future<void> _loadTipos() async {
    if (!mounted) return;

    try {
      if (!_apiConfig.isConfigured) {
        debugPrint("API no configurada. Usando valores predeterminados de tipos de plaga.");
        setState(() {
          _tiposPlaga = {1: 'Insecto', 2: 'Roedor', 3: 'Ácaro', 4: 'Otro'};
        });
        return;
      }

      debugPrint("Cargando tipos de plaga desde: ${_apiConfig.plagasUrl}/tipos");
      
      // CAMBIO: Obtener tipos desde la API
      try {
        final tiposMap = await _plagaService.getTiposPlagas();
        
        if (mounted) {
          setState(() {
            _tiposPlaga = tiposMap;
            debugPrint("✅ Tipos cargados desde API: ${_tiposPlaga.length}");
            debugPrint("Tipos disponibles: $_tiposPlaga");
          });
        }
      } catch (apiError) {
        debugPrint("❌ Error al obtener tipos desde API: $apiError");
        // Si falla la API, usar tipos hardcodeados pero intentar obtener desde datos existentes
        if (_plagaData.isNotEmpty) {
          final tiposUnicos = <String, int>{};
          int counter = 1;
          
          for (var plaga in _plagaData) {
            if (plaga.pmpl_tipo != null && plaga.pmpl_tipo!.isNotEmpty) {
              if (!tiposUnicos.containsKey(plaga.pmpl_tipo)) {
                tiposUnicos[plaga.pmpl_tipo!] = counter++;
              }
            }
          }
          
          if (mounted) {
            setState(() {
              _tiposPlaga = Map.fromEntries(
                tiposUnicos.entries.map((e) => MapEntry(e.value, e.key))
              );
              debugPrint("✅ Tipos extraídos de datos existentes: $_tiposPlaga");
            });
          }
        } else {
          // Fallback a tipos predeterminados
          if (mounted) {
            setState(() {
              _tiposPlaga = {1: 'Insecto', 2: 'Roedor', 3: 'Ácaro', 4: 'Otro'};
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error general cargando tipos: $e");
      if (mounted) {
        setState(() {
          _tiposPlaga = {1: 'Insecto', 2: 'Roedor', 3: 'Ácaro', 4: 'Otro'};
        });
      }
    }
  }

  // Método para ordenar las plagas
  void _sortPlagas(int columnIndex) {
    if (!mounted) return;

    setState(() {
      for (int i = 0; i < _columns.length; i++) {
        if (i != columnIndex) {
          _columns[i].isSorted = false;
        }
      }

      if (_columns[columnIndex].isSorted) {
        _columns[columnIndex].sortAscending = !_columns[columnIndex].sortAscending;
      } else {
        _columns[columnIndex].isSorted = true;
        _columns[columnIndex].sortAscending = true;
      }

      _sortedPlagaData.sort((a, b) {
        dynamic valueA = _columns[columnIndex].valueExtractor(a);
        dynamic valueB = _columns[columnIndex].valueExtractor(b);

        int result;
        if (valueA is String && valueB is String) {
          result = valueA.compareTo(valueB);
        } else if (valueA.toString().contains('/') && valueB.toString().contains('/')) {
          try {
            final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
            final dateA = dateFormat.parse(valueA);
            final dateB = dateFormat.parse(valueB);
            result = dateA.compareTo(dateB);
          } catch (e) {
            result = valueA.toString().compareTo(valueB.toString());
          }
        } else {
          try {
            final numA = num.parse(valueA.toString());
            final numB = num.parse(valueB.toString());
            result = numA.compareTo(numB);
          } catch (e) {
            result = valueA.toString().compareTo(valueB.toString());
          }
        }

        return _columns[columnIndex].sortAscending ? result : -result;
      });

      _paginaActual = 1;
      _updatePaginatedData();
    });
  }

  // Cargar datos de plagas desde la API
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente.');
      }

      debugPrint("Cargando plagas desde: ${_apiConfig.plagasUrl}");
      final plagas = await _plagaService.getPlagas();

      if (mounted) {
        setState(() {
          _plagaData = plagas;
          _sortedPlagaData = List<Plaga>.from(plagas);
          _paginaActual = 1;
          _updatePaginatedData();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos: $e';
        });
        _showMessage('Error al cargar datos. Por favor intente nuevamente.');

        if (e.toString().contains('API no está configurada')) {
          _showConfigurationError();
        }
      }
    }
  }

  // Método CORREGIDO para buscar plagas con filtros - ARREGLADO EL TIPO
  Future<void> _searchPlagas() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente.');
      }

      // Preparar parámetros de búsqueda - CORREGIDO PARA TIPO
      String? tipoParam;
      String? estatusParam;
      String? busquedaParam;

      // CORREGIR PROCESAMIENTO DE TIPO - Enviar el texto directamente, no el ID
      if (_selectedTipoFiltro != null && _selectedTipoFiltro!.isNotEmpty) {
        tipoParam = _selectedTipoFiltro; // Enviar directamente el texto del tipo
        debugPrint("🔧 Tipo para buscar: '$tipoParam'");
      }

      // Procesar estado seleccionado - VALIDACIÓN MEJORADA
      if (_selectedEstadoFiltro != null && _selectedEstadoFiltro!.isNotEmpty) {
        // Verificar que el valor existe en el mapa
        if (_estatusFilterMap.containsKey(_selectedEstadoFiltro)) {
          final rawEstatus = _estatusFilterMap[_selectedEstadoFiltro];
          
          // Validación adicional para números válidos
          if (rawEstatus == '0' || rawEstatus == '1') {
            estatusParam = rawEstatus;
          }
        }
      }

      // Procesar búsqueda de texto
      if (_searchController.text.trim().isNotEmpty) {
        busquedaParam = _searchController.text.trim();
      }

      debugPrint("🔍 Parámetros de búsqueda final:");
      debugPrint("   - Tipo: '$tipoParam'");
      debugPrint("   - Estatus: '$estatusParam'");
      debugPrint("   - Búsqueda: '$busquedaParam'");

      final plagas = await _plagaService.getPlagas(
        tipo: tipoParam,
        estatus: estatusParam,
        busqueda: busquedaParam,
      );

      if (mounted) {
        setState(() {
          _plagaData = plagas;
          _sortedPlagaData = List<Plaga>.from(plagas);
          _paginaActual = 1;
          _updatePaginatedData();
          _isLoading = false;
        });

        debugPrint("✅ Búsqueda completada: ${plagas.length} resultados");
      }
    } catch (e) {
      debugPrint("❌ Error en búsqueda: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al buscar plagas: $e';
        });
        _showMessage('Error al buscar plagas: $e');
      }
    }
  }

  // Método MODIFICADO para limpiar filtros e integrar con recargar
  void _clearFiltersAndReload() {
    if (!mounted) return;

    setState(() {
      // Limpiar filtros
      _selectedTipoFiltro = null;
      _selectedEstadoFiltro = null;
      _searchController.clear();
    });

    // Recargar datos y tipos
    _loadData();
    _loadTipos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nombreComunController.dispose();
    _generoController.dispose();
    _familiaController.dispose();
    _tipoController.dispose();
    _nivel1RangoController.dispose();
    _nivel1LimInfController.dispose();
    _nivel1LimSupController.dispose();
    _nivel1ObservacionController.dispose();
    _nivel1CintaController.dispose();
    _nivel1TipoObsController.dispose();
    _nivel2RangoController.dispose();
    _nivel2LimInfController.dispose();
    _nivel2LimSupController.dispose();
    _nivel2ObservacionController.dispose();
    _nivel2CintaController.dispose();
    _nivel2TipoObsController.dispose();
    _nivel3RangoController.dispose();
    _nivel3LimInfController.dispose();
    _nivel3LimSupController.dispose();
    _nivel3ObservacionController.dispose();
    _nivel3CintaController.dispose();
    _nivel3TipoObsController.dispose();
    _apiConfig.removeListener(_onApiConfigChanged);
    super.dispose();
  }

  // Limpiar el formulario completo
  void _clearForm() {
    if (!mounted) return;

    _nombreComunController.clear();
    _generoController.clear();
    _familiaController.clear();
    _tipoController.clear();
    _nivel1RangoController.clear();
    _nivel1LimInfController.clear();
    _nivel1LimSupController.clear();
    _nivel1ObservacionController.clear();
    _nivel1CintaController.clear();
    _nivel1TipoObsController.clear();
    _nivel2RangoController.clear();
    _nivel2LimInfController.clear();
    _nivel2LimSupController.clear();
    _nivel2ObservacionController.clear();
    _nivel2CintaController.clear();
    _nivel2TipoObsController.clear();
    _nivel3RangoController.clear();
    _nivel3LimInfController.clear();
    _nivel3LimSupController.clear();
    _nivel3ObservacionController.clear();
    _nivel3CintaController.clear();
    _nivel3TipoObsController.clear();

    if (mounted) {
      try {
        setState(() {
          _selectedTipo = null;
          _selectedEstado = null;
          _currentPlaga = null;
          _nivelesSeleccionados = [];
          _isEditing = false;
          _isCreatingNew = false;
          _errorMessage = '';
        });

        if (mounted && WidgetsBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
          _updateEditMode(false);
        }
      } catch (e) {
        debugPrint('Error al limpiar formulario: $e');
      }
    }
  }

  // Método para iniciar la creación de una nueva plaga
  void _nuevaPlaga() {
    _clearForm();
    if (!mounted) return;

    setState(() {
      _isCreatingNew = true;
      _isEditing = true;
      _selectedEstado = 'Activo';
    });

    _tabController.animateTo(1);
    _updateEditMode(true);
  }

  // Cargar plaga para editar
  Future<void> _editPlaga(Plaga plaga) async {
    if (!mounted) return;

    try {
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente.');
      }

      setState(() {
        _isLoading = true;
        _isCreatingNew = false;
      });

      debugPrint("Cargando plaga para editar con ID: ${plaga.pmpl_id}");

      final completePlaga = await _plagaService.getPlagaById(plaga.pmpl_id!);
      final niveles = await _nivelService.getNivelesPorPlaga(plaga.pmpl_id!);

      if (mounted) {
        setState(() {
          _currentPlaga = completePlaga;
          _nivelesSeleccionados = niveles;
          _isEditing = true;

          _nombreComunController.text = completePlaga.pmpl_nombrecomun ?? '';
          _generoController.text = completePlaga.pmpl_genero ?? '';
          _familiaController.text = completePlaga.pmpl_familia ?? '';
          _tipoController.text = completePlaga.pmpl_tipo ?? '';
          _selectedEstado = _estatusMap[completePlaga.pmpl_estatus];

          if (completePlaga.pmpl_tipo != null) {
            final tiposInverso = Map.fromEntries(
              _tiposPlaga.entries.map((e) => MapEntry(e.value, e.key)),
            );
            if (tiposInverso.containsKey(completePlaga.pmpl_tipo)) {
              _selectedTipo = completePlaga.pmpl_tipo;
            }
          }

          _cargarDatosNivelesEnFormulario(niveles);
          _isLoading = false;
          _errorMessage = '';
          _tabController.animateTo(1);
        });

        _updateEditMode(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar la plaga: $e';
        });
        _showMessage('Error al cargar la plaga: $e');

        if (e.toString().contains('API no está configurada')) {
          _showConfigurationError();
        }
      }
    }
  }

  // Cargar datos de niveles en el formulario
  void _cargarDatosNivelesEnFormulario(List<NivelInfestacion> niveles) {
    for (var nivel in niveles) {
      switch (nivel.pmni_nivel) {
        case 1:
          _nivel1RangoController.text = nivel.pmni_rango ?? '';
          _nivel1LimInfController.text = nivel.pmni_lminferior?.toString() ?? '';
          _nivel1LimSupController.text = nivel.pmni_lmsuperior?.toString() ?? '';
          _nivel1ObservacionController.text = nivel.pmni_observacion ?? '';
          _nivel1CintaController.text = nivel.pmni_cintaidentificadora ?? '';
          _nivel1TipoObsController.text = nivel.pmni_tipoobservacion ?? '';
          break;
        case 2:
          _nivel2RangoController.text = nivel.pmni_rango ?? '';
          _nivel2LimInfController.text = nivel.pmni_lminferior?.toString() ?? '';
          _nivel2LimSupController.text = nivel.pmni_lmsuperior?.toString() ?? '';
          _nivel2ObservacionController.text = nivel.pmni_observacion ?? '';
          _nivel2CintaController.text = nivel.pmni_cintaidentificadora ?? '';
          _nivel2TipoObsController.text = nivel.pmni_tipoobservacion ?? '';
          break;
        case 3:
          _nivel3RangoController.text = nivel.pmni_rango ?? '';
          _nivel3LimInfController.text = nivel.pmni_lminferior?.toString() ?? '';
          _nivel3LimSupController.text = nivel.pmni_lmsuperior?.toString() ?? '';
          _nivel3ObservacionController.text = nivel.pmni_observacion ?? '';
          _nivel3CintaController.text = nivel.pmni_cintaidentificadora ?? '';
          _nivel3TipoObsController.text = nivel.pmni_tipoobservacion ?? '';
          break;
      }
    }
  }

  // Guardar plaga con niveles
  Future<void> _savePlaga() async {
    if (!mounted) return;

    if (_nombreComunController.text.isEmpty) {
      _showMessage('Por favor ingrese el nombre común de la plaga');
      return;
    }

    if (_nivel1RangoController.text.isNotEmpty) {
      if (_nivel1LimInfController.text.isEmpty || _nivel1LimSupController.text.isEmpty) {
        _showMessage('Debe completar los límites inferior y superior para el nivel 1');
        return;
      }

      try {
        int limInf = int.parse(_nivel1LimInfController.text);
        int limSup = int.parse(_nivel1LimSupController.text);
        if (limInf >= limSup) {
          _showMessage('El límite inferior debe ser menor que el límite superior en el nivel 1');
          return;
        }
      } catch (e) {
        _showMessage('Los límites deben ser valores numéricos válidos');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente.');
      }

      final Plaga plaga = _isEditing && !_isCreatingNew ? _currentPlaga!.copyWith() : Plaga();

      plaga.pmpl_nombrecomun = _nombreComunController.text.trim();
      plaga.pmpl_genero = _generoController.text.trim();
      plaga.pmpl_familia = _familiaController.text.trim();
      plaga.pmpl_tipo = _tipoController.text.trim();

      final estatus = _estatusMap.map((k, v) => MapEntry(v, k));
      plaga.pmpl_estatus = _selectedEstado != null ? estatus[_selectedEstado] ?? 1 : 1;

      if (_isCreatingNew) {
        plaga.pmpl_creadopor = 1;
        plaga.pmpl_fechacreacion = DateTime.now();
      } else {
        plaga.pmpl_modificadopor = 1;
        plaga.pmpl_fechamodificacion = DateTime.now();
      }

      Plaga plagaGuardada;
      if (_isEditing && !_isCreatingNew) {
        plagaGuardada = await _plagaService.actualizarPlaga(plaga);
      } else {
        plagaGuardada = await _plagaService.crearPlaga(plaga);
      }

      if (_nivel1RangoController.text.isNotEmpty ||
          _nivel2RangoController.text.isNotEmpty ||
          _nivel3RangoController.text.isNotEmpty) {
        List<NivelInfestacion> nivelesAGuardar = _crearObjetosNivelesInfestacion(
            plagaGuardada.pmpl_id!, plagaGuardada.pmpl_nombrecomun!);

        for (var nivel in nivelesAGuardar) {
          if (nivel.pmni_secuencia != null) {
            await _nivelService.actualizarNivelInfestacion(nivel);
          } else {
            await _nivelService.crearNivelInfestacion(nivel);
          }
        }
      }

      await _loadData();

      if (mounted) {
        _showMessage(_isCreatingNew ? 'Plaga creada correctamente' : 'Plaga actualizada correctamente');
        _clearForm();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al guardar: $e';
        });
        _showMessage('Error: $e');

        if (e.toString().contains('API no está configurada')) {
          _showConfigurationError();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _updateEditMode(false);
      }
    }
  }

  // Crear objetos de niveles de infestación
  List<NivelInfestacion> _crearObjetosNivelesInfestacion(int plagaId, String nombreComun) {
    List<NivelInfestacion> niveles = [];

    if (_nivel1RangoController.text.isNotEmpty) {
      NivelInfestacion nivel1 = NivelInfestacion(
        pmni_nivel: 1,
        pmni_plaga: plagaId,
        pmni_nombrecomun: nombreComun,
        pmni_rango: _nivel1RangoController.text.trim(),
        pmni_lminferior: int.tryParse(_nivel1LimInfController.text) ?? 0,
        pmni_lmsuperior: int.tryParse(_nivel1LimSupController.text) ?? 0,
        pmni_tipoobservacion: _nivel1TipoObsController.text.trim(),
        pmni_observacion: _nivel1ObservacionController.text.trim(),
        pmni_cintaidentificadora: _nivel1CintaController.text.trim(),
        pmni_estatus: 1,
      );

      if (!_isCreatingNew && _nivelesSeleccionados.isNotEmpty) {
        final nivelExistente = _nivelesSeleccionados.firstWhere(
            (n) => n.pmni_nivel == 1, orElse: () => NivelInfestacion());
        if (nivelExistente.pmni_secuencia != null) {
          nivel1 = nivel1.copyWith(
            pmni_secuencia: nivelExistente.pmni_secuencia,
            pmni_modificadopor: 1,
            pmni_fechamodificacion: DateTime.now(),
          );
        } else {
          nivel1 = nivel1.copyWith(
            pmni_creadopor: 1,
            pmni_fechacreacion: DateTime.now(),
          );
        }
      } else {
        nivel1 = nivel1.copyWith(
          pmni_creadopor: 1,
          pmni_fechacreacion: DateTime.now(),
        );
      }

      niveles.add(nivel1);
    }

    if (_nivel2RangoController.text.isNotEmpty) {
      NivelInfestacion nivel2 = NivelInfestacion(
        pmni_nivel: 2,
        pmni_plaga: plagaId,
        pmni_nombrecomun: nombreComun,
        pmni_rango: _nivel2RangoController.text.trim(),
        pmni_lminferior: int.tryParse(_nivel2LimInfController.text) ?? 0,
        pmni_lmsuperior: int.tryParse(_nivel2LimSupController.text) ?? 0,
        pmni_tipoobservacion: _nivel2TipoObsController.text.trim(),
        pmni_observacion: _nivel2ObservacionController.text.trim(),
        pmni_cintaidentificadora: _nivel2CintaController.text.trim(),
        pmni_estatus: 1,
      );

      if (!_isCreatingNew && _nivelesSeleccionados.isNotEmpty) {
        final nivelExistente = _nivelesSeleccionados.firstWhere(
            (n) => n.pmni_nivel == 2, orElse: () => NivelInfestacion());
        if (nivelExistente.pmni_secuencia != null) {
          nivel2 = nivel2.copyWith(
            pmni_secuencia: nivelExistente.pmni_secuencia,
            pmni_modificadopor: 1,
            pmni_fechamodificacion: DateTime.now(),
          );
        } else {
          nivel2 = nivel2.copyWith(
            pmni_creadopor: 1,
            pmni_fechacreacion: DateTime.now(),
          );
        }
      } else {
        nivel2 = nivel2.copyWith(
          pmni_creadopor: 1,
          pmni_fechacreacion: DateTime.now(),
        );
      }

      niveles.add(nivel2);
    }

    if (_nivel3RangoController.text.isNotEmpty) {
      NivelInfestacion nivel3 = NivelInfestacion(
        pmni_nivel: 3,
        pmni_plaga: plagaId,
        pmni_nombrecomun: nombreComun,
        pmni_rango: _nivel3RangoController.text.trim(),
        pmni_lminferior: int.tryParse(_nivel3LimInfController.text) ?? 0,
        pmni_lmsuperior: int.tryParse(_nivel3LimSupController.text) ?? 0,
        pmni_tipoobservacion: _nivel3TipoObsController.text.trim(),
        pmni_observacion: _nivel3ObservacionController.text.trim(),
        pmni_cintaidentificadora: _nivel3CintaController.text.trim(),
        pmni_estatus: 1,
      );

      if (!_isCreatingNew && _nivelesSeleccionados.isNotEmpty) {
        final nivelExistente = _nivelesSeleccionados.firstWhere(
            (n) => n.pmni_nivel == 3, orElse: () => NivelInfestacion());
        if (nivelExistente.pmni_secuencia != null) {
          nivel3 = nivel3.copyWith(
            pmni_secuencia: nivelExistente.pmni_secuencia,
            pmni_modificadopor: 1,
            pmni_fechamodificacion: DateTime.now(),
          );
        } else {
          nivel3 = nivel3.copyWith(
            pmni_creadopor: 1,
            pmni_fechacreacion: DateTime.now(),
          );
        }
      } else {
        nivel3 = nivel3.copyWith(
          pmni_creadopor: 1,
          pmni_fechacreacion: DateTime.now(),
        );
      }

      niveles.add(nivel3);
    }

    return niveles;
  }

  // Eliminar plaga
  void _deletePlaga(Plaga plaga) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro que desea eliminar la plaga ${plaga.pmpl_nombrecomun}?'),
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
                if (!_apiConfig.isConfigured) {
                  throw Exception('La API no está configurada correctamente.');
                }

                debugPrint("Eliminando plaga con ID: ${plaga.pmpl_id}");

                final success = await _plagaService.eliminarPlaga(plaga.pmpl_id!);

                if (success && mounted) {
                  await _loadData();
                  _showMessage('Plaga eliminada correctamente');
                } else if (mounted) {
                  _showMessage('No se pudo eliminar la plaga');
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('Error al eliminar plaga: $e');

                  if (e.toString().contains('API no está configurada')) {
                    _showConfigurationError();
                  }
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

  // Mostrar mensaje
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Widget para celda de encabezado redimensionable y ordenable
  Widget _buildResizableHeaderCell(int columnIndex) {
    final column = _columns[columnIndex];

    return GestureDetector(
      onTap: () => _sortPlagas(columnIndex),
      child: Container(
        width: column.width,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              column.title,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (column.isSorted)
              Icon(
                column.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  // Widget para encabezado de tabla redimensionable
  Widget _buildSortableTableHeader() {
    return Container(
      color: const Color(0xFFF9F9F9),
      child: Row(
        children: [
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_columns.length, (index) {
                  return Stack(
                    children: [
                      _buildResizableHeaderCell(index),
                      if (index < _columns.length - 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              if (mounted) {
                                setState(() {
                                  final newWidth = _columns[index].width + details.delta.dx;
                                  if (newWidth > 60) {
                                    _columns[index].width = newWidth;
                                  }
                                });
                              }
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: Container(
                                width: 8,
                                color: Colors.transparent,
                                child: Center(
                                  child: Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir celdas de datos
  Widget _buildDataCell(String text, double width) {
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
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

  // Widget para campos de formulario
  Widget _buildFormField(
    String label,
    String hint, {
    bool enabled = true,
    bool required = false,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF505050),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
          ],
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
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: InputBorder.none,
              fillColor: enabled ? Colors.white : Colors.grey[100],
              filled: true,
            ),
            onChanged: (value) {
              if (_tabController.index == 1) {
                _updateEditMode(true);
              }
            },
          ),
        ),
      ],
    );
  }

  // Widget para campos de selección (dropdown)
  Widget _buildDropdownField(
    String label,
    String hint,
    List<String> options, {
    String? value,
    Function(String?)? onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF505050),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
          ],
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
              items: options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (onChanged != null) {
                  onChanged(newValue);
                }
                if (_tabController.index == 1) {
                  _updateEditMode(true);
                }
              },
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }

  // Widget para formulario de nivel de infestación
  Widget _buildNivelForm(
    String titulo,
    TextEditingController rangoController,
    TextEditingController limInfController,
    TextEditingController limSupController,
    TextEditingController tipoObsController,
    TextEditingController cintaController,
    TextEditingController observacionController,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildFormField(
                    'Rango *',
                    'Ej: 1 ~ 3 individuos',
                    controller: rangoController,
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    'Límite Inferior *',
                    'Valor mínimo',
                    controller: limInfController,
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    'Límite Superior *',
                    'Valor máximo',
                    controller: limSupController,
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    'Tipo de Observación',
                    'Tipo de observación',
                    controller: tipoObsController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    'Cinta Identificadora',
                    'Color o código',
                    controller: cintaController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Observación',
              'Descripción detallada',
              controller: observacionController,
            ),
          ],
        ),
      ),
    );
  }

  // Mostrar detalles de niveles de infestación
  void _verNivelesInfestacion(Plaga plaga) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente.');
      }

      final niveles = await _nivelService.getNivelesPorPlaga(plaga.pmpl_id!);

      if (mounted) {
        setState(() => _isLoading = false);

        if (niveles.isEmpty) {
          _showMessage('No hay niveles de infestación definidos para esta plaga');
          return;
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Niveles de infestación - ${plaga.pmpl_nombrecomun}'),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var nivel in niveles)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nivel ${nivel.pmni_nivel} - ${nivel.pmni_rango}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailItem('Límite Inferior:', '${nivel.pmni_lminferior}'),
                                  ),
                                  Expanded(
                                    child: _buildDetailItem('Límite Superior:', '${nivel.pmni_lmsuperior}'),
                                  ),
                                ],
                              ),
                              _buildDetailItem('Tipo Observación:', nivel.pmni_tipoobservacion ?? 'N/A'),
                              _buildDetailItem('Cinta Identificadora:', nivel.pmni_cintaidentificadora ?? 'N/A'),
                              _buildDetailItem('Observación:', nivel.pmni_observacion ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
                  _editPlaga(plaga);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Editar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar niveles: $e';
        });
        _showMessage('Error al cargar niveles: $e');

        if (e.toString().contains('API no está configurada')) {
          _showConfigurationError();
        }
      }
    }
  }

  // Construir elemento de detalle para el diálogo
  Widget _buildDetailItem(String label, String value) {
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

  // Widget para mostrar filtros activos (OPCIONAL)
  Widget _buildActiveFiltersIndicator() {
    final activeFilters = <String>[];
    
    if (_selectedTipoFiltro != null) {
      activeFilters.add('Tipo: $_selectedTipoFiltro');
    }
    if (_selectedEstadoFiltro != null) {
      activeFilters.add('Estado: $_selectedEstadoFiltro');
    }
    if (_searchController.text.isNotEmpty) {
      activeFilters.add('Búsqueda: "${_searchController.text}"');
    }
    
    if (activeFilters.isEmpty) return Container();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: primaryColor.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            'Filtros activos: ${activeFilters.join(' • ')}',
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearFiltersAndReload,
            icon: Icon(Icons.clear, size: 14, color: primaryColor),
            label: Text('Limpiar', style: TextStyle(color: primaryColor, fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // Construir la vista de consulta CORREGIDA SIN BANNER DE API
  Widget _buildConsultaTab() {
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
            // Indicador de filtros activos (opcional)
            _buildActiveFiltersIndicator(),

            // SECCIÓN DE FILTROS CORREGIDA
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Campo Nombre/Familia
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nombre / Familia',
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
                                  hintText: 'Buscar por nombre o familia...',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Campo Tipo CORREGIDO PARA MOSTRAR TIPOS DINÁMICOS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tipo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF505050),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTipoFiltro,
                                  isExpanded: true,
                                  hint: Text(
                                    'Todos los tipos',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Todos los tipos'),
                                    ),
                                    // MOSTRAR TIPOS ORDENADOS ALFABÉTICAMENTE
                                    ...(_tiposPlaga.values.toList()..sort()).map((String tipo) {
                                      return DropdownMenuItem<String>(
                                        value: tipo,
                                        child: Text(tipo),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (String? value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedTipoFiltro = value;
                                      });
                                      debugPrint("🔧 Tipo filtro seleccionado: $value");
                                    }
                                  },
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Campo Estado (sin cambios)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF505050),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedEstadoFiltro,
                                  isExpanded: true,
                                  hint: Text(
                                    'Todos los estados',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Todos los estados'),
                                    ),
                                    const DropdownMenuItem<String>(
                                      value: 'Activo',
                                      child: Text('Activo'),
                                    ),
                                    const DropdownMenuItem<String>(
                                      value: 'Inactivo',
                                      child: Text('Inactivo'),
                                    ),
                                  ],
                                  onChanged: (String? value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedEstadoFiltro = value;
                                      });
                                      debugPrint("🔧 Estado filtro seleccionado: $value");
                                    }
                                  },
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // Tabla de plagas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text(_errorMessage, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadData, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _buildSortableTableHeader(),
                            _paginatedPlagaData.isEmpty
                                ? Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No hay plagas para mostrar',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Intenta ajustar los filtros de búsqueda',
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: _paginatedPlagaData.map((plaga) {
                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Columna de acciones fija
                                              Container(
                                                width: 140,
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
                                                    InkWell(
                                                      onTap: () => _verNivelesInfestacion(plaga),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: Colors.transparent,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Icon(Icons.visibility_outlined, size: 20, color: accentColor),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    InkWell(
                                                      onTap: () => _editPlaga(plaga),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: Colors.transparent,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Icon(Icons.edit_outlined, size: 20, color: primaryColor),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    InkWell(
                                                      onTap: () => _deletePlaga(plaga),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: Colors.transparent,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
                                                    children: List.generate(_columns.length, (index) {
                                                      final column = _columns[index];
                                                      final value = column.valueExtractor(plaga);

                                                      if (column.title == 'Estado') {
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
                                                      } else {
                                                        return _buildDataCell(value, column.width);
                                                      }
                                                    }),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
            ),

            // Widget de paginación
            PaginationWidget(
              totalItems: _sortedPlagaData.length,
              currentPage: _paginaActual,
              itemsPerPage: _registrosPorPagina,
              onPageChanged: _cambiarPagina,
              primaryColor: primaryColor,
              textColor: const Color(0xFF505050),
              itemsLabel: 'plagas',
            ),
          ],
        ),
      ),
    );
  }

  // Construir la vista de registro
  Widget _buildRegistroTab() {
    return Container(
      color: lightGrey,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Text(
                      _isCreatingNew ? 'Nueva Plaga' : 'Editar Plaga y Niveles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_errorMessage, style: TextStyle(color: Colors.red.shade800)),
                      ),

                    // Panel de información de la plaga
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información de la Plaga',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildFormField(
                                  'Nombre Común',
                                  'Nombre común de la plaga',
                                  controller: _nombreComunController,
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  'Género',
                                  'Género científico',
                                  controller: _generoController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  'Familia',
                                  'Familia científica',
                                  controller: _familiaController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdownField(
                                  'Tipo',
                                  'Seleccione tipo de plaga',
                                  _tiposPlaga.values.toList(),
                                  value: _selectedTipo,
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedTipo = value;
                                        _tipoController.text = value ?? '';
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdownField(
                                  'Estado',
                                  'Seleccione estado',
                                  ['Activo', 'Inactivo'],
                                  value: _selectedEstado,
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedEstado = value;
                                      });
                                    }
                                  },
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título de niveles
                    Row(
                      children: [
                        Text(
                          'Niveles de Infestación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Opcional',
                            style: TextStyle(fontSize: 12, color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Niveles de infestación
                    _buildNivelForm(
                      'Nivel 1',
                      _nivel1RangoController,
                      _nivel1LimInfController,
                      _nivel1LimSupController,
                      _nivel1TipoObsController,
                      _nivel1CintaController,
                      _nivel1ObservacionController,
                    ),

                    _buildNivelForm(
                      'Nivel 2',
                      _nivel2RangoController,
                      _nivel2LimInfController,
                      _nivel2LimSupController,
                      _nivel2TipoObsController,
                      _nivel2CintaController,
                      _nivel2ObservacionController,
                    ),

                    _buildNivelForm(
                      'Nivel 3',
                      _nivel3RangoController,
                      _nivel3LimInfController,
                      _nivel3LimSupController,
                      _nivel3TipoObsController,
                      _nivel3CintaController,
                      _nivel3ObservacionController,
                    ),

                    const SizedBox(height: 32),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            _clearForm();
                            _tabController.animateTo(0);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _savePlaga,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: Text(_isCreatingNew ? 'Guardar' : 'Actualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Método principal MODIFICADO de construcción de la interfaz
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de navegación de pestañas CON BOTONES RESTAURADOS
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Pestañas
              SizedBox(
                width: 200,
                child: TabBar(
                  controller: _tabController,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Consulta'),
                    Tab(text: 'Registro'),
                  ],
                ),
              ),

              Expanded(child: Container()),

              // BOTONES RESTAURADOS EN SU POSICIÓN ORIGINAL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Botón Buscar
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchPlagas,
                      icon: _isLoading 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: Text(_isLoading ? 'Buscando...' : 'Buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Nueva
                    ElevatedButton.icon(
                      onPressed: _nuevaPlaga,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Nueva'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Recargar/Limpiar MODIFICADO
                    ElevatedButton.icon(
                      onPressed: _clearFiltersAndReload,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Recargar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
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
              _buildConsultaTab(),
              _buildRegistroTab(),
            ],
          ),
        ),
      ],
    );
  }
}