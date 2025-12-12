import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/unidad_cultivo_model.dart';
import '../../../services/unidad_cultivo_service.dart';
import '../../../core/config/flavor_config.dart';
import '../../widgets/pagination_widget.dart';

// Clase para manejar la información de las columnas
class ColumnInfo {
  final String title;
  double width;
  bool isSorted;
  bool sortAscending;
  final Function(UnidadCultivo) valueExtractor;

  ColumnInfo({
    required this.title,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    required this.valueExtractor,
  });
}

class UnidadCultivoScreen extends StatefulWidget {
  final Function(bool)? onEditModeChanged;

  const UnidadCultivoScreen({Key? key, this.onEditModeChanged})
      : super(key: key);

  @override
  State<UnidadCultivoScreen> createState() => _UnidadCultivoScreenState();
}

class _UnidadCultivoScreenState extends State<UnidadCultivoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Controladores para el formulario
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _canteroController = TextEditingController();
  final TextEditingController _idExternoController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();

  // Variables para valores seleccionados en dropdowns
  String? _selectedEstado;
  String? _selectedUbicacion;

  // Ubicaciones disponibles
  List<String> _ubicacionesDisponibles = [];

  // Unidad actualmente en edición
  UnidadCultivo? _currentUnidad;
  bool _isEditing = false;
  bool _isCreatingNew = false;

  // Colores del tema
  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color backgroundColor = Colors.white;
  final Color lightGrey = const Color(0xFFF5F5F5);

  // Variables para datos de la API
  List<UnidadCultivo> _unidadData = [];
  List<UnidadCultivo> _sortedUnidadData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Variables para paginación
  int _currentPage = 1;
  int _itemsPerPage = 20;
  int _totalItems = 0;

  // Servicio de unidades de cultivo
  final UnidadCultivoService _unidadService = UnidadCultivoService();

  // Mapeo de estatus a nombres de estado
  final Map<int, String> _estatusMap = {
    1: 'Activo',
    0: 'Inactivo',
  };

  // Definición de columnas para la tabla
  late List<ColumnInfo> _columns;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Inicializar las columnas
    _columns = [
      ColumnInfo(
        title: 'ID',
        width: 80,
        valueExtractor: (unidad) => unidad.secuencia.toString(),
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
        title: 'Ubicación',
        width: 140,
        valueExtractor: (unidad) => unidad.ubicacion ?? '-',
      ),
      ColumnInfo(
        title: 'ID Externo',
        width: 120,
        valueExtractor: (unidad) => unidad.id.toString(),
      ),
      ColumnInfo(
        title: 'Estado',
        width: 120,
        valueExtractor: (unidad) => _estatusMap[unidad.estatus] ?? '-',
      ),
      ColumnInfo(
        title: 'Fecha Creación',
        width: 180,
        valueExtractor: (unidad) {
          if (unidad.fechaCreacion != null &&
              unidad.fechaCreacion!.isNotEmpty) {
            try {
              final DateTime date = DateTime.parse(unidad.fechaCreacion!);
              return DateFormat('dd/MM/yyyy HH:mm').format(date);
            } catch (e) {
              return unidad.fechaCreacion ?? '-';
            }
          }
          return '-';
        },
      ),
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
        _loadUbicaciones();
        _loadData();
      }
    });
  }

  // Cargar ubicaciones dinámicamente
  Future<void> _loadUbicaciones() async {
    try {
      final ubicaciones = await _unidadService.getUbicaciones();
      if (mounted) {
        setState(() {
          _ubicacionesDisponibles = ['Todos', ...ubicaciones];
        });
        print('Ubicaciones cargadas: $_ubicacionesDisponibles');
      }
    } catch (e) {
      print('Error al cargar ubicaciones: $e');
      if (mounted) {
        setState(() {
          _ubicacionesDisponibles = ['Todos'];
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

  // Método para ordenar las unidades según la columna seleccionada
  void _sortUnidades(int columnIndex) {
    if (!mounted) return;

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

      _sortedUnidadData.sort((a, b) {
        dynamic valueA = _columns[columnIndex].valueExtractor(a);
        dynamic valueB = _columns[columnIndex].valueExtractor(b);

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

        return _columns[columnIndex].sortAscending ? result : -result;
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
    if (_unidadData.isEmpty) {
      _sortedUnidadData = [];
      return;
    }

    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (endIndex > _unidadData.length) {
      endIndex = _unidadData.length;
    }

    if (startIndex >= _unidadData.length) {
      _currentPage = (_unidadData.length / _itemsPerPage).ceil();
      return _applyPagination();
    }

    _sortedUnidadData = _unidadData.sublist(startIndex, endIndex);
  }

  // Cargar datos de unidades desde la API
  // REEMPLAZAR el método _loadData() (línea 340 aproximadamente):
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final unidades = await _unidadService.getUnidadesCultivo();

      if (mounted) {
        setState(() {
          _unidadData = unidades;
          _totalItems = unidades.length;
          _currentPage = 1;
          _applyPagination();
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
      }
    }
  }

  // Método de búsqueda actualizado con filtro de ubicación y códigos
  // REEMPLAZAR el método _searchUnidades() (línea 375 aproximadamente):
  Future<void> _searchUnidades() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final estatusMap = _estatusMap.map((k, v) => MapEntry(v, k.toString()));

      String? estatusValue;
      if (_selectedEstado != null && _selectedEstado != 'Todos') {
        estatusValue = estatusMap[_selectedEstado];
      }

      String? ubicacionValue;
      if (_selectedUbicacion != null && _selectedUbicacion != 'Todos') {
        ubicacionValue = _selectedUbicacion;
      }

      String? busquedaValue;
      if (_searchController.text.isNotEmpty) {
        busquedaValue = _searchController.text;
      }

      print(
          'Buscando con: busqueda=$busquedaValue, estatus=$estatusValue, ubicacion=$ubicacionValue');

      final unidades = await _unidadService.getUnidadesCultivo(
        busqueda: busquedaValue,
        estatus: estatusValue,
        ubicacion: ubicacionValue,
      );

      if (mounted) {
        setState(() {
          _unidadData = unidades;
          _totalItems = unidades.length;
          _currentPage = 1;
          _applyPagination();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al buscar unidades: $e';
        });
        _showMessage('Error al buscar unidades: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _codigoController.dispose();
    _canteroController.dispose();
    _idExternoController.dispose();
    _ubicacionController.dispose();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onEditModeChanged?.call(false);
    });

    super.dispose();
  }

  // Limpiar el formulario
  void _clearForm() {
    if (!mounted) return;

    setState(() {
      _codigoController.clear();
      _canteroController.clear();
      _idExternoController.clear();
      _ubicacionController.clear();
      _selectedEstado = null;
      _selectedUbicacion = null;
      _currentUnidad = null;
      _isEditing = false;
      _isCreatingNew = false;
      _errorMessage = '';
    });

    _updateEditMode(false);
  }

  // Cargar unidad para editar
  Future<void> _editUnidad(UnidadCultivo unidad) async {
    if (!mounted) return;

    try {
      final completeUnidad =
          await _unidadService.getUnidadCultivoById(unidad.secuencia);

      if (mounted) {
        setState(() {
          _currentUnidad = completeUnidad;
          _isEditing = true;
          _isCreatingNew = false;
          _codigoController.text = completeUnidad.codigo;
          _canteroController.text = completeUnidad.cantero;
          _idExternoController.text = completeUnidad.id.toString();
          _ubicacionController.text = completeUnidad.ubicacion ?? '';
          _selectedEstado = _estatusMap[completeUnidad.estatus];
          _errorMessage = '';

          _tabController.animateTo(1);
        });

        _updateEditMode(true);
      }
    } catch (e) {
      _showMessage('Error al cargar la unidad: $e');
    }
  }

  // Nueva unidad
  void _nuevaUnidad() {
    _clearForm();
    if (!mounted) return;

    setState(() {
      _isCreatingNew = true;
      _isEditing = false;
      _selectedEstado = 'Activo';
    });

    _tabController.animateTo(1);
    _updateEditMode(true);
  }

  // Guardar unidad (crear o actualizar)
  Future<void> _saveUnidad() async {
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      if (_codigoController.text.isEmpty ||
          _canteroController.text.isEmpty ||
          _idExternoController.text.isEmpty ||
          _selectedEstado == null) {
        _showMessage('Por favor complete todos los campos obligatorios');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      final estatus = _estatusMap.map((k, v) => MapEntry(v, k));

      if (_isEditing && _currentUnidad != null) {
        var updatedUnidad = _currentUnidad!.copyWith(
          codigo: _codigoController.text,
          cantero: _canteroController.text,
          id: int.tryParse(_idExternoController.text) ?? 0,
          estatus: estatus[_selectedEstado] ?? 1,
          ubicacion: _ubicacionController.text.isNotEmpty
              ? _ubicacionController.text
              : null,
          modificadoPor: 1,
        );

        final success = await _unidadService.updateUnidadCultivo(updatedUnidad);

        if (success && mounted) {
          await _loadUbicaciones();
          await _loadData();
          _showMessage('Unidad actualizada correctamente');

          _clearForm();
          _tabController.animateTo(0);
        }
      } else {
        final newUnidad = UnidadCultivo.nueva(
          codigo: _codigoController.text,
          cantero: _canteroController.text,
          id: int.tryParse(_idExternoController.text) ?? 0,
          estatus: estatus[_selectedEstado] ?? 1,
          ubicacion: _ubicacionController.text.isNotEmpty
              ? _ubicacionController.text
              : null,
          creadoPor: 1,
        );

        final newSecuencia =
            await _unidadService.createUnidadCultivo(newUnidad);

        if (newSecuencia > 0 && mounted) {
          await _loadUbicaciones();
          await _loadData();
          _showMessage('Unidad creada correctamente');

          _clearForm();
          _tabController.animateTo(0);
        }
      }
    } catch (e) {
      _showMessage('Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al guardar: $e';
        });
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

  // Eliminar unidad
  void _deleteUnidad(UnidadCultivo unidad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Está seguro que desea eliminar la unidad ${unidad.codigo}?'),
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
                final success =
                    await _unidadService.deleteUnidadCultivo(unidad.secuencia);

                if (success && mounted) {
                  await _loadData();
                  _showMessage('Unidad eliminada correctamente');
                } else if (mounted) {
                  _showMessage('No se pudo eliminar la unidad');
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('Error al eliminar unidad: $e');
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

  // ===== SECCIÓN DE FILTROS MEJORADA =====

  // REEMPLAZAR _buildFiltrosSection() (línea 730 aproximadamente):
  Widget _buildFiltrosSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Campo de búsqueda general
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Búsqueda General',
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
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, cantero...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.grey.shade400, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade400, size: 18),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Filtro por ubicación
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubicación',
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
                      value: _selectedUbicacion ?? 'Todos',
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _ubicacionesDisponibles.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child:
                              Text(value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (mounted) {
                          setState(() {
                            _selectedUbicacion =
                                value == 'Todos' ? null : value;
                          });
                        }
                      },
                      icon: Icon(Icons.arrow_drop_down,
                          color: Colors.grey.shade600, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Filtro por estado
          Expanded(
            flex: 1,
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
                      value: _selectedEstado ?? 'Todos',
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items:
                          ['Todos', 'Activo', 'Inactivo'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child:
                              Text(value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (mounted) {
                          setState(() {
                            _selectedEstado = value == 'Todos' ? null : value;
                          });
                        }
                      },
                      icon: Icon(Icons.arrow_drop_down,
                          color: Colors.grey.shade600, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para celda de encabezado redimensionable y ordenable
  Widget _buildResizableHeaderCell(int columnIndex) {
    final column = _columns[columnIndex];

    return GestureDetector(
      onTap: () => _sortUnidades(columnIndex),
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
          // Columna de acciones fija
          Container(
            width: 100,
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

          // Encabezados redimensionables
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
                                  final newWidth =
                                      _columns[index].width + details.delta.dx;
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

  // Widget para campos de formulario
  Widget _buildFormField(
    String label,
    String hint, {
    bool enabled = true,
    bool required = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
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
            keyboardType: keyboardType,
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

  // Construir la vista de consulta con la tabla de unidades
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
            _buildFiltrosSection(),

            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // Tabla de unidades
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
                            _buildSortableTableHeader(),
                            _sortedUnidadData.isEmpty
                                ? Expanded(
                                    child: Center(
                                      child: Text(
                                        'No hay unidades de cultivo para mostrar',
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
                                        children:
                                            _sortedUnidadData.map((unidad) {
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Columna de acciones fija
                                              Container(
                                                width: 100,
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
                                                    InkWell(
                                                      onTap: () =>
                                                          _editUnidad(unidad),
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
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
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: () =>
                                                          _deleteUnidad(unidad),
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
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
                                                      final value =
                                                          column.valueExtractor(
                                                              unidad);

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

            PaginationWidget(
              totalItems: _totalItems,
              itemsPerPage: _itemsPerPage,
              currentPage: _currentPage,
              onPageChanged: _onPageChanged,
              primaryColor: primaryColor,
              textColor: const Color(0xFF505050),
              itemsLabel: 'unidades de cultivo',
            ),
          ],
        ),
      ),
    );
  }

  // Construir la vista de registro con el formulario de unidad
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
                      _isEditing
                          ? 'Editar Unidad de Cultivo'
                          : 'Nueva Unidad de Cultivo',
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

                    // Panel de información
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
                            'Información de la Unidad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          // Primera fila de formulario
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  'Código',
                                  'Ingrese código de unidad',
                                  controller: _codigoController,
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  'Cantero',
                                  'Ingrese cantero',
                                  controller: _canteroController,
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Segunda fila de formulario
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  'ID Externo',
                                  'Ingrese ID externo',
                                  controller: _idExternoController,
                                  keyboardType: TextInputType.number,
                                  required: true,
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
                          const SizedBox(height: 16),

                          // Tercera fila - UBICACIÓN TYPEABLE
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  'Ubicación',
                                  'Ingrese ubicación (ej: La Romana, Sabana de la mar)',
                                  controller: _ubicacionController,
                                  required: false,
                                ),
                              ),
                              const Expanded(child: SizedBox()),
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
                            foregroundColor:
                                const Color.fromARGB(175, 245, 11, 2),
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
                          onPressed: _isSubmitting ? null : _saveUnidad,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 255, 255, 255),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            disabledBackgroundColor: Colors.grey.shade400,
                            foregroundColor:
                                const Color.fromARGB(255, 93, 93, 94),
                          ),
                          child: Text(_isEditing ? 'Actualizar' : 'Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Método principal de construcción de la interfaz
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de navegación de pestañas (Consulta/Registro)
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
                    ElevatedButton.icon(
                      onPressed: _searchUnidades,
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Buscar'),
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
                    ElevatedButton.icon(
                      onPressed: _nuevaUnidad,
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
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _loadUbicaciones();
                        await _loadData();
                      },
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
