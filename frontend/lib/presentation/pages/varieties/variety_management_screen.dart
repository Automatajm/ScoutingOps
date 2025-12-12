import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart'; // Importar intl para formateo de fechas
import '../../../models/variety_model.dart';
import '../../../services/variety_service.dart';
import '../../widgets/pagination_widget.dart'; // Importar widget de paginación

// Clase para manejar la información de las columnas
class ColumnInfo {
  final String title;
  double width;
  bool isSorted;
  bool sortAscending;
  final Function(Variety) valueExtractor;

  ColumnInfo({
    required this.title,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    required this.valueExtractor,
  });
}

class VarietyManagementScreen extends StatefulWidget {
  // Callback para notificar cambios en el modo de edición
  final Function(bool)? onEditModeChanged;

  const VarietyManagementScreen({Key? key, this.onEditModeChanged})
      : super(key: key);

  @override
  State<VarietyManagementScreen> createState() =>
      _VarietyManagementScreenState();
}

class _VarietyManagementScreenState extends State<VarietyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Controladores para el formulario
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _responsableController = TextEditingController();

  // Variables para los valores seleccionados en dropdowns
  String? _selectedEstado;

  // Variedad actualmente en edición
  Variety? _currentVariety;
  bool _isEditing = false;
  bool _isCreatingNew = false;

  // Colores del tema
  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color backgroundColor = Colors.white;
  final Color lightGrey = const Color(0xFFF5F5F5);

  // Variables para datos de la API
  List<Variety> _varietyData = [];
  // Lista para datos ordenados
  List<Variety> _sortedVarietyData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Variables para paginación
  int _currentPage = 1;
  int _itemsPerPage = 20; // Puedes ajustar este valor según tus necesidades
  int _totalItems = 0;

  // Servicio de variedades con ApiConfig centralizada
  final VarietyService _varietyService = VarietyService();

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
        valueExtractor: (variety) => variety.id.toString(),
      ),
      ColumnInfo(
        title: 'Código',
        width: 150,
        valueExtractor: (variety) => variety.codigo,
      ),
      ColumnInfo(
        title: 'Descripción',
        width: 250,
        valueExtractor: (variety) => variety.descripcion,
      ),
      ColumnInfo(
        title: 'Responsable',
        width: 200,
        valueExtractor: (variety) => variety.responsable ?? '-',
      ),
      ColumnInfo(
        title: 'Estado',
        width: 120,
        valueExtractor: (variety) => _estatusMap[variety.estatus] ?? '-',
      ),
      ColumnInfo(
        title: 'Fecha Creación',
        width: 180,
        valueExtractor: (variety) {
          if (variety.fechaCreacion != null &&
              variety.fechaCreacion!.isNotEmpty) {
            try {
              // Intentar parsear la fecha a DateTime
              final DateTime date = DateTime.parse(variety.fechaCreacion!);
              // Formatear la fecha como dd/MM/yyyy HH:mm
              return DateFormat('dd/MM/yyyy HH:mm').format(date);
            } catch (e) {
              // Si hay error al parsear, mostrar fecha original
              return variety.fechaCreacion ?? '-';
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
    // Solo notificamos el cambio si el widget sigue montado y tenemos un callback
    if (widget.onEditModeChanged != null && mounted) {
      // Verificamos si no estamos en una fase crítica del ciclo de vida
      if (WidgetsBinding.instance.schedulerPhase !=
          SchedulerPhase.persistentCallbacks) {
        // Usamos un try-catch para evitar errores durante transiciones de navegación
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Verificación adicional - solo actuamos si el widget todavía está montado
            if (mounted) {
              widget.onEditModeChanged!(isEditing);
            }
          });
        } catch (e) {
          // Si ocurre un error, lo ignoramos silenciosamente para evitar bloquear la navegación
          print('Ignorando actualización de modo de edición: $e');
        }
      }
    }
  }

  // Método para ordenar las variedades según la columna seleccionada
  void _sortVarieties(int columnIndex) {
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
      _sortedVarietyData.sort((a, b) {
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
    if (_varietyData.isEmpty) {
      _sortedVarietyData = [];
      return;
    }

    // Calcular índices de inicio y fin para la página actual
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    // Asegurarse de que el índice final no exceda el total de elementos
    if (endIndex > _varietyData.length) {
      endIndex = _varietyData.length;
    }

    // Si el índice de inicio es mayor que el tamaño de la lista, ajustar a la última página
    if (startIndex >= _varietyData.length) {
      _currentPage = (_varietyData.length / _itemsPerPage).ceil();
      return _applyPagination(); // Aplicar nuevamente con la página ajustada
    }

    // Obtener subconjunto de datos para la página actual
    _sortedVarietyData = _varietyData.sublist(startIndex, endIndex);
  }

  // Cargar datos de variedades desde la API
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final varieties = await _varietyService.getVarieties();

      // Actualizar estado
      if (mounted) {
        setState(() {
          _varietyData = varieties;
          _totalItems = varieties.length;
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

  // Método para buscar variedades con filtros
  Future<void> _searchVarieties() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String? estatusParam;
      if (_selectedEstado != null && _selectedEstado != 'Todos') {
        estatusParam = _selectedEstado == 'Activo' ? '1' : '0';
      }

      final varieties = await _varietyService.getVarieties(
        busqueda: _searchController.text,
        estatus: estatusParam,
      );

      if (mounted) {
        setState(() {
          _varietyData = varieties;
          _totalItems = varieties.length;
          _currentPage = 1; // Resetear a la primera página al buscar
          _applyPagination(); // Aplicar paginación
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al buscar variedades: $e';
        });
        _showMessage('Error al buscar variedades: $e');
      }
    }
  }

  @override
  void dispose() {
    // Liberar recursos
    _tabController.dispose();
    _searchController.dispose();
    _idController.dispose();
    _codigoController.dispose();
    _descripcionController.dispose();
    _responsableController.dispose();

    // Completar el ciclo dispose sin actualizar estados
    super.dispose();

    // Ya NO llamamos a _updateEditMode() ni a widget.onEditModeChanged
    // desde aquí, ya que está causando el error.
  }

  // Limpiar el formulario
  void _clearForm() {
    if (!mounted) return;

    // Limpia los controladores sin necesidad de setState si es posible
    _idController.clear();
    _codigoController.clear();
    _descripcionController.clear();
    _responsableController.clear();

    // Solo actualiza el estado si el widget sigue montado
    if (mounted) {
      try {
        setState(() {
          _selectedEstado = null;
          _currentVariety = null;
          _isEditing = false;
          _isCreatingNew = false;
          _errorMessage = '';
        });

        // Solo notificamos el cambio si no estamos en medio de una disposición
        if (mounted &&
            WidgetsBinding.instance.schedulerPhase !=
                SchedulerPhase.persistentCallbacks) {
          _updateEditMode(false);
        }
      } catch (e) {
        // Si ocurre un error al actualizar el estado, simplemente continuamos
        print('Error al limpiar formulario: $e');
      }
    }
  }

  // Cargar variedad para editar
  Future<void> _editVariety(Variety variety) async {
    if (!mounted) return;

    try {
      // Obtener detalles completos de la variedad desde la API
      final completeVariety = await _varietyService.getVarietyById(variety.id);

      if (mounted) {
        setState(() {
          _currentVariety = completeVariety;
          _isEditing = true;
          _isCreatingNew = false;
          _idController.text = completeVariety.id.toString();
          _codigoController.text = completeVariety.codigo;
          _descripcionController.text = completeVariety.descripcion;
          _responsableController.text = completeVariety.responsable ?? '';
          _selectedEstado = _estatusMap[completeVariety.estatus];
          _errorMessage = '';

          // Cambiar a la pestaña de registro
          _tabController.animateTo(1);
        });

        // Notificar que estamos en modo edición
        _updateEditMode(true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error al cargar la variedad: $e');
      }
    }
  }

  // Nueva variedad
  void _nuevaVariedad() {
    _clearForm();
    if (!mounted) return;

    setState(() {
      _isCreatingNew = true; // Marcar que estamos creando una nueva variedad
      _isEditing = false;
      _selectedEstado = 'Activo'; // Predeterminar como activo
    });

    // Cambiar a la pestaña de registro
    _tabController.animateTo(1);

    // Notificar que estamos en modo edición
    _updateEditMode(true);
  }

  // Guardar variedad (crear o actualizar)
  Future<void> _saveVariety() async {
    if (!mounted) return;

    // Mostrar indicador de carga
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      // Validar formulario
      if (_codigoController.text.isEmpty ||
          _descripcionController.text.isEmpty ||
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

      // Crear o actualizar variedad
      if (_isEditing && _currentVariety != null) {
        // Actualizar variedad existente
        var updatedVariety = _currentVariety!.copyWith(
          codigo: _codigoController.text,
          descripcion: _descripcionController.text,
          responsable: _responsableController.text.isEmpty
              ? null
              : _responsableController.text,
          estatus: estatus[_selectedEstado] ?? 1,
          modificadoPor: 1, // Usuario actual como modificador
        );

        // Enviar actualización a la API
        final success = await _varietyService.updateVariety(updatedVariety);

        if (success && mounted) {
          // Recargar la lista de variedades
          await _loadData();
          _showMessage('Variedad actualizada correctamente');

          // Limpiar formulario y volver a la lista
          _clearForm();
          _tabController.animateTo(0);
        }
      } else {
        // Crear nueva variedad
        final newVariety = Variety.newVariety(
          codigo: _codigoController.text,
          descripcion: _descripcionController.text,
          responsable: _responsableController.text.isEmpty
              ? null
              : _responsableController.text,
          creadoPor: 1, // Usuario actual como creador
        );

        // Enviar creación a la API
        final newId = await _varietyService.createVariety(newVariety);

        if (newId > 0 && mounted) {
          // Recargar la lista de variedades
          await _loadData();
          _showMessage('Variedad creada correctamente');

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

  // Eliminar variedad
  void _deleteVariety(Variety variety) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Está seguro que desea eliminar la variedad ${variety.descripcion}?'),
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
                final success = await _varietyService.deleteVariety(variety.id);

                if (success && mounted) {
                  // Recargar datos
                  await _loadData();
                  _showMessage('Variedad eliminada correctamente');
                } else if (mounted) {
                  _showMessage('No se pudo eliminar la variedad');
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('Error al eliminar variedad: $e');
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
      onTap: () => _sortVarieties(columnIndex),
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

  // Construir la vista de consulta con la tabla de variedades
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
                  // Campo de búsqueda
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buscar por código o descripción',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedEstado,
                              isExpanded: true,
                              hint: Text(
                                'Todos',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              items: ['Todos', 'Activo', 'Inactivo']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (value) {
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

                  const SizedBox(width: 16),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // Tabla de variedades
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
                            _sortedVarietyData.isEmpty
                                ? Expanded(
                                    child: Center(
                                      child: Text(
                                        'No hay variedades para mostrar',
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
                                            _sortedVarietyData.map((variety) {
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
                                                          _editVariety(variety),
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
                                                          _deleteVariety(
                                                              variety),
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
                                                              variety);

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
              itemsLabel: 'variedades',
            ),
          ],
        ),
      ),
    );
  }

  // Construir la vista de registro con el formulario de variedad
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
                      _isEditing ? 'Editar Variedad' : 'Nueva Variedad',
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
                            'Información de la Variedad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const Divider(height: 24),

                          // Campo ID (solo lectura)
                          if (_isEditing)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormField(
                                  'ID',
                                  'ID de la variedad',
                                  controller: _idController,
                                  enabled: false,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),

                          // Primera fila: Código y Descripción
                          Row(
                            children: [
                              // Campo Código
                              Expanded(
                                child: _buildFormField(
                                  'Código',
                                  'Ingrese código de la variedad',
                                  controller: _codigoController,
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Campo Descripción
                              Expanded(
                                flex: 2,
                                child: _buildFormField(
                                  'Descripción',
                                  'Ingrese descripción de la variedad',
                                  controller: _descripcionController,
                                  required: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Segunda fila: Responsable y Estado
                          Row(
                            children: [
                              // Campo Responsable
                              Expanded(
                                flex: 2,
                                child: _buildFormField(
                                  'Responsable',
                                  'Ingrese responsable de la variedad',
                                  controller: _responsableController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Campo Estado
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
                          onPressed: _isSubmitting ? null : _saveVariety,
                          style: ElevatedButton.styleFrom(
                            foregroundColor:
                                const Color.fromARGB(173, 116, 115, 115),
                            backgroundColor:
                                const Color.fromARGB(255, 255, 255, 255),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            disabledBackgroundColor: Colors.grey.shade400,
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
                    // Botón de buscar
                    ElevatedButton.icon(
                      onPressed: _searchVarieties,
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
                      onPressed: _nuevaVariedad,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Nueva'),
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
              // Tab de Consulta (Listado de Variedades)
              _buildConsultaTab(),

              // Tab de Registro (Formulario de Variedad)
              _buildRegistroTab(),
            ],
          ),
        ),
      ],
    );
  }
}
