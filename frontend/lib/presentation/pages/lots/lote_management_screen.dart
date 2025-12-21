import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/lote_model.dart';
import '../../../services/lote_service.dart';
import '../../../services/excel_service.dart';
import '../../widgets/pagination_widget.dart';
//import '../../widgets/searchable_variedad_selector.dart';

// Clase para manejar la información de las columnas
class ColumnInfo {
  final String title;
  double width;
  bool isSorted;
  bool sortAscending;
  final Function(Lote) valueExtractor;

  ColumnInfo({
    required this.title,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    required this.valueExtractor,
  });
}

class LoteManagementScreen extends StatefulWidget {
  final Function(bool)? onEditModeChanged;

  const LoteManagementScreen({Key? key, this.onEditModeChanged})
      : super(key: key);

  @override
  State<LoteManagementScreen> createState() => _LoteManagementScreenState();
}

class _LoteManagementScreenState extends State<LoteManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Controladores para el formulario de lote
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _canterosController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _contenedorController = TextEditingController();
  final TextEditingController _growerController = TextEditingController();
  final TextEditingController _casaController = TextEditingController();

  // Variables para filtros (SEPARADAS del formulario)
  String? _selectedVariedadFiltro;
  String? _selectedEstadoFiltro = null;

  // Variables para formulario (SEPARADAS de los filtros)
  String? _selectedVariedad;
  String? _selectedEstado;
  int? _selectedVariedadId;
  String? _selectedVariedadCodigo;

  // Lote actualmente en edición
  Lote? _currentLote;
  bool _isEditing = false;
  bool _isCreatingNew = false;
  bool _isImporting = false;
  bool _isExporting = false;

  // Colores del tema
  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color backgroundColor = Colors.white;
  final Color lightGrey = const Color(0xFFF5F5F5);

  // Variables para datos de la API
  List<Lote> _loteData = [];
  List<Lote> _sortedLoteData = [];
  Map<int, String> _variedadesMap = {};
  Map<int, String> _variedadesCodigoMap = {};
  Map<String, int> _codigoVariedadesMap = {};

  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Servicios
  final LoteService _loteService = LoteService();
  final ExcelService _excelService = ExcelService();

  // Mapeo de estatus a nombres de estado
  final Map<int, String> _estatusMap = {
    1: 'Activo',
    0: 'Inactivo',
  };

  // Mapeo para filtros de estado
  final Map<String, String> _estatusFilterMap = {
    'Activo': '1',
    'Inactivo': '0',
  };

  // Variables para paginación
  int _paginaActual = 1;
  int _registrosPorPagina = 20;
  List<Lote> _paginatedLoteData = [];

  // Definición de columnas para la tabla
  late List<ColumnInfo> _columns;

  @override
  void initState() {
    super.initState();

    // AGREGAR DIAGNÓSTICO DEL NAVEGADOR
    ExcelService.diagnosticarNavegador();

    _tabController = TabController(length: 2, vsync: this);

    // Inicializar las columnas con sus anchos predeterminados
    _columns = [
      ColumnInfo(
        title: 'ID',
        width: 80,
        valueExtractor: (lote) => lote.pmlt_secuencia.toString(),
      ),
      ColumnInfo(
        title: 'Código',
        width: 150,
        valueExtractor: (lote) => lote.pmlt_codigo ?? '-',
      ),
      ColumnInfo(
        title: 'Canteros',
        width: 150,
        valueExtractor: (lote) => lote.pmlt_canteros ?? '-',
      ),
      ColumnInfo(
        title: 'Cantidad',
        width: 120,
        valueExtractor: (lote) => lote.pmlt_cantidad?.toString() ?? '-',
      ),
      ColumnInfo(
        title: 'Variedad',
        width: 150,
        valueExtractor: (lote) => lote.pmlt_variedad ?? '-',
      ),
      ColumnInfo(
        title: 'Contenedor',
        width: 150,
        valueExtractor: (lote) => lote.pmlt_contenedor ?? '-',
      ),
      ColumnInfo(
        title: 'Grower',
        width: 150,
        valueExtractor: (lote) => lote.pmlt_grower ?? '-',
      ),
      ColumnInfo(
        title: 'Casa',
        width: 120,
        valueExtractor: (lote) => lote.pmlt_casa ?? '-',
      ),
      ColumnInfo(
        title: 'Estado',
        width: 120,
        valueExtractor: (lote) => _estatusMap[lote.pmlt_estatus] ?? '-',
      ),
      ColumnInfo(
        title: 'Fecha Creación',
        width: 180,
        valueExtractor: (lote) => lote.pmlt_fechacreacion != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(lote.pmlt_fechacreacion!)
            : '-',
      ),
    ];

    // Escuchar cambios de tab para limpiar el formulario
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _clearForm();
      }
    });

    // Cargar datos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData().then((_) {
        _loadVariedades();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _codigoController.dispose();
    _canterosController.dispose();
    _cantidadController.dispose();
    _contenedorController.dispose();
    _growerController.dispose();
    _casaController.dispose();

    if (widget.onEditModeChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEditModeChanged?.call(false);
      });
    }

    super.dispose();
  }

  // Método para actualizar datos paginados
  void _updatePaginatedData() {
    if (_sortedLoteData.isEmpty) {
      _paginatedLoteData = [];
      return;
    }

    int startIndex = (_paginaActual - 1) * _registrosPorPagina;
    int endIndex = startIndex + _registrosPorPagina;

    if (endIndex > _sortedLoteData.length) {
      endIndex = _sortedLoteData.length;
    }

    _paginatedLoteData = _sortedLoteData.sublist(startIndex, endIndex);
  }

  // Método para cambiar de página
  void _cambiarPagina(int pagina) {
    setState(() {
      _paginaActual = pagina;
      _updatePaginatedData();
    });
  }

  // Método para notificar el cambio en el modo de edición
  void _updateEditMode(bool isEditing) {
    if (widget.onEditModeChanged != null && mounted) {
      widget.onEditModeChanged!(isEditing);
    }
  }

  // Cargar variedades desde la API
  Future<void> _loadVariedades() async {
    try {
      debugPrint("🔄 Cargando variedades desde la API...");

      final dynamic resultado = await _loteService.getVariedades();
      debugPrint("📥 Respuesta de API variedades: $resultado");

      if (mounted) {
        setState(() {
          _variedadesMap = {};
          _variedadesCodigoMap = {};
          _codigoVariedadesMap = {};

          // Extraer variedades de los lotes cargados primero
          Set<String> variedadesEncontradas = {};
          for (var lote in _loteData) {
            if (lote.pmlt_variedad != null && lote.pmlt_variedad!.isNotEmpty) {
              variedadesEncontradas.add(lote.pmlt_variedad!);
            }
          }

          debugPrint(
              "🔍 Variedades encontradas en lotes: $variedadesEncontradas");

          // Procesamiento de la respuesta de la API
          bool cargadoDesdeAPI = false;

          if (resultado != null) {
            try {
              if (resultado is Map &&
                  resultado.containsKey('data') &&
                  resultado['data'] is List) {
                final List<dynamic> variedadesList =
                    resultado['data'] as List<dynamic>;
                debugPrint(
                    "📊 Procesando lista de variedades: ${variedadesList.length} elementos");

                for (var i = 0; i < variedadesList.length; i++) {
                  final variedad = variedadesList[i];
                  if (variedad is Map<String, dynamic>) {
                    _procesarVariedadSegura(variedad);
                    cargadoDesdeAPI = true;
                  }
                }
              } else if (resultado is List) {
                debugPrint(
                    "📊 Procesando lista directa: ${resultado.length} elementos");
                for (var i = 0; i < resultado.length; i++) {
                  final variedad = resultado[i];
                  if (variedad is Map<String, dynamic>) {
                    _procesarVariedadSegura(variedad);
                    cargadoDesdeAPI = true;
                  }
                }
              } else if (resultado is Map) {
                final keys = resultado.keys.toList();
                debugPrint("📊 Procesando mapa: ${keys.length} keys");

                for (var i = 0; i < keys.length; i++) {
                  final key = keys[i];
                  final value = resultado[key];

                  debugPrint(
                      "🔍 Procesando entrada de mapa: key=$key, value=$value");

                  if (value is Map<String, dynamic>) {
                    if (!value.containsKey('id') &&
                        !value.containsKey('pmvr_secuencia')) {
                      value['id'] = key.toString();
                    }
                    _procesarVariedadSegura(value);
                    cargadoDesdeAPI = true;
                  } else if (value is Map) {
                    final Map<String, dynamic> convertedValue = {};
                    value.forEach((k, v) {
                      convertedValue[k.toString()] = v;
                    });

                    if (!convertedValue.containsKey('id') &&
                        !convertedValue.containsKey('pmvr_secuencia')) {
                      convertedValue['id'] = key.toString();
                    }
                    _procesarVariedadSegura(convertedValue);
                    cargadoDesdeAPI = true;
                  }
                }
              }
            } catch (e) {
              debugPrint("❌ Error procesando respuesta de API: $e");
            }
          }

          // Agregar variedades de los lotes
          int idCounter = _variedadesMap.keys.isNotEmpty
              ? _variedadesMap.keys.reduce((a, b) => a > b ? a : b) + 1
              : 1;
          for (String variedad in variedadesEncontradas) {
            if (!_variedadesMap.values.contains(variedad)) {
              _variedadesMap[idCounter] = variedad;
              _variedadesCodigoMap[idCounter] = idCounter.toString();
              _codigoVariedadesMap[idCounter.toString()] = idCounter;

              debugPrint(
                  "✅ Variedad agregada de lotes: ID=$idCounter, Desc=$variedad");
              idCounter++;
            }
          }

          // Datos de respaldo final solo si no hay ninguna variedad
          if (_variedadesMap.isEmpty) {
            debugPrint(
                "⚠️ No se encontraron variedades, usando datos de respaldo");
            _cargarVariedadesRespaldo();
          }

          debugPrint("📊 Total variedades cargadas: ${_variedadesMap.length}");
          debugPrint(
              "🗂️ Variedades disponibles: ${_variedadesMap.values.join(', ')}");
        });
      }
    } catch (e) {
      debugPrint("❌ Error cargando variedades: $e");
      if (mounted) {
        setState(() {
          _variedadesMap = {};
          _variedadesCodigoMap = {};
          _codigoVariedadesMap = {};

          Set<String> variedadesEncontradas = {};
          for (var lote in _loteData) {
            if (lote.pmlt_variedad != null && lote.pmlt_variedad!.isNotEmpty) {
              variedadesEncontradas.add(lote.pmlt_variedad!);
            }
          }

          int idCounter = 1;
          for (String variedad in variedadesEncontradas) {
            _variedadesMap[idCounter] = variedad;
            _variedadesCodigoMap[idCounter] = idCounter.toString();
            _codigoVariedadesMap[idCounter.toString()] = idCounter;
            idCounter++;
          }

          if (_variedadesMap.isEmpty) {
            _cargarVariedadesRespaldo();
          }
        });
      }
    }
  }

  // Método auxiliar para procesar una variedad de manera segura
  void _procesarVariedadSegura(Map<String, dynamic> variedad) {
    try {
      final descripcion = variedad['descripcion']?.toString() ??
          variedad['pmvr_descripcion']?.toString() ??
          variedad['nombre']?.toString() ??
          'Sin descripción';

      final idRaw =
          variedad['id'] ?? variedad['pmvr_secuencia'] ?? variedad['codigo'];

      final codigo = variedad['codigo']?.toString() ??
          variedad['pmvr_codigo']?.toString() ??
          idRaw?.toString() ??
          '0';

      int? id;
      if (idRaw is int) {
        id = idRaw;
      } else if (idRaw != null) {
        id = int.tryParse(idRaw.toString());
      }

      if (id != null &&
          descripcion.isNotEmpty &&
          descripcion != 'Sin descripción') {
        _variedadesMap[id] = descripcion;
        _variedadesCodigoMap[id] = codigo;
        _codigoVariedadesMap[codigo] = id;

        debugPrint(
            "✅ Variedad procesada: ID=$id, Código=$codigo, Desc=$descripcion");
      } else {
        debugPrint(
            "⚠️ Variedad omitida - datos insuficientes: ID=$id, Desc=$descripcion");
      }
    } catch (e) {
      debugPrint("❌ Error procesando variedad individual: $e");
    }
  }

  // Método auxiliar para cargar variedades de respaldo
  void _cargarVariedadesRespaldo() {
    _variedadesMap = {
      1: 'Adenium Obesum',
      2: 'Epipremnnum Aureum',
      3: 'Mandevilla Splendens',
      4: 'Variedad Genérica'
    };
    _variedadesCodigoMap = {1: '1', 2: '2', 3: '3', 4: '4'};
    _codigoVariedadesMap = {'1': 1, '2': 2, '3': 3, '4': 4};
    debugPrint(
        "📋 Cargadas variedades de respaldo: ${_variedadesMap.values.join(', ')}");
  }

  // Cargar datos de lotes desde la API
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint("Cargando lotes desde la API...");

      final lotes = await _loteService.getLotes();

      if (mounted) {
        setState(() {
          _loteData = lotes;
          _sortedLoteData = List<Lote>.from(lotes);
          _paginaActual = 1;
          _updatePaginatedData();
          _isLoading = false;
        });

        debugPrint("✅ Lotes cargados: ${lotes.length} registros");
      }
    } catch (e) {
      debugPrint("❌ Error cargando lotes: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos: $e';
        });
        _showMessage('Error al cargar datos. Por favor intente nuevamente.');
      }
    }
  }

  // Buscar lotes con filtros
  Future<void> _searchLotes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String? descripcionVariedadParam;
      String? estatusParam;
      String? busquedaParam;

      if (_selectedVariedadFiltro != null &&
          _selectedVariedadFiltro!.isNotEmpty) {
        descripcionVariedadParam = _selectedVariedadFiltro;
        debugPrint(
            "🔧 Filtro variedad: Enviando descripción directa -> '$descripcionVariedadParam'");
      }

      if (_selectedEstadoFiltro != null &&
          _selectedEstadoFiltro!.isNotEmpty &&
          _selectedEstadoFiltro != 'Todos') {
        estatusParam = _selectedEstadoFiltro;
        debugPrint(
            "🔧 Filtro estado: '$_selectedEstadoFiltro' -> '$estatusParam'");
      } else {
        estatusParam = null;
        debugPrint("🔧 Filtro estado: Sin selección -> SIN FILTRO (null)");
      }

      if (_searchController.text.trim().isNotEmpty) {
        busquedaParam = _searchController.text.trim();
        debugPrint("🔧 Filtro búsqueda: '$busquedaParam'");
      }

      debugPrint("🔍 Parámetros enviados al backend:");
      debugPrint("   - Descripción variedad: $descripcionVariedadParam");
      debugPrint("   - Estatus: $estatusParam");
      debugPrint("   - Búsqueda: $busquedaParam");

      final lotes = await _loteService.getLotes(
        codigoVariedad: descripcionVariedadParam,
        estatus: estatusParam,
        busqueda: busquedaParam,
      );

      if (mounted) {
        setState(() {
          _loteData = lotes;
          _sortedLoteData = List<Lote>.from(lotes);
          _paginaActual = 1;
          _updatePaginatedData();
          _isLoading = false;
        });

        debugPrint(
            "✅ Búsqueda completada: ${lotes.length} resultados encontrados");
      }
    } catch (e) {
      debugPrint("❌ Error en búsqueda: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al buscar lotes: $e';
        });
        _showMessage('Error al buscar lotes: $e');
      }
    }
  }

  // Limpiar solo los filtros y recargar
  Future<void> _clearFiltersAndReload() async {
    setState(() {
      _selectedVariedadFiltro = null;
      _selectedEstadoFiltro = null;
      _searchController.clear();
    });

    debugPrint("🧹 Filtros limpiados - Recargando datos...");
    await _loadData();
    await _loadVariedades();
  }

  // Limpiar el formulario completo
  void _clearForm() {
    if (!mounted) return;

    setState(() {
      _codigoController.clear();
      _canterosController.clear();
      _cantidadController.clear();
      _contenedorController.clear();
      _growerController.clear();
      _casaController.clear();

      _selectedVariedad = null;
      _selectedVariedadId = null;
      _selectedVariedadCodigo = null;
      _selectedEstado = null;
      _currentLote = null;
      _isEditing = false;
      _isCreatingNew = false;
      _errorMessage = '';
    });

    _updateEditMode(false);
  }

  // Método para ordenar los lotes según la columna seleccionada
  void _sortLotes(int columnIndex) {
    setState(() {
      for (int i = 0; i < _columns.length; i++) {
        if (i != columnIndex) {
          _columns[i].isSorted = false;
        }
      }

      if (_columns[columnIndex].isSorted) {
        _columns[columnIndex].sortAscending =
            !_columns[columnIndex].sortAscending;
      } else {
        _columns[columnIndex].isSorted = true;
        _columns[columnIndex].sortAscending = true;
      }

      _sortedLoteData.sort((a, b) {
        dynamic valueA = _columns[columnIndex].valueExtractor(a);
        dynamic valueB = _columns[columnIndex].valueExtractor(b);

        int result;

        if (valueA is String && valueB is String) {
          result = valueA.compareTo(valueB);
        } else if (valueA.toString().contains('/') &&
            valueB.toString().contains('/')) {
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

  // Método para iniciar la creación de un nuevo lote
  void _nuevoLote() {
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

  // Cargar lote para editar
  Future<void> _editLote(Lote lote) async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _isCreatingNew = false;
      });

      debugPrint("Cargando lote para editar con ID: ${lote.pmlt_secuencia}");

      final completeLote = await _loteService.getLoteById(lote.pmlt_secuencia!);

      if (mounted) {
        setState(() {
          _currentLote = completeLote;
          _isEditing = true;

          _codigoController.text = completeLote.pmlt_codigo ?? '';
          _canterosController.text = completeLote.pmlt_canteros ?? '';
          _cantidadController.text =
              completeLote.pmlt_cantidad?.toString() ?? '';
          _contenedorController.text = completeLote.pmlt_contenedor ?? '';
          _growerController.text = completeLote.pmlt_grower ?? '';
          _casaController.text = completeLote.pmlt_casa ?? '';

          String? codigoVariedad = completeLote.pmlt_idvariedad?.toString();
          _selectedVariedadCodigo = codigoVariedad;

          if (codigoVariedad != null &&
              _codigoVariedadesMap.containsKey(codigoVariedad)) {
            _selectedVariedadId = _codigoVariedadesMap[codigoVariedad];
            _selectedVariedad = _variedadesMap[_selectedVariedadId];
          } else if (completeLote.pmlt_variedad != null &&
              completeLote.pmlt_variedad!.isNotEmpty) {
            _selectedVariedad = completeLote.pmlt_variedad;

            final entry = _variedadesMap.entries.firstWhere(
              (entry) =>
                  entry.value.toLowerCase() == _selectedVariedad!.toLowerCase(),
              orElse: () => const MapEntry(-1, ''),
            );

            if (entry.key != -1) {
              _selectedVariedadId = entry.key;
              _selectedVariedadCodigo = _variedadesCodigoMap[entry.key];
            }
          }

          _selectedEstado = _estatusMap[completeLote.pmlt_estatus];
          _isLoading = false;
          _errorMessage = '';

          _tabController.animateTo(1);
        });

        _updateEditMode(true);
      }
    } catch (e) {
      debugPrint("❌ Error cargando lote: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar el lote: $e';
        });
        _showMessage('Error al cargar el lote: $e');
      }
    }
  }

  // Guardar lote
  Future<void> _saveLote() async {
    if (_codigoController.text.isEmpty) {
      _showMessage('Por favor ingrese el código del lote');
      return;
    }

    if (_cantidadController.text.isEmpty) {
      _showMessage('Por favor ingrese la cantidad');
      return;
    }

    if (_selectedVariedad == null) {
      _showMessage('Por favor seleccione una variedad');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final Lote lote =
          _isEditing && !_isCreatingNew ? _currentLote!.copyWith() : Lote();

      lote.pmlt_codigo = _codigoController.text.trim();
      lote.pmlt_canteros = _canterosController.text.trim();
      lote.pmlt_cantidad = int.tryParse(_cantidadController.text.trim()) ?? 0;
      lote.pmlt_contenedor = _contenedorController.text.trim();
      lote.pmlt_grower = _growerController.text.trim();
      lote.pmlt_casa = _casaController.text.trim();

      final estatus = _estatusMap.map((k, v) => MapEntry(v, k));
      lote.pmlt_estatus =
          _selectedEstado != null ? estatus[_selectedEstado] ?? 1 : 1;

      if (_selectedVariedad != null) {
        final entry = _variedadesMap.entries.firstWhere(
          (entry) => entry.value == _selectedVariedad,
          orElse: () => const MapEntry(-1, ''),
        );

        if (entry.key != -1) {
          int variedadId = entry.key;
          String variedadCodigo = _variedadesCodigoMap[variedadId] ?? '';

          lote.pmlt_idvariedad = int.tryParse(variedadCodigo);
          lote.pmlt_variedad = entry.value;

          debugPrint(
              "Guardando lote con: ID Variedad=$variedadId, Código=$variedadCodigo, Descripción=${entry.value}");
        } else {
          lote.pmlt_variedad = _selectedVariedad;
        }
      }

      if (_isCreatingNew) {
        lote.pmlt_creadopor = 1;
        lote.pmlt_fechacreacion = DateTime.now();
      } else {
        lote.pmlt_modificadopor = 1;
        lote.pmlt_fechamodificacion = DateTime.now();
      }

      Lote loteGuardado;
      if (_isEditing && !_isCreatingNew) {
        loteGuardado = await _loteService.actualizarLote(lote);
      } else {
        loteGuardado = await _loteService.crearLote(lote);
      }

      await _loadData();

      _showMessage(_isCreatingNew
          ? 'Lote creado correctamente'
          : 'Lote actualizado correctamente');

      _clearForm();
      _tabController.animateTo(0);
    } catch (e) {
      debugPrint("❌ Error guardando lote: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al guardar: $e';
        });
        _showMessage('Error: $e');
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

  // Eliminar lote
  void _deleteLote(Lote lote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Está seguro que desea eliminar el lote ${lote.pmlt_codigo}?'),
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
                debugPrint("Eliminando lote con ID: ${lote.pmlt_secuencia}");

                final success =
                    await _loteService.eliminarLote(lote.pmlt_secuencia!);

                if (success) {
                  await _loadData();
                  _showMessage('Lote eliminado correctamente');
                } else {
                  _showMessage('No se pudo eliminar el lote');
                }
              } catch (e) {
                _showMessage('Error al eliminar lote: $e');
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

  // MÉTODOS SIMPLIFICADOS PARA EXCEL USANDO EL SERVICIO
  Future<void> _exportarExcel() async {
    if (!mounted) return;

    try {
      await _excelService.exportarExcel(
        context,
        _sortedLoteData,
        _estatusMap,
        _showMessage,
        (isExporting) {
          if (mounted) {
            setState(() {
              _isExporting = isExporting;
            });
          }
        },
      );
    } catch (e) {
      _showMessage('Error al exportar Excel: $e');
      debugPrint('Error detallado: $e');
    }
  }

  Future<void> _importarExcel() async {
    if (!mounted) return;

    try {
      //await _excelService.importarExcel(
      //viejo metodo no tomaba en cuenta los cambios recientes
      await _excelService.importarExcelModerno(
        context,
        _variedadesMap,
        _codigoVariedadesMap,
        _loadData,
        _showMessage,
        (isImporting) {
          if (mounted) {
            setState(() {
              _isImporting = isImporting;
            });
          }
        },
      );
    } catch (e) {
      _showMessage('Error al importar Excel: $e');
    }
  }

  // Widget para celda de encabezado redimensionable y ordenable
  Widget _buildResizableHeaderCell(int columnIndex) {
    final column = _columns[columnIndex];

    return GestureDetector(
      onTap: () => _sortLotes(columnIndex),
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
                              setState(() {
                                final newWidth =
                                    _columns[index].width + details.delta.dx;
                                if (newWidth > 60) {
                                  _columns[index].width = newWidth;
                                }
                              });
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

  // Widget dropdown para formulario
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
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              hint: Text(hint),
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

  // Construir indicador de filtros activos
  Widget _buildActiveFiltersIndicator() {
    List<String> activeFilters = [];

    if (_selectedVariedadFiltro != null) {
      activeFilters.add('Variedad: $_selectedVariedadFiltro');
    }
    if (_selectedEstadoFiltro != null) {
      activeFilters.add('Estado: $_selectedEstadoFiltro');
    }
    if (_searchController.text.isNotEmpty) {
      activeFilters.add('Búsqueda: ${_searchController.text}');
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtros activos: ${activeFilters.join(', ')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearFiltersAndReload,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              'Limpiar filtros',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Construir la vista de consulta con filtros
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
            // Filtros de búsqueda
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Campo Código/Grower
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Código / Grower',
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
                                  hintText: 'Buscar por código o grower...',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[400], fontSize: 13),
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
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Campo Variedad
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Variedad',
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
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedVariedadFiltro,
                                  isExpanded: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  hint: Text(
                                    'Todas las variedades',
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 13),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Todas las variedades'),
                                    ),
                                    ..._variedadesMap.values
                                        .where((desc) => desc.isNotEmpty)
                                        .toSet()
                                        .toList()
                                        .map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (String? value) {
                                    setState(() {
                                      _selectedVariedadFiltro = value;
                                    });
                                    debugPrint(
                                        "🔧 Variedad filtro seleccionada: $_selectedVariedadFiltro");
                                  },
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Campo Estado
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
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedEstadoFiltro,
                                  isExpanded: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  hint: Text(
                                    'Todos los estados',
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 13),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Todos los estados'),
                                    ),
                                    ...['Activo', 'Inactivo']
                                        .map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }),
                                  ],
                                  onChanged: (String? value) {
                                    setState(() {
                                      _selectedEstadoFiltro = value;
                                    });
                                    debugPrint(
                                        "🔧 Estado filtro seleccionado: $_selectedEstadoFiltro");
                                  },
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Mostrar conteo de resultados
                  if (_loteData.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Mostrando ${_sortedLoteData.length} lotes de ${_loteData.length} total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Indicador de filtros activos
            _buildActiveFiltersIndicator(),

            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // Tabla de lotes
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
                                style: TextStyle(color: Colors.red),
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
                            _buildSortableTableHeader(),
                            _paginatedLoteData.isEmpty
                                ? Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.inbox_outlined,
                                            size: 64,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No se encontraron lotes',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Intenta ajustar los filtros de búsqueda',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children:
                                            _paginatedLoteData.map((lote) {
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Columna de acciones fija
                                              Container(
                                                width: 140,
                                                height: 48,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: BorderSide(
                                                        color: Colors
                                                            .grey.shade200),
                                                    bottom: BorderSide(
                                                        color: Colors
                                                            .grey.shade200),
                                                  ),
                                                  color: Colors.white,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Botón de editar
                                                    InkWell(
                                                      onTap: () =>
                                                          _editLote(lote),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Icon(
                                                          Icons.edit_outlined,
                                                          size: 20,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    // Botón de eliminar
                                                    InkWell(
                                                      onTap: () =>
                                                          _deleteLote(lote),
                                                      child: Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: const Icon(
                                                          Icons.delete_outline,
                                                          size: 20,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Datos desplazables
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    children: List.generate(
                                                        _columns.length,
                                                        (index) {
                                                      final column =
                                                          _columns[index];
                                                      final value = column
                                                          .valueExtractor(lote);

                                                      // Celda especial para el estado
                                                      if (column.title ==
                                                          'Estado') {
                                                        return Container(
                                                          width: column.width,
                                                          height: 48,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      16),
                                                          decoration:
                                                              BoxDecoration(
                                                            border: Border(
                                                              bottom: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200),
                                                              right: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200),
                                                            ),
                                                          ),
                                                          child: Center(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: value ==
                                                                        'Activo'
                                                                    ? const Color(
                                                                        0xFFE7F5E7)
                                                                    : const Color(
                                                                        0xFFFCE8E8),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child: Text(
                                                                value,
                                                                style:
                                                                    TextStyle(
                                                                  color: value ==
                                                                          'Activo'
                                                                      ? const Color(
                                                                          0xFF219653)
                                                                      : const Color(
                                                                          0xFFE53935),
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        return _buildDataCell(
                                                            value,
                                                            column.width);
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
              totalItems: _sortedLoteData.length,
              currentPage: _paginaActual,
              itemsPerPage: _registrosPorPagina,
              onPageChanged: _cambiarPagina,
              primaryColor: primaryColor,
              textColor: const Color(0xFF505050),
              itemsLabel: 'lotes',
            ),
          ],
        ),
      ),
    );
  }

  // Construir la vista de registro con formulario
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
                      _isCreatingNew ? 'Nuevo Lote' : 'Editar Lote',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mensaje de error si existe
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),

                    // Panel de información del lote
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
                            'Información del Lote',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          // Primera fila
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  'Código',
                                  'Código del lote',
                                  controller: _codigoController,
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  'Canteros',
                                  'Canteros del lote',
                                  controller: _canterosController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  'Cantidad',
                                  'Cantidad de plantas',
                                  controller: _cantidadController,
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Segunda fila
                          Row(
                            children: [
                              // Dropdown Variedad
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Variedad',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF505050),
                                          ),
                                        ),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                        color: Colors.white,
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedVariedad,
                                          isExpanded: true,
                                          hint: Text(
                                            'Seleccione variedad',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 13,
                                            ),
                                          ),
                                          items: _variedadesMap.values
                                              .where((desc) => desc.isNotEmpty)
                                              .toSet()
                                              .toList()
                                              .map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                value,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedVariedad = newValue;

                                                final entry = _variedadesMap
                                                    .entries
                                                    .firstWhere(
                                                  (entry) =>
                                                      entry.value == newValue,
                                                  orElse: () => const MapEntry<
                                                      int, String>(-1, ''),
                                                );

                                                if (entry.key != -1) {
                                                  _selectedVariedadId =
                                                      entry.key;
                                                  debugPrint(
                                                      "✅ Variedad seleccionada: $newValue (ID: $_selectedVariedadId)");
                                                }
                                              });

                                              if (_tabController.index == 1) {
                                                _updateEditMode(true);
                                              }
                                            }
                                          },
                                          icon: Icon(Icons.arrow_drop_down,
                                              color: Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  'Contenedor',
                                  'Tipo de contenedor',
                                  controller: _contenedorController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Dropdown Estado
                              Expanded(
                                child: _buildDropdownField(
                                  'Estado',
                                  'Seleccione estado',
                                  ['Activo', 'Inactivo'],
                                  value: _selectedEstado,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedEstado = value;
                                    });
                                    if (_tabController.index == 1) {
                                      _updateEditMode(true);
                                    }
                                  },
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Tercera fila
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  'Grower',
                                  'Nombre del grower',
                                  controller: _growerController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  'Casa',
                                  'Casa de cultivo',
                                  controller: _casaController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Mostrar ID de Variedad (solo como referencia)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ID Variedad',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF505050),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                        color: Colors.grey[100],
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _selectedVariedadId?.toString() ??
                                              '-',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveLote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child:
                              Text(_isCreatingNew ? 'Guardar' : 'Actualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de navegación de pestañas
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
              bottom: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
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
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Consulta'),
                    Tab(text: 'Registro'),
                  ],
                ),
              ),

              Expanded(child: Container()),

              // Botones de acción
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Botón Buscar
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchLotes,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: Text(_isLoading ? 'Buscando...' : 'Buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Nuevo
                    ElevatedButton.icon(
                      onPressed: _nuevoLote,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Nuevo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Recargar
                    ElevatedButton.icon(
                      onPressed: _clearFiltersAndReload,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Recargar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Importar Excel
                    ElevatedButton.icon(
                      onPressed: _isImporting ? null : _importarExcel,
                      icon: _isImporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.upload_file, size: 20),
                      label: Text(_isImporting ? 'Importando...' : 'Importar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Exportar Excel
                    ElevatedButton.icon(
                      onPressed: _isExporting
                          ? null
                          : (_sortedLoteData.isEmpty ? null : _exportarExcel),
                      icon: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.download, size: 20),
                      label: Text(_isExporting ? 'Exportando...' : 'Exportar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 14),
                        disabledBackgroundColor: Colors.grey.shade400,
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
