import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart'; // Importar intl para formateo de fechas
import '../../../models/role_model.dart';
import '../../../services/role_service.dart';
import '../../../core/config/flavor_config.dart'; // Importar ApiConfig

// Clase para manejar la información de las columnas
class ColumnInfo {
  final String title;
  double width;
  bool isSorted;
  bool sortAscending;
  final Function(Role) valueExtractor;

  ColumnInfo({
    required this.title,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    required this.valueExtractor,
  });
}

class RoleManagementScreen extends StatefulWidget {
  // Callback para notificar cambios en el modo de edición
  final Function(bool)? onEditModeChanged;

  const RoleManagementScreen({Key? key, this.onEditModeChanged})
      : super(key: key);

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Controladores para el formulario
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  // Rol actualmente en edición
  Role? _currentRole;
  bool _isEditing = false;
  bool _isCreatingNew = false;

  // Colores del tema
  final Color primaryColor = const Color(0xFF1E73BB);
  final Color accentColor = const Color(0xFF00A99D);
  final Color backgroundColor = Colors.white;
  final Color lightGrey = const Color(0xFFF5F5F5);

  // Variables para datos de la API
  List<Role> _roleData = [];
  // Lista para datos ordenados
  List<Role> _sortedRoleData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Servicio de roles usando la configuración centralizada
  final RoleService _roleService = RoleService();

  // Instancia de ApiConfig para monitorear cambios de configuración
  final ApiConfig _apiConfig = ApiConfig();

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
        valueExtractor: (role) => role.id.toString(),
      ),
      ColumnInfo(
        title: 'Descripción',
        width: 250,
        valueExtractor: (role) => role.descripcion,
      ),
      ColumnInfo(
        title: 'Fecha Creación',
        width: 180,
        valueExtractor: (role) {
          if (role.fechaCreacion != null && role.fechaCreacion!.isNotEmpty) {
            try {
              // Intentar parsear la fecha a DateTime
              final DateTime date = DateTime.parse(role.fechaCreacion!);
              // Formatear la fecha como dd/MM/yyyy HH:mm
              return DateFormat('dd/MM/yyyy HH:mm').format(date);
            } catch (e) {
              // Si hay error al parsear, mostrar fecha original
              return role.fechaCreacion ?? '-';
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

    // Escuchar cambios en la configuración de API
    _apiConfig.addListener(_onApiConfigChanged);

    // Cargar datos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Método para manejar cambios en la configuración de la API
  void _onApiConfigChanged() {
    if (mounted) {
      // Recargar datos cuando cambie la configuración
      _loadData();
    }
  }

  // Método para notificar el cambio en el modo de edición de manera segura
  void _updateEditMode(bool isEditing) {
    // Solo notificamos el cambio si el widget sigue montado y tenemos un callback
    if (widget.onEditModeChanged != null && mounted) {
      // Usamos un try-catch para evitar errores durante transiciones de navegación
      try {
        // Verificamos el estado del widget tree
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Verificación adicional - solo actuamos si el widget todavía está montado
          if (mounted) {
            widget.onEditModeChanged!(isEditing);
          }
        });
      } catch (e) {
        // Si ocurre un error, lo ignoramos silenciosamente para evitar bloquear la navegación
        // Esto evita que se intente actualizar el estado cuando el árbol esté bloqueado
        print('Ignorando actualización de modo de edición: $e');
      }
    }
  }

  // Método para ordenar los roles según la columna seleccionada
  void _sortRoles(int columnIndex) {
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
      _sortedRoleData.sort((a, b) {
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

  // Cargar datos de roles desde la API
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Verificar si la API está configurada
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente');
      }

      // Cargar roles
      final roles = await _roleService.getRoles();

      // Actualizar estado
      if (mounted) {
        setState(() {
          _roleData = roles;
          _sortedRoleData =
              List<Role>.from(roles); // Copiar lista para ordenamiento
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

        // Si el error es de configuración, mostrar mensaje específico
        if (e.toString().contains('API no está configurada')) {
          _showConfigurationError();
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

              // Aquí podrías navegar a la pantalla de configuración
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => ConfigurationScreen(
              //       apiConfig: _apiConfig,
              //       onConfigSuccess: () {
              //         Navigator.pop(context);
              //         _loadData();
              //       },
              //     ),
              //   ),
              // );
            },
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }

  // Método para buscar roles con filtros
  Future<void> _searchRoles() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Verificar si la API está configurada
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente');
      }

      final roles = await _roleService.getRoles(
        busqueda: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _roleData = roles;
          _sortedRoleData = List<Role>.from(roles); // Actualizar lista ordenada
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al buscar roles: $e';
        });
        _showMessage('Error al buscar roles: $e');

        // Si el error es de configuración, mostrar mensaje específico
        if (e.toString().contains('API no está configurada')) {
          _showConfigurationError();
        }
      }
    }
  }

  @override
  void dispose() {
    // Primero liberamos los controladores
    _tabController.dispose();
    _searchController.dispose();
    _idController.dispose();
    _descripcionController.dispose();

    // Eliminar listener de ApiConfig
    _apiConfig.removeListener(_onApiConfigChanged);

    // Ya no intentamos actualizar el estado directamente en dispose
    // El problema es que estamos tratando de modificar el HomeScreen cuando está bloqueado

    // Completamos el ciclo de dispose sin actualizar el estado
    super.dispose();

    // Nota: La notificación de cambio de modo de edición ya no es necesaria aquí
    // porque debería haberse manejado adecuadamente antes de la disposición del widget.
  }

  // Limpiar el formulario
  void _clearForm() {
    if (!mounted) return;

    // Limpia los controladores sin necesidad de setState si es posible
    _idController.clear();
    _descripcionController.clear();

    // Solo actualiza el estado si el widget sigue montado
    if (mounted) {
      try {
        setState(() {
          _currentRole = null;
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

  // Cargar rol para editar
  Future<void> _editRole(Role role) async {
    if (!mounted) return;

    try {
      // Verificar si la API está configurada
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente');
      }

      // Obtener detalles completos del rol desde la API
      final completeRole = await _roleService.getRoleById(role.id);

      if (mounted) {
        setState(() {
          _currentRole = completeRole;
          _isEditing = true;
          _isCreatingNew = false;
          _idController.text = completeRole.id.toString();
          _descripcionController.text = completeRole.descripcion;
          _errorMessage = '';

          // Cambiar a la pestaña de registro
          _tabController.animateTo(1);
        });

        // Notificar que estamos en modo edición
        _updateEditMode(true);
      }
    } catch (e) {
      _showMessage('Error al cargar el rol: $e');

      // Si el error es de configuración, mostrar mensaje específico
      if (e.toString().contains('API no está configurada')) {
        _showConfigurationError();
      }
    }
  }

  // Nueva rol
  void _nuevoRole() {
    _clearForm();
    if (!mounted) return;

    setState(() {
      _isCreatingNew = true; // Marcar que estamos creando un nuevo rol
      _isEditing = false;
    });

    // Cambiar a la pestaña de registro
    _tabController.animateTo(1);

    // Notificar que estamos en modo edición
    _updateEditMode(true);
  }

  // Guardar rol (crear o actualizar)
  Future<void> _saveRole() async {
    if (!mounted) return;

    // Mostrar indicador de carga
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      // Verificar si la API está configurada
      if (!_apiConfig.isConfigured) {
        throw Exception('La API no está configurada correctamente');
      }

      // Validar formulario
      if (_descripcionController.text.isEmpty) {
        _showMessage('Por favor complete la descripción del rol');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      // Crear o actualizar rol
      if (_isEditing && _currentRole != null) {
        // Actualizar rol existente
        var updatedRole = _currentRole!.copyWith(
          descripcion: _descripcionController.text,
          modificadoPor: 1, // Usuario actual como modificador
        );

        // Enviar actualización a la API
        final success = await _roleService.updateRole(updatedRole);

        if (success && mounted) {
          // Recargar la lista de roles
          await _loadData();
          _showMessage('Rol actualizado correctamente');

          // Limpiar formulario y volver a la lista
          _clearForm();
          _tabController.animateTo(0);
        }
      } else {
        // Crear nuevo rol
        final newRole = Role.newRole(
          descripcion: _descripcionController.text,
        );

        // Enviar creación a la API
        final newId = await _roleService.createRole(newRole);

        if (newId > 0 && mounted) {
          // Recargar la lista de roles
          await _loadData();
          _showMessage('Rol creado correctamente');

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

      // Si el error es de configuración, mostrar mensaje específico
      if (e.toString().contains('API no está configurada')) {
        _showConfigurationError();
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

  // Eliminar rol
  void _deleteRole(Role role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Está seguro que desea eliminar el rol ${role.descripcion}?'),
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
                // Verificar si la API está configurada
                if (!_apiConfig.isConfigured) {
                  throw Exception('La API no está configurada correctamente');
                }

                // Llamar a la API para eliminar
                final success = await _roleService.deleteRole(role.id);

                if (success && mounted) {
                  // Recargar datos
                  await _loadData();
                  _showMessage('Rol eliminado correctamente');
                } else if (mounted) {
                  _showMessage('No se pudo eliminar el rol');
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('Error al eliminar rol: $e');

                  // Si el error es de configuración, mostrar mensaje específico
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
      // Detectar clic para ordenar
      onTap: () => _sortRoles(columnIndex),
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

  // Construir la vista de consulta con la tabla de roles
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
            // Mostrar información de la URL configurada
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: _apiConfig.isConfigured
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Text(
                _apiConfig.isConfigured
                    ? 'API configurada: ${_apiConfig.apiUrl}'
                    : 'API no configurada. Configure la URL del servidor.',
                style: TextStyle(
                  fontSize: 12,
                  color: _apiConfig.isConfigured
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Filtros de búsqueda
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Campo de búsqueda
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buscar por descripción',
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
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

            // Tabla de roles
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
                            _sortedRoleData.isEmpty
                                ? Expanded(
                                    child: Center(
                                      child: Text(
                                        'No hay roles para mostrar',
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
                                        children: _sortedRoleData.map((role) {
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
                                                          _editRole(role),
                                                      child: Container(
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
                                                          _deleteRole(role),
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
                                                      final value = column
                                                          .valueExtractor(role);
                                                      return _buildDataCell(
                                                          value, column.width);
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
            // Indicador de número de registros
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Center(
                child: Text(
                  'Mostrando ${_sortedRoleData.length} roles',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir la vista de registro con el formulario de rol
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
                      _isEditing ? 'Editar Rol' : 'Nuevo Rol',
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
                            'Información del Rol',
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
                                  'ID del rol',
                                  controller: _idController,
                                  enabled: false,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),

                          // Campo Descripción
                          _buildFormField(
                            'Descripción',
                            'Ingrese descripción del rol',
                            controller: _descripcionController,
                            required: true,
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
                          onPressed: _isSubmitting ? null : _saveRole,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 255, 255, 255),
                            foregroundColor:
                                const Color.fromARGB(174, 116, 113, 113),
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
                    // Buscador como botón ejecutable
                    ElevatedButton.icon(
                      onPressed: _searchRoles,
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
                      onPressed: _nuevoRole,
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

                    // Botón para mostrar la configuración actual de la API
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Configuración API'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('API URL: ${_apiConfig.apiUrl}'),
                                Text('Base URL: ${_apiConfig.baseUrl}'),
                                Text(
                                    'Configurada: ${_apiConfig.isConfigured ? 'Sí' : 'No'}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Aquí podrías navegar a la pantalla de configuración
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) => ConfigurationScreen(
                                  //       apiConfig: _apiConfig,
                                  //       onConfigSuccess: () {
                                  //         Navigator.pop(context);
                                  //         _loadData();
                                  //       },
                                  //     ),
                                  //   ),
                                  // );
                                },
                                child: const Text('Configurar'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      tooltip: 'Ver configuración',
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
              // Tab de Consulta (Listado de Roles)
              _buildConsultaTab(),

              // Tab de Registro (Formulario de Rol)
              _buildRegistroTab(),
            ],
          ),
        ),
      ],
    );
  }
}
