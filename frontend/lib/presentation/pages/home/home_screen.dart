import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth/login_screen.dart';
import '../users/user_management_screen.dart';
import '../roles/role_management_screen.dart';
import '../varieties/variety_management_screen.dart';
import '../unidad_cultivo/unidad_cultivo_management_screen.dart';
import '../plaga_niveles/plaga_niveles_management_screen.dart';
import '../lots/lote_management_screen.dart';
import '../../monitoring/monitoreo_screen.dart';

class HomeScreen extends StatefulWidget {
  final String?
      nombreUsuario; // Nuevo parámetro para recibir el nombre del usuario
  final String? empresa; // Nuevo parámetro para recibir la empresa

  const HomeScreen(
      {super.key,
      this.nombreUsuario = 'User', // Valor por defecto
      this.empresa = 'Costa Farms LLC' // Valor por defecto
      });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isCollapsed = false;
  String activeMenu = 'Home';
  String? hoveredMenu;
  OverlayEntry? _overlayEntry;
  IconData _currentMenuIcon = Icons.home; // Nueva variable para el ícono actual

  // Widget actual que se muestra en el contenido principal
  late Widget _currentContent;
  String _currentTitle = 'Home';

  // Variable para controlar si hay un diálogo activo
  bool _isDialogOpen = false;

  // Variable para controlar si alguna pantalla está en modo edición
  bool _isInEditMode = false;

  // Función para actualizar el estado de edición
  void setEditMode(bool isEditing) {
    // Verificamos si es seguro llamar a setState
    if (mounted) {
      setState(() {
        _isInEditMode = isEditing;
      });
    } else {
      // Si no es seguro, solo actualizamos la variable
      _isInEditMode = isEditing;
    }
  }

  // Definir las opciones de los submenús
  final Map<String, List<String>> subMenuOptions = {
    'Home': [], // No tiene submenú
    'Administración': ['Usuarios', 'Roles', 'Permisos', 'Configuración'],
    'Generales': [
      'Unidades Cultivo',
      'Variedades',
      'Plagas y Niveles',
      'Lotes',
      'Monitoreo'
    ],
    'Compras e Inventario': [
      'Tipo proveedores',
      'Clientes / Proveedores',
      'Tipos movimientos inventario'
    ],
    'Cuentas por pagar': ['Pagos', 'Historial', 'Reportes'],
    'Caja general': ['Movimientos', 'Cierre diario'],
    'Facturación': ['Nueva factura', 'Consultar facturas'],
    'Cuentas por cobrar': ['Cobros', 'Estado de cuenta'],
    'Reportes': ['Ventas', 'Inventario', 'Finanzas'],
  };

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(BuildContext context, String menuTitle, GlobalKey key) {
    if (menuTitle == 'Home' || subMenuOptions[menuTitle]!.isEmpty) {
      return;
    }

    _hideOverlay();

    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    // Color del texto que coincide con el verde de la interfaz
    final Color menuTextColor = const Color(0xFF00A99D);
    // Color de iluminación al hacer hover
    final Color hoverColor = const Color(0xFF00A99D).withOpacity(0.1);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: isCollapsed ? 70 : 220,
        top: position.dy,
        child: MouseRegion(
          // Cuando el mouse sale del menú, lo ocultamos
          onExit: (_) {
            _hideOverlay();
          },
          child: Material(
            elevation: 4,
            // Bordes redondeados para las esquinas externas
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: ClipRRect(
              // Aseguramos que el contenido también tenga bordes redondeados
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: subMenuOptions[menuTitle]!
                      .map(
                        (option) => InkWell(
                          onTap: () {
                            _navigateToSubmenu(menuTitle, option);
                          },
                          // Cambiamos el comportamiento del hover para iluminar el texto
                          hoverColor: hoverColor,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14,
                                color: menuTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // Método general para confirmar cambio de página con control de diálogo único
  void _confirmPageNavigation(String targetTitle, Function navigationAction) {
    // Evitar múltiples diálogos
    if (_isDialogOpen) {
      return;
    }

    // Si ya estamos en la página de destino, no hacemos nada
    if (_currentTitle == targetTitle) {
      return;
    }

    // Solo mostrar diálogo de confirmación si estamos en modo edición
    if (_isInEditMode) {
      // Marcar que hay un diálogo abierto
      _isDialogOpen = true;

      // Crear una lista de acciones para el diálogo
      final List<Widget> actions = [
        ElevatedButton(
          autofocus: true, // Este botón tendrá el foco inicial
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
            // Marcar que ya no hay diálogo abierto
            _isDialogOpen = false;
          },
          child: const Text('No'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            // Ejecutar la acción de navegación
            navigationAction();
            // Marcar que ya no hay diálogo abierto
            _isDialogOpen = false;
          },
          child: const Text('Sí'),
        ),
      ];

      // Mostrar diálogo de confirmación
      showDialog(
        context: context,
        barrierDismissible: false, // Evitar cierre al tocar fuera del diálogo
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            // Prevenir cierre con botón atrás
            onWillPop: () async {
              _isDialogOpen = false;
              return true;
            },
            child: AlertDialog(
              title: Text('Cambiar a $targetTitle'),
              content: Text(
                  '¿Está seguro que desea salir de "$_currentTitle" sin guardar los cambios?'),
              actions: actions,
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              actionsAlignment: MainAxisAlignment.end,
            ),
          );
        },
      ).then((_) {
        // Garantizar que la bandera se reinicie si el diálogo se cierra de cualquier forma
        _isDialogOpen = false;
      });
    } else {
      // Si no estamos en modo edición, navegamos directamente
      navigationAction();
    }
  }

  void _navigateToSubmenu(String menuTitle, String submenuOption) {
    // Nombre completo del destino
    final destinationTitle =
        menuTitle == 'Administración' && submenuOption == 'Usuarios'
            ? 'Gestión de Usuarios'
            : '$menuTitle: $submenuOption';

    // Usar el método general de confirmación
    _confirmPageNavigation(destinationTitle, () {
      setState(() {
        activeMenu = menuTitle;
        hoveredMenu = null;
        // Actualizar el ícono actual del menú
        _currentMenuIcon = _getIconForMenu(menuTitle);

        if (menuTitle == 'Administración' && submenuOption == 'Usuarios') {
          _currentContent =
              UserManagementScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Gestión de Usuarios';
        } else if (menuTitle == 'Administración' && submenuOption == 'Roles') {
          _currentContent =
              RoleManagementScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Gestión de Roles';
        } else if (menuTitle == 'Generales' && submenuOption == 'Variedades') {
          _currentContent =
              VarietyManagementScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Gestión de Variedades';
        } else if (menuTitle == 'Generales' &&
            submenuOption == 'Unidades Cultivo') {
          _currentContent = UnidadCultivoScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Gestión de Unidades de Cultivo';
        } else if (menuTitle == 'Generales' &&
            submenuOption == 'Plagas y Niveles') {
          _currentContent = PlagaNivelesScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Gestión de Plagas y Niveles';
        } else if (menuTitle == 'Generales' && submenuOption == 'Lotes') {
          _currentContent =
              LoteManagementScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Gestión de Lotes';
        } else if (menuTitle == 'Generales' && submenuOption == 'Monitoreo') {
          _currentContent = MonitoreoScreen(onEditModeChanged: setEditMode);
          _currentTitle = 'Monitoreo';
        } else {
          _currentContent = Center(
            child: Text(
              'Contenido de $menuTitle: $submenuOption',
              style: const TextStyle(fontSize: 24),
            ),
          );
          _currentTitle = '$menuTitle: $submenuOption';
        }

        // Reset del modo de edición al cambiar de pantalla
        _isInEditMode = false;
      });

      _hideOverlay();
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
            child: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de Contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Nombre: Soporte Técnico'),
            SizedBox(height: 8),
            Text('Email: jmendoza@costanusery.com'),
            SizedBox(height: 8),
            Text('Teléfono: +1 (809) 722-4957'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentContent = _buildDashboardContent();
    _currentMenuIcon = Icons.home; // Iniciar con el ícono de home
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  Widget _buildDashboardContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCircularNavItem(
                    'Administración', 'Proyectos', Icons.admin_panel_settings),
                _buildCircularNavItem('Generales', 'Almacenes', Icons.settings),
                _buildCircularNavItem(
                    'Transacciones', 'SolicitudRequisición', Icons.swap_horiz),
                _buildCircularNavItem(
                    'Contabilidad', 'Asientos', Icons.account_balance),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey[200]),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100]!,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Monitoreo en el tiempo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700]!,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Infestación por tipo de plaga',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700]!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            _buildLineChartCard(),
                            const SizedBox(height: 16),
                            _buildPieChartCard(),
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildLineChartCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPieChartCard()),
                          ],
                        );
                      }
                    },
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1E73BB),
                  Color(0xFF00A99D),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isCollapsed ? Icons.menu : Icons.menu_open,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          isCollapsed = !isCollapsed;
                          _hideOverlay();
                        });
                      },
                    ),
                    // Logo
                    Container(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bar_chart_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Costa Analytics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          // Aquí actualizamos el icono para que muestre el actual
                          Icon(_currentMenuIcon,
                              size: 18, color: Color(0xFF1E73BB)),
                          const SizedBox(width: 8),
                          Text(
                            _currentTitle,
                            style: const TextStyle(
                              color: Color(0xFF1E73BB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Perfil de usuario
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person,
                                    color: Color(0xFF1E73BB)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Usar el nombre del usuario pasado como parámetro
                              Text(
                                widget.nombreUsuario ?? 'Usuario',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              // Usar la empresa pasada como parámetro
                              Text(
                                widget.empresa ?? 'Empresa',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          // Agregar nombre de usuario autenticado cerca del avatar
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Conectado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.help, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCollapsed ? 70 : 220,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1E73BB),
                        Color(0xFF00A99D),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          children: [
                            // Botón de Home separado y con implementación especial
                            InkWell(
                              onTap: () {
                                // Usar el método general de confirmación
                                _confirmPageNavigation('Home', () {
                                  setState(() {
                                    activeMenu = 'Home';
                                    hoveredMenu = null;
                                    _currentContent = _buildDashboardContent();
                                    _currentTitle = 'Home';
                                    _currentMenuIcon =
                                        Icons.home; // Actualizar ícono
                                    // Asegurarse de resetear el modo de edición al volver a Home
                                    _isInEditMode = false;
                                  });
                                  _hideOverlay();
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isCollapsed ? 16 : 12,
                                ),
                                decoration: BoxDecoration(
                                  color: activeMenu == 'Home'
                                      ? Colors.white.withOpacity(0.1)
                                      : (hoveredMenu == 'Home'
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.transparent),
                                  border: activeMenu == 'Home'
                                      ? const Border(
                                          left: BorderSide(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Icon(
                                      Icons.home,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    if (!isCollapsed) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Home',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Resto de los menús en ListView
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                // Excluimos Home del contador de elementos
                                itemCount: subMenuOptions.length - 1,
                                itemBuilder: (context, index) {
                                  // Ajustamos el índice para omitir "Home"
                                  final realIndex = index +
                                      1; // Saltamos el primer elemento (Home)
                                  final menuTitle =
                                      subMenuOptions.keys.elementAt(realIndex);
                                  final icon = _getIconForMenu(menuTitle);
                                  final isActive = activeMenu == menuTitle;
                                  final isHovered = hoveredMenu == menuTitle;
                                  final menuKey = GlobalKey();

                                  return InkWell(
                                    key: menuKey,
                                    onTap: () {
                                      // Usar el método general de confirmación
                                      _confirmPageNavigation(menuTitle, () {
                                        setState(() {
                                          activeMenu = menuTitle;
                                          _currentMenuIcon =
                                              icon; // Actualizar ícono actual
                                          _hideOverlay();
                                        });
                                      });
                                    },
                                    onHover: (isHovering) {
                                      if (isHovering) {
                                        setState(() {
                                          hoveredMenu = menuTitle;
                                        });
                                        _showOverlay(
                                            context, menuTitle, menuKey);
                                      } else {
                                        // Si el mouse sale del ítem, limpiamos el estado de hover
                                        if (hoveredMenu == menuTitle) {
                                          setState(() {
                                            hoveredMenu = null;
                                          });
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: isCollapsed ? 16 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.white.withOpacity(0.1)
                                            : (isHovered
                                                ? Colors.white.withOpacity(0.05)
                                                : Colors.transparent),
                                        border: isActive
                                            ? const Border(
                                                left: BorderSide(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Icon(
                                            icon,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          if (!isCollapsed) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                menuTitle,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                        ),
                        child: isCollapsed
                            ? Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: _handleLogout,
                                    child: const Icon(
                                      Icons.power_settings_new,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {},
                                    child: const Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showInfoDialog,
                                    child: const Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: _handleLogout,
                                    child: const Icon(
                                      Icons.power_settings_new,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {},
                                    child: const Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showInfoDialog,
                                    child: const Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[200]!,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _currentContent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForMenu(String menuTitle) {
    switch (menuTitle) {
      case 'Home':
        return Icons.home;
      case 'Administración':
        return Icons.admin_panel_settings;
      case 'Generales':
        return Icons.settings;
      case 'Compras e Inventario':
        return Icons.shopping_cart;
      case 'Cuentas por pagar':
        return Icons.account_balance_wallet;
      case 'Caja general':
        return Icons.point_of_sale;
      case 'Facturación':
        return Icons.receipt;
      case 'Cuentas por cobrar':
        return Icons.payments;
      case 'Reportes':
        return Icons.analytics;
      default:
        return Icons.circle;
    }
  }

  Widget _buildLineChartCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                horizontalInterval: 10,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: const Color(0xFFE0E0E0),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: const Color(0xFFE0E0E0),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    String text = '';
                    if (value.toInt() % 2 == 0) {
                      text = 'Día ${value.toInt() + 1}';
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(text,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600]!)),
                    );
                  },
                )),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text('${value.toInt()}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600]!)),
                    );
                  },
                )),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    const FlSpot(0, 30),
                    const FlSpot(1, 25),
                    const FlSpot(2, 35),
                    const FlSpot(3, 20),
                    const FlSpot(4, 30),
                    const FlSpot(5, 25),
                    const FlSpot(6, 35),
                    const FlSpot(7, 20),
                    const FlSpot(8, 40),
                    const FlSpot(9, 55),
                    const FlSpot(10, 50),
                    const FlSpot(11, 65),
                    const FlSpot(12, 70),
                    const FlSpot(13, 75),
                    const FlSpot(14, 80),
                  ],
                  isCurved: true,
                  color: const Color(0xFF1E73BB),
                  barWidth: 1,
                  isStrokeCapRound: true,
                  // Modificación: Línea con guiones
                  dashArray: [8, 4], // Patrón de guiones [longitud, espacio]
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      if (index == 10) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.white,
                          strokeWidth: 1,
                          strokeColor: const Color(0xFF1E73BB),
                        );
                      }
                      return FlDotCirclePainter(
                        radius: 0,
                        color: Colors.transparent,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF1E73BB).withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  color: const Color(0xFF6ACDFF),
                  value: 30,
                  title: '30%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: const Color(0xFF4F81BD),
                  value: 20,
                  title: '20%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: const Color(0xFF9656C0),
                  value: 15,
                  title: '15%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: const Color(0xFFCD6CEA),
                  value: 10,
                  title: '10%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: const Color(0xFFF2999B),
                  value: 25,
                  title: '25%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
              sectionsSpace: 0,
              centerSpaceRadius: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularNavItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E73BB),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500]!,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
