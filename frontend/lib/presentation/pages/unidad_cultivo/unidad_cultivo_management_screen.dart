import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importar intl para formateo de fechas
import '../../../models/unidad_cultivo_model.dart';
import '../../../services/unidad_cultivo_service.dart';
import '../../../core/config/flavor_config.dart'; // Importar configuración centralizada
import '../../widgets/pagination_widget.dart'; // Importar widget de paginación

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
  // Callback para notificar cambios en el modo de edición
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

  // Variable para el valor seleccionado en dropdown
  String? _selectedEstado;

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
  // Lista para datos ordenados
  List<UnidadCultivo> _sortedUnidadData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Variables para paginación
  int _currentPage = 1;
  int _itemsPerPage = 20; // Puedes ajustar este valor según tus necesidades
  int _totalItems = 0;

  // Servicio de unidades de cultivo con ApiConfig centralizada
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

    // Inicializar las columnas con sus anchos predeterminados
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
              // Intentar parsear la fecha a DateTime
              final DateTime date = DateTime.parse(unidad.fechaCreacion!);
              // Formatear la fecha como dd/MM/yyyy HH:mm
              return DateFormat('dd/MM/yyyy HH:mm').format(date);
            } catch (e) {
              // Si hay error al parsear, mostrar fecha original
              return unidad.fechaCreacion ?? '-';
            }
          }
          return '-';
        },
      ),
    ];

    // Escuchar cambios de tab pero verificando si está montado
    _tabController.addListener(() {
      if (mounted && _tabController.index == 0) {
        _clearForm();
      }
    });

    // Cargar datos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Método para notificar el cambio en el modo de edición de manera segura
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
      // Restablecer el estado de ordenamiento de otras columnas
      for (int i = 0; i < _columns.length; i++) {
        if (i != columnIndex) {
          _columns[i].isSorted = false;
        }
      }

      // Alternar el orden de la columna actual
      if (_columns[columnIndex].isSorted) {
        _columns[columnIndex].sortAscending =
            !_columns[columnIndex].sortAscending;
      } else {
        _columns[columnIndex].isSorted = true;
        _columns[columnIndex].sortAscending = true;
      }

      // Aplicar el ordenamiento
      _sortedUnidadData.sort((a, b) {
        dynamic valueA = _columns[columnIndex].valueExtractor(a);
        dynamic valueB = _columns[columnIndex].valueExtractor(b);

        int result;

        // Manejar diferentes tipos de datos
        if (valueA is String && valueB is String) {
          // Ordenamiento de texto
          result = valueA.compareTo(valueB);
        } else {
          // Intento de ordenamiento numérico si es posible
          try {
            final numA = num.parse(valueA.toString());
            final numB = num.parse(valueB.toString());
            result = numA.compareTo(numB);
          } catch (e) {
            // Si no se puede convertir a número, ordenar como texto
            result = valueA.toString().compareTo(valueB.toString());
          }
        }

        // Aplicar sentido de ordenamiento (ascendente/descendente)
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

    // Calcular índices de inicio y fin para la página actual
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    // Asegurarse de que el índice final no exceda el total de elementos
    if (endIndex > _unidadData.length) {
      endIndex = _unidadData.length;
    }

    // Si el índice de inicio es mayor que el tamaño de la lista, ajustar a la última página
    if (startIndex >= _unidadData.length) {
      _currentPage = (_unidadData.length / _itemsPerPage).ceil();
      return _applyPagination(); // Aplicar nuevamente con la página ajustada
    }

    // Obtener subconjunto de datos para la página actual
    _sortedUnidadData = _unidadData.sublist(startIndex, endIndex);
  }

  // Cargar datos de unidades desde la API
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Cargar unidades
      final unidades = await _unidadService.getUnidadesCultivo();

      // Actualizar estado
      if (mounted) {
        setState(() {
          _unidadData = unidades;
          _totalItems = unidades.length;
          _currentPage = 1; // Resetear a la primera página
          _applyPagination(); // Aplicar paginación
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

  // Método para buscar unidades con filtros
  // Método de búsqueda actualizado para la pantalla Flutter
  Future<void> _searchUnidades() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Mapeo inverso para obtener valores de estatus
      final estatusMap = _estatusMap.map((k, v) => MapEntry(v, k.toString()));

      // Determinar el valor de estatus adecuado para el backend
      String? estatusValue;
      if (_selectedEstado != null && _selectedEstado != 'Todos') {
        estatusValue = estatusMap[_selectedEstado];
      }

      // Mostrar los parámetros de búsqueda para depuración
      print(
          'Buscando con: busqueda=${_searchController.text}, estatus=$estatusValue');

      // Enviar la búsqueda con los parámetros simplificados
      final unidades = await _unidadService.getUnidadesCultivo(
        busqueda:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        estatus: estatusValue,
      );

      if (mounted) {
        setState(() {
          _unidadData = unidades;
          _totalItems = unidades.length;
          _currentPage = 1; // Resetear a la primera página al buscar
          _applyPagination(); // Aplicar paginación
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

    // Asegurarse de notificar que ya no estamos en modo edición
    // pero de manera segura, programando la llamada para después del frame actual
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
      _selectedEstado = null;
      _currentUnidad = null;
      _isEditing = false;
      _isCreatingNew = false;
      _errorMessage = '';
    });

    // Notificar cambio de estado de edición
    _updateEditMode(false);
  }

  // Cargar unidad para editar
  Future<void> _editUnidad(UnidadCultivo unidad) async {
    if (!mounted) return;

    try {
      // Obtener detalles completos de la unidad desde la API
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
          _selectedEstado = _estatusMap[completeUnidad.estatus];
          _errorMessage = '';

          // Cambiar a la pestaña de registro
          _tabController.animateTo(1);
        });

        // Notificar que estamos en modo edición
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
      _isCreatingNew = true; // Marcar que estamos creando una nueva unidad
      _isEditing = false;
      _selectedEstado = 'Activo'; // Predeterminar como activo
    });

    // Cambiar a la pestaña de registro
    _tabController.animateTo(1);

    // Notificar que estamos en modo edición
    _updateEditMode(true);
  }

  // Guardar unidad (crear o actualizar)
  Future<void> _saveUnidad() async {
    if (!mounted) return;

    // Mostrar indicador de carga
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      // Validar formulario
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

      // Mapeo inverso para obtener valores de estatus
      final estatus = _estatusMap.map((k, v) => MapEntry(v, k));

      // Crear o actualizar unidad
      if (_isEditing && _currentUnidad != null) {
        // Actualizar unidad existente
        var updatedUnidad = _currentUnidad!.copyWith(
          codigo: _codigoController.text,
          cantero: _canteroController.text,
          id: int.tryParse(_idExternoController.text) ?? 0,
          estatus: estatus[_selectedEstado] ?? 1,
          modificadoPor: 1, // Usuario actual como modificador
        );

        // Enviar actualización a la API
        final success = await _unidadService.updateUnidadCultivo(updatedUnidad);

        if (success && mounted) {
          // Recargar la lista de unidades
          await _loadData();
          _showMessage('Unidad actualizada correctamente');

          // Limpiar formulario y volver a la lista
          _clearForm();
          _tabController.animateTo(0);
        }
      } else {
        // Crear nueva unidad
        final newUnidad = UnidadCultivo.nueva(
          codigo: _codigoController.text,
          cantero: _canteroController.text,
          id: int.tryParse(_idExternoController.text) ?? 0,
          estatus: estatus[_selectedEstado] ?? 1,
          creadoPor: 1, // Usuario actual como creador
        );

        // Enviar creación a la API
        final newSecuencia =
            await _unidadService.createUnidadCultivo(newUnidad);

        if (newSecuencia > 0 && mounted) {
          // Recargar la lista de unidades
          await _loadData();
          _showMessage('Unidad creada correctamente');

          // Limpiar formulario y volver a la lista
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

        // Finalmente, notificar que ya no estamos en modo edición
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
                // Llamar a la API para eliminar
                final success =
                    await _unidadService.deleteUnidadCultivo(unidad.secuencia);

                if (success && mounted) {
                  // Recargar datos
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

  // Widget para celda de encabezado redimensionable y ordenable
  Widget _buildResizableHeaderCell(int columnIndex) {
    final column = _columns[columnIndex];

    return GestureDetector(
      // Detectar clic para ordenar
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
            // Texto de la columna
            Text(
              column.title,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            // Indicador de ordenamiento
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
                      // Celda de encabezado
                      _buildResizableHeaderCell(index),

                      // Manejador de redimensionamiento (excepto para la última columna)
                      if (index < _columns.length - 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              if (mounted) {
                                setState(() {
                                  // Actualizar ancho con un mínimo para evitar columnas muy pequeñas
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
            // Detectar cuando el campo cambia para actualizar el modo de edición de manera segura
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
                // Notificar modo edición cuando se cambia un valor del dropdown de manera segura
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
            // Filtros de búsqueda
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Campo de búsqueda (Código/Cantero)
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Código / Cantero',
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
                              value: _selectedEstado ?? 'Todos',
                              isExpanded: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              items: ['Todos', 'Activo', 'Inactivo']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                if (mounted) {
                                  setState(() {
                                    _selectedEstado =
                                        value == 'Todos' ? null : value;
                                  });
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
                ],
              ),
            ),

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
                            // Encabezados de tabla redimensionables y ordenables
                            _buildSortableTableHeader(),

                            // Filas de datos o mensaje de no datos
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
                                                    // Botón de editar
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
                                                    // Botón de eliminar
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

                                                      // Celda especial para el estado (color diferente según estado)
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
                                                        // Celdas normales
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
                            // Cancelar y volver a consulta
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
                width: 200, // Ancho definido para las pestañas
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

              // Espacio flexible entre pestañas y botones
              Expanded(child: Container()),

              // Botones de acción
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Buscador como botón ejecutable
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
                      onPressed: _loadData, // Recargar datos
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
              // Tab de Consulta (Listado de Unidades)
              _buildConsultaTab(),

              // Tab de Registro (Formulario de Unidad)
              _buildRegistroTab(),
            ],
          ),
        ),
      ],
    );
  }
}
