import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
import '../../screens/monitoreo/widgets/cantero_wizard_bar.dart';
import '../../core/routes/routes_manager.dart';
import '../../services/offline_database_service.dart';
import 'maintenance_helper.dart';

// MIXINS REFACTORIZADOS
import 'mixins/cantero_wizard_mixin.dart';
import 'mixins/monitoreo_navigation_mixin.dart';
import 'mixins/monitoreo_data_loader_mixin.dart';
import 'mixins/monitoreo_sync_mixin.dart';

class MonitoreoScreen extends StatefulWidget {
  final Function(bool)? onEditModeChanged;
  const MonitoreoScreen({Key? key, this.onEditModeChanged}) : super(key: key);
  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen>
    with 
        SingleTickerProviderStateMixin,
        CanteroWizardMixin,
        MonitoreoNavigationMixin,
        MonitoreoDataLoaderMixin,
        MonitoreoSyncMixin {
  late TabController _tabController;

  // Controladores para filtros
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fechaInicioController = TextEditingController();
  final TextEditingController _fechaFinController = TextEditingController();

  // Controladores para formulario
  final TextEditingController _codigoLoteController = TextEditingController();
  final TextEditingController _casaController = TextEditingController();
  final TextEditingController _canteroController = TextEditingController();
  final TextEditingController _responsableController = TextEditingController();
  final TextEditingController _comentariosController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _cantidadBotadaController = TextEditingController();
  final TextEditingController _muestra1Controller = TextEditingController();
  final TextEditingController _muestra2Controller = TextEditingController();
  final TextEditingController _muestra3Controller = TextEditingController();
  final TextEditingController _canterosRangeController = TextEditingController();

  // Datos dropdowns
  Map<String, dynamic> casasData = {'data': []};
  Map<String, String> _variedadesIdMap = {};

  // Variables filtrado
  String? _selectedEstado;
  String? _selectedPlaga;
  String? _selectedCasaFiltro;
  String? _selectedCanteroFiltro;
  String? _selectedVariedadFiltro;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Variables formulario
  String? _selectedVariedad;
  List<String> _variedades = ['Variedad genérica'];
  Map<String, String> _responsablesPorVariedad = {};
  String? _selectedCasa;
  List<String> _casas = ['Casa genérica'];
  List<String> _plagas = [];

  String? _selectedNivelMuestra1;
  String? _selectedNivelMuestra2;
  String? _selectedNivelMuestra3;

  String? _loteCanterosOriginal;
  String? _loteContenedorOriginal;

  int? _limiteNivel1;
  int? _limiteNivel2;
  int? _limiteNivel3;

  // Control estado
  bool _isManualEntry = false;
  Monitoreo? _currentMonitoreo;
  bool _isEditing = false;
  bool _isCreatingNew = false;
  bool _isPartialSave = false;
  bool _isFilteredByUser = false;
  bool _isInModeFiltrado = false;

  // Guardado parcial
  bool _isInPartialSaveMode = false;
  bool _isEditingExistingPartial = false;
  Set<String> _plagasRegistradasParcial = {};
  Set<String> _variedadesUsadasParcial = {};

  // Datos API
  List<Monitoreo> _monitoreoData = [];
  List<Monitoreo> _filteredMonitoreoData = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  // Paginación
  int _currentPage = 1;
  int _itemsPerPage = 25;
  int _totalItems = 0;
  int _totalPages = 1;

  // Ordenamiento
  String? _sortColumn;
  bool _sortAscending = false;
  Map<String, double> _columnWidths = {};
  List<Map<String, dynamic>> _columns = [];

  // Sincronización - NOTA: Variables movidas a MonitoreoSyncMixin
  IntranetService? _cachedIntranetService;
  bool _lastSaveSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Listener para actualizar UI cuando cambia de tab (para tabs en header)
    // Y para interceptar cambios cuando el wizard está activo
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Usuario está intentando cambiar de tab
        if (_tabController.index == 0 && isWizardActive) {
          // Intentando ir a Consulta con wizard activo
          _showCloseWizardDialog();
        }
      } else if (mounted) {
        setState(() {});  // Refrescar para cambiar color activo del tab
      }
    });
    
    _sortColumn = 'ID';
    _sortAscending = false;

    _columns = [
      {
        'title': 'ID',
        'width': 80.0,
        'valueExtractor': (m) => m.pmmo_secuencia.toString(),
        'isNumeric': true
      },
      {
        'title': 'Lote',
        'width': 120.0,
        'valueExtractor': (m) => m.pmlt_codigo ?? '-'
      },
      {
        'title': 'Fecha',
        'width': 120.0,
        'valueExtractor': (m) => m.pmmo_fecha != null
            ? DateFormat('dd/MM/yyyy').format(m.pmmo_fecha!)
            : '-'
      },
      {
        'title': 'Casa',
        'width': 100.0,
        'valueExtractor': (m) => m.pmmo_casa ?? '-'
      },
      {
        'title': 'Cantero',
        'width': 100.0,
        'valueExtractor': (m) => m.pmmo_cantero ?? '-'
      },
      {
        'title': 'Variedad',
        'width': 150.0,
        'valueExtractor': (m) => m.pmmo_variedad ?? m.pmva_descripcion ?? '-'
      },
      {
        'title': 'Plaga',
        'width': 150.0,
        'valueExtractor': (m) => m.pmni_nombrecomun ?? '-'
      },
      {
        'title': 'Cantidad',
        'width': 100.0,
        'valueExtractor': (m) => m.pmmo_cantidad?.toString() ?? '-',
        'isNumeric': true
      },
      {
        'title': 'Nivel M1',
        'width': 80.0,
        'valueExtractor': (m) => m.pmmo_nivmuestram1?.toString() ?? '-',
        'isNumeric': true
      },
      {
        'title': 'Nivel M2',
        'width': 80.0,
        'valueExtractor': (m) => m.pmmo_nivmuestram2?.toString() ?? '-',
        'isNumeric': true
      },
      {
        'title': 'Nivel M3',
        'width': 80.0,
        'valueExtractor': (m) => m.pmmo_nivmuestram3?.toString() ?? '-',
        'isNumeric': true
      },
      {
        'title': 'Estado',
        'width': 100.0,
        'valueExtractor': (m) {
          if ((m.pmmo_secuencia != null && m.pmmo_secuencia! < 0) ||
              (m.isOfflineCreated == true)) return 'Pendiente';
          return m.pmmo_estatus == 1 ? 'Activo' : 'Inactivo';
        }
      },
    ];

    _tabController.addListener(() {
      if (mounted && _tabController.index == 0) {
        if (isWizardActive || isWizardRangeLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tabController.animateTo(1);
              _showMessage('Debe finalizar el wizard antes de cambiar de pestaña');
            }
          });
          return;
        }
        _clearForm();
      }
      if (mounted && _tabController.index == 1) {
        if (!_isEditing) {
          setState(() {
            _isEditing = true;
            _isCreatingNew = true;
            _cantidadController.text = '0';
          });
          _updateEditMode(true);
        }
      }
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        setState(() {
          _isFilteredByUser = authService.mustFilterByUser;
          _isInModeFiltrado = authService.isMonitoreador;
        });
        if (authService.isAdmin) {
          setState(() {
            _columns.add({
              'title': 'Creado por',
              'width': 120.0,
              'valueExtractor': (m) => m.pmmo_creadopor?.toString() ?? '-'
            });
          });
        }
        _cachedIntranetService = Provider.of<IntranetService>(context, listen: false);
        
        // Configurar listeners desde mixins
        setupConnectivityListener();
        updatePendingChangesCount();
        
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
    _cachedIntranetService = Provider.of<IntranetService>(context, listen: false);
  }

  @override
  void dispose() {
    cleanupConnectivityListener(); // Del SyncMixin
    
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
    _canterosRangeController.dispose();
    super.dispose();
  }

  // ===== MANEJO DE DUPLICADOS =====
  
  /// Método para crear un nuevo monitoreo con validaciones
  void _nuevoMonitoreo() {
    if (isWizardActive || isWizardRangeLocked) {
      _showMessage('Debe finalizar el wizard antes de crear un nuevo monitoreo');
      return;
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      FriendlyErrorDialog.show(
        context,
        title: 'Sesión expirada',
        message: 'Por favor inicie sesión.',
        actionText: 'Login',
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
        message: 'Inicie sesión nuevamente.',
        actionText: 'Login',
        onAction: () {
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
    
    _clearForm();
    if (!mounted) return;
    
    setState(() {
      _isCreatingNew = true;
      _isEditing = true;
      _isManualEntry = false;
      _cantidadController.text = '0';
      _loteContenedorOriginal = 'CONT_GENERAL';
    });
    
    _tabController.animateTo(1);
    _updateEditMode(true);
  }

  /// Escanear código de barras con lógica dual del baseline
  /// - Si hay texto en el campo → Buscar directamente
  /// - Si está vacío → Abrir escáner OCR
  Future<void> _scanBarcode() async {
    debugPrint('📷 _scanBarcode iniciado');
    
    // ✅ LÓGICA DUAL: Si ya hay código, buscar directamente
    if (_codigoLoteController.text.isNotEmpty) {
      final String existingCode = _codigoLoteController.text.trim();
      debugPrint('🔍 Código existente detectado: $existingCode - Buscando directamente...');
      
      if (mounted) {
        setState(() {
          _isManualEntry = false;
          _errorMessage = '';
          _isLoading = true;
        });
        
        // Buscar información del lote directamente
        await _loadLoteData(existingCode);
      }
      return;
    }

    // ✅ SI NO HAY CÓDIGO: Abrir escáner OCR (HTML/JavaScript)
    debugPrint('📸 Campo vacío - Abriendo escáner OCR...');
    final String? scannedCode = await BarcodeScanner.scanBarcode(context);
    
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      debugPrint('✅ Código escaneado: $scannedCode');
      
      setState(() {
        _codigoLoteController.text = scannedCode;
        _isManualEntry = false;
        _errorMessage = '';
        _isLoading = true;
      });
      
      // Buscar información del lote escaneado
      await _loadLoteData(scannedCode);
    } else {
      debugPrint('⚠️ Escaneo cancelado o sin resultado');
    }
  }

  /// Cargar información completa del lote desde múltiples fuentes
  /// 1. SQLite lote_info
  /// 2. SQLite catálogo lotes (fallback)
  /// 3. API (si está online)
  /// 4. Enriquecer variedad desde catálogo
  /// 5. Actualizar dropdowns dinámicamente
  Future<void> _loadLoteData(String codigoLote) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      dynamic loteInfo;

      // ===== 1. BUSCAR EN LOTE_INFO (SQLite) =====
      loteInfo = await offlineDbService.getLoteInfo(codigoLote);
      if (loteInfo != null) {
        final estatus = loteInfo['estatus'] ?? loteInfo['pmlt_estatus'] ?? 1;
        if (estatus != 1) {
          debugPrint('⚠️ Lote $codigoLote encontrado en lote_info pero inactivo');
          loteInfo = null;
        } else {
          debugPrint('📦 Lote $codigoLote encontrado en lote_info (SQLite)');
        }
      }

      // ===== 2. BUSCAR EN CATÁLOGO GENERAL SI NO ESTÁ EN LOTE_INFO =====
      if (loteInfo == null) {
        debugPrint('🔍 Buscando lote $codigoLote en catálogo general...');
        loteInfo = await _buscarLoteEnCatalogo(codigoLote, offlineDbService);
        if (loteInfo != null) {
          debugPrint('📦 Lote $codigoLote encontrado en catálogo lotes (SQLite)');
        }
      }

      // ===== 3. BUSCAR EN API SI ESTÁ ONLINE =====
      if (loteInfo == null && intranetService.isConnected.value) {
        debugPrint('🌐 Consultando lote $codigoLote desde API...');
        try {
          loteInfo = await monitoreoService.getLoteInfo(codigoLote);
          if (loteInfo != null) {
            final estatus = loteInfo['estatus'] ?? loteInfo['pmlt_estatus'] ?? 1;
            if (estatus != 1) {
              _showMessage('Lote $codigoLote no activo.');
              loteInfo = null;
            } else {
              await offlineDbService.saveLoteInfo(
                  codigoLote, Map<String, dynamic>.from(loteInfo));
              debugPrint('💾 Lote $codigoLote guardado en lote_info para offline');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error consultando API: $e');
        }
      }

      if (loteInfo == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        _showMessage('❌ Lote $codigoLote no encontrado');
        return;
      }

      // ===== 4. ENRIQUECER VARIEDAD DESDE CATÁLOGO =====
      final idVariedad = loteInfo['pmlt_idvariedad'] ?? loteInfo['pmva_id'];
      final tieneVariedad = (loteInfo['pmlt_variedad'] != null && 
              loteInfo['pmlt_variedad'].toString().isNotEmpty) ||
          (loteInfo['pmva_descripcion'] != null && 
              loteInfo['pmva_descripcion'].toString().isNotEmpty);

      if (idVariedad != null && !tieneVariedad) {
        debugPrint('🔍 Enriqueciendo variedad desde catálogo (ID: $idVariedad)');
        final variedadesData = await offlineDbService.getVariedades();
        if (variedadesData != null) {
          try {
            final variedad = variedadesData.firstWhere((v) {
              if (v is! Map) return false;
              final idMatch = (v['id']?.toString() == idVariedad.toString()) ||
                  (v['pmva_id']?.toString() == idVariedad.toString());
              if (!idMatch) return false;
              final estatus = v['estatus'] ?? v['pmva_estatus'] ?? 1;
              return estatus == 1;
            });
            
            if (variedad != null) {
              loteInfo['pmlt_variedad'] = 
                  variedad['descripcion'] ?? variedad['pmva_descripcion'];
              loteInfo['pmva_responsable'] = 
                  variedad['responsable'] ?? variedad['pmva_responsable'];
              loteInfo['pmlt_idvariedad'] = variedad['codigo']?.toString() ??
                  variedad['pmva_codigo']?.toString() ??
                  loteInfo['pmlt_idvariedad'];

              debugPrint('📦 Variedad enriquecida: ${loteInfo['pmlt_variedad']} → Código: ${loteInfo['pmlt_idvariedad']}');
            }
          } catch (e) {
            debugPrint('⚠️ No se encontró variedad con ID $idVariedad en catálogo');
          }
        }
      }

      // ===== 5. ACTUALIZAR DROPDOWNS DINÁMICAMENTE =====
      String? variedadDescripcion = loteInfo['pmlt_variedad']?.toString() ??
          loteInfo['pmva_descripcion']?.toString();
      String? casaLote = loteInfo['pmlt_casa']?.toString();
      String? idVariedadStr = loteInfo['pmlt_idvariedad']?.toString();
      String? responsableLote = loteInfo['pmva_responsable']?.toString() ??
          loteInfo['pmlt_grower']?.toString();

      List<String> variedadesActualizadas = List.from(_variedades);
      List<String> casasActualizadas = List.from(_casas);
      Map<String, String> variedadesIdMapActualizado = Map.from(_variedadesIdMap);
      Map<String, String> responsablesActualizado = Map.from(_responsablesPorVariedad);

      // Agregar variedad si no existe
      if (variedadDescripcion != null && variedadDescripcion.isNotEmpty) {
        if (!variedadesActualizadas.contains(variedadDescripcion)) {
          variedadesActualizadas.insert(1, variedadDescripcion);
          debugPrint('➕ Variedad agregada a dropdown: $variedadDescripcion');
        }
        if (idVariedadStr != null) {
          variedadesIdMapActualizado[variedadDescripcion] = idVariedadStr;
        }
        if (responsableLote != null && responsableLote.isNotEmpty) {
          responsablesActualizado[variedadDescripcion] = responsableLote;
        }
      }

      // Agregar casa si no existe
      if (casaLote != null && casaLote.isNotEmpty && 
          !casasActualizadas.contains(casaLote)) {
        casasActualizadas.insert(1, casaLote);
        debugPrint('➕ Casa agregada a dropdown: $casaLote');
      }

      // ===== 6. APLICAR CAMBIOS AL ESTADO =====
      if (mounted) {
        setState(() {
          // Actualizar dropdowns
          _variedades = variedadesActualizadas;
          _casas = casasActualizadas;
          _variedadesIdMap = variedadesIdMapActualizado;
          _responsablesPorVariedad = responsablesActualizado;
          
          // Aplicar valores al formulario
          _selectedVariedad = variedadDescripcion;
          _selectedCasa = casaLote;
          _casaController.text = casaLote ?? '';
          _canteroController.text = loteInfo['pmlt_cantero'] ?? '';
          _responsableController.text = responsableLote ?? '';
          _cantidadController.text = '0';
          
          // Guardar valores originales del lote
          _loteCanterosOriginal = loteInfo['pmlt_canteros'];
          _loteContenedorOriginal = loteInfo['pmlt_contenedor'] ?? 'CONT_GENERAL';
          
          _isLoading = false;
        });

        // ===== 7. INICIAR WIZARD SI HAY RANGO DE CANTEROS =====
        final canterosLote = loteInfo['pmlt_canteros'];
        if (canterosLote != null && canterosLote.toString().isNotEmpty) {
          _canterosRangeController.text = canterosLote.toString();
          initWizard(canterosLote.toString());
          debugPrint('🧙 Wizard iniciado con rango: $canterosLote');
        }
        
        _showMessage('✅ Lote $codigoLote cargado correctamente');
        debugPrint('✅ Lote $codigoLote procesado completamente');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en _loadLoteData: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
        _showMessage('❌ Error cargando lote');
      }
    }
  }

  /// Buscar lote en el catálogo completo de lotes (segunda capa de búsqueda)
  Future<Map<String, dynamic>?> _buscarLoteEnCatalogo(
      String codigoLote, OfflineDatabaseService offlineDbService) async {
    try {
      final lotesData = await offlineDbService.getCatalogo('lotes');
      
      if (lotesData == null) {
        debugPrint('⚠️ Catálogo de lotes no disponible en SQLite');
        return null;
      }

      List<dynamic> lotesList;
      if (lotesData is List) {
        lotesList = lotesData;
      } else if (lotesData is String) {
        try {
          lotesList = json.decode(lotesData) as List<dynamic>;
        } catch (e) {
          debugPrint('⚠️ Error decodificando catálogo de lotes: $e');
          return null;
        }
      } else {
        debugPrint('⚠️ Formato inesperado: ${lotesData.runtimeType}');
        return null;
      }

      debugPrint('🔍 Buscando lote $codigoLote en ${lotesList.length} lotes...');

      for (var lote in lotesList) {
        if (lote is! Map) continue;

        final loteCodigo = lote['pmlt_codigo']?.toString();
        if (loteCodigo == codigoLote) {
          final estatus = lote['pmlt_estatus'] ?? lote['estatus'] ?? 1;
          if (estatus != 1) {
            debugPrint('⚠️ Lote $codigoLote encontrado pero inactivo');
            return null;
          }

          debugPrint('✅ Lote $codigoLote encontrado en catálogo');

          return {
            'pmlt_secuencia': lote['pmlt_secuencia'],
            'pmlt_codigo': lote['pmlt_codigo'],
            'pmlt_casa': lote['pmlt_casa'],
            'pmlt_canteros': lote['pmlt_canteros'],
            'pmlt_cantero': lote['pmlt_cantero'] ?? '',
            'pmlt_idvariedad': lote['pmlt_idvariedad'],
            'pmlt_contenedor': lote['pmlt_contenedor'] ?? 'CONT_GENERAL',
            'pmlt_cantidad': lote['pmlt_cantidad'],
            'pmlt_grower': lote['pmlt_grower'],
            'pmlt_variedad': lote['pmva_descripcion'] ?? lote['pmlt_variedad'],
            'pmva_descripcion': lote['pmva_descripcion'],
            'pmva_responsable': lote['pmva_responsable'] ?? lote['pmlt_grower'],
            'pmlt_estatus': estatus,
          };
        }
      }

      debugPrint('⚠️ Lote $codigoLote no encontrado en catálogo');
      return null;
    } catch (e) {
      debugPrint('❌ Error buscando lote en catálogo: $e');
      return null;
    }
  }


  // ===== MANEJO DE DUPLICADOS =====
  
  Future<void> _showDuplicateDialog(String message, int? duplicateId) async {
    if (duplicateId == null) return;

    final shouldEdit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 56),
        title: Text('Registro Duplicado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(fontSize: 14)),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¿Desea editar el registro existente?',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text('ID del registro: $duplicateId',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icon(Icons.edit, size: 18),
            label: Text('Editar Existente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    if (shouldEdit == true && mounted) {
      await _loadAndEditExistingMonitoreo(duplicateId);
    }
  }

  Future<void> _showCloseWizardDialog() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.info_outline, color: Colors.blue, size: 56),
        title: Text('Cerrar Wizard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El wizard está activo. Al cambiar de tab se guardará el cantero actual y se cerrará el wizard.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.save, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se guardará el cantero ${wizardCanteroActual}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade900, fontSize: 13),
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
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icon(Icons.check, size: 18),
            label: Text('Guardar y Cerrar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    if (shouldClose == true && mounted) {
      // Guardar cantero actual y cerrar wizard
      await wizardFinish();
      // Cambiar al tab de Consulta
      _tabController.animateTo(0);
    } else {
      // Cancelar - volver al tab de Registro
      _tabController.animateTo(1);
    }
  }

  /// Maneja el botón "Finalizar" del wizard
  /// 
  /// IMPORTANTE: Guarda el cantero actual ANTES de cerrar el wizard
  /// 
  /// Flujo:
  /// 1. Valida que el formulario actual esté completo
  /// 2. Si hay errores → Muestra mensaje, NO cierra
  /// 3. Si todo OK → Guarda el cantero actual primero
  /// 4. Luego cierra el wizard y cambia a tab Consulta
  Future<void> _handleWizardFinish() async {
    if (!isWizardActive) return;
    
    debugPrint('🏁 [FINALIZAR] Iniciando finalización de wizard...');
    
    // PASO 1: Validar que el formulario actual esté completo
    // (Solo validar si hay datos en el formulario)
    final hasDataInForm = _canteroController.text.isNotEmpty ||
                          _selectedPlaga != null ||
                          _cantidadController.text.isNotEmpty;
    
    if (hasDataInForm) {
      debugPrint('📋 [FINALIZAR] Hay datos en formulario, validando...');
      
      // Validar campos requeridos
      if (_codigoLoteController.text.isEmpty) {
        _showMessage('⚠️ Falta código de lote');
        return;
      }
      
      if (_selectedCasa == null || _selectedCasa!.isEmpty) {
        _showMessage('⚠️ Falta seleccionar casa');
        return;
      }
      
      if (_canteroController.text.isEmpty) {
        _showMessage('⚠️ Falta número de cantero');
        return;
      }
      
      if (_selectedPlaga == null || _selectedPlaga!.isEmpty) {
        _showMessage('⚠️ Falta seleccionar plaga');
        return;
      }
      
      if (_cantidadController.text.isEmpty) {
        _showMessage('⚠️ Falta cantidad');
        return;
      }
      
      // PASO 2: Todo OK → Guardar el cantero actual PRIMERO
      debugPrint('✅ [FINALIZAR] Validación OK, guardando cantero actual...');
      await _saveMonitoreo();
      
      // Verificar si el guardado fue exitoso
      if (!_lastSaveSuccess) {
        debugPrint('❌ [FINALIZAR] Error guardando, no se cierra wizard');
        _showMessage('❌ Error al guardar. Corrija los errores antes de finalizar.');
        return;
      }
      
      debugPrint('✅ [FINALIZAR] Cantero guardado exitosamente');
    } else {
      debugPrint('ℹ️ [FINALIZAR] No hay datos en formulario actual, solo cerrando wizard');
    }
    
    // PASO 3: Cerrar el wizard
    debugPrint('🏁 [FINALIZAR] Cerrando wizard...');
    await wizardFinish();
    
    // PASO 4: Cambiar a tab de Consulta y recargar datos
    if (mounted) {
      _tabController.animateTo(0);
      await loadData();
      debugPrint('✅ [FINALIZAR] Wizard finalizado exitosamente');
    }
  }

  /// Helper: Detecta si el formulario de monitoreo está vacío
  /// 
  /// Un formulario se considera vacío cuando NO tiene:
  /// - Plaga seleccionada
  /// - Cantidad ingresada
  /// - Comentarios
  bool _isFormEmpty() {
    final hasPlaga = _selectedPlaga != null && _selectedPlaga!.isNotEmpty;
    final hasCantidad = _cantidadController.text.isNotEmpty && 
                        _cantidadController.text != '0';
    final hasComentarios = _comentariosController.text.isNotEmpty;
    
    // Formulario vacío = no tiene ninguno de los campos importantes
    final isEmpty = !hasPlaga && !hasCantidad && !hasComentarios;
    
    debugPrint('📋 [FORM CHECK] isEmpty=$isEmpty (plaga=$hasPlaga, cantidad=$hasCantidad, comentarios=$hasComentarios)');
    
    return isEmpty;
  }

  /// Override de wizardNext del mixin para agregar lógica de guardado en modo parcial/wizard
  /// 
  /// Flujo:
  /// 1. Si formulario VACÍO → Muestra diálogo para confirmar saltar cantero
  /// 2. Si formulario CON DATOS → Muestra diálogo para guardar o continuar sin guardar
  @override
  Future<void> wizardNext() async {
    if (!isWizardActive) return;
    
    debugPrint('➡️ [WIZARD NEXT] Iniciando...');
    
    // Detectar si el formulario está vacío
    final formEmpty = _isFormEmpty();
    
    if (formEmpty) {
      // CASO 1: Formulario vacío
      debugPrint('⚠️ [WIZARD NEXT] Formulario vacío detectado');
      
      final canteroActual = _canteroController.text;
      
      // Mostrar diálogo para confirmar saltar cantero vacío
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.warning_amber, color: Colors.orange, size: 56),
          title: Text(
            '⚠️ Cantero $canteroActual sin datos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El formulario está vacío.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                '¿Desea continuar al siguiente cantero sin guardar el cantero $canteroActual?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No, quedarme aquí', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text('Sí, continuar', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
      
      if (confirmar != true) {
        debugPrint('❌ [WIZARD NEXT] Usuario decidió quedarse en cantero actual');
        return; // Usuario decidió quedarse para llenar el formulario
      }
      
      debugPrint('✅ [WIZARD NEXT] Usuario confirmó saltar cantero vacío');
      
      // Limpiar el formulario y avanzar al siguiente cantero
      _clearMonitoreoData();
      
      // Llamar al método original del mixin para avanzar
      await super.wizardNext();
      
    } else {
      // CASO 2: Formulario con datos
      debugPrint('📝 [WIZARD NEXT] Formulario con datos detectado');
      
      final canteroActual = _canteroController.text;
      
      // Mostrar diálogo para guardar o continuar sin guardar
      final accion = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.save, color: Colors.blue, size: 56),
          title: Text(
            '💾 Guardar cambios',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hay datos sin guardar en el cantero $canteroActual.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                '¿Desea guardar los cambios antes de continuar al siguiente cantero?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Cancelar', style: TextStyle(fontSize: 14)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('no_save'),
              child: Text('Continuar sin guardar', style: TextStyle(fontSize: 14, color: Colors.orange)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar y continuar', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
      
      if (accion == 'cancel' || accion == null) {
        debugPrint('❌ [WIZARD NEXT] Usuario canceló');
        return;
      }
      
      if (accion == 'no_save') {
        debugPrint('⚠️ [WIZARD NEXT] Usuario decidió continuar sin guardar');
        // Limpiar el formulario y avanzar sin guardar
        _clearMonitoreoData();
        await super.wizardNext();
        return;
      }
      
      if (accion == 'save') {
        debugPrint('💾 [WIZARD NEXT] Usuario decidió guardar antes de continuar');
        
        // Guardar usando el método de guardado parcial (modo wizard)
        await _saveMonitoreoParcial();
        
        // Verificar si el guardado fue exitoso
        if (!_lastSaveSuccess) {
          debugPrint('❌ [WIZARD NEXT] Error guardando, no se avanza');
          _showMessage('❌ Error al guardar. Corrija los errores antes de continuar.');
          return;
        }
        
        debugPrint('✅ [WIZARD NEXT] Guardado exitoso, preparando avance...');
        
        // Limpiar completamente el estado ANTES de avanzar
        // Esto es CRÍTICO para que super.wizardNext() no vuelva a mostrar diálogo
        _clearMonitoreoData();
        
        // IMPORTANTE: Limpiar estado de modo parcial
        setState(() {
          isInPartialSaveMode = false;
          plagasRegistradasParcial.clear();
          variedadesUsadasParcial.clear();
        });
        
        debugPrint('🧹 [WIZARD NEXT] Estado limpiado completamente');
        
        // Pequeño delay para asegurar que setState se aplique
        await Future.delayed(Duration(milliseconds: 10));
        
        // Ahora avanzar - super.wizardNext() no debería mostrar diálogo porque estado está limpio
        debugPrint('➡️ [WIZARD NEXT] Llamando a super.wizardNext()...');
        await super.wizardNext();
        
        debugPrint('✅ [WIZARD NEXT] Avance completado');
      }
    }
  }

  Future<void> _loadAndEditExistingMonitoreo(int monitoreoId) async {
    try {
      setState(() => _isLoading = true);

      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final monitoreo = await monitoreoService.getMonitoreoById(monitoreoId);
      
      if (monitoreo != null && mounted) {
        _editMonitoreo(monitoreo);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.edit, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Editando registro existente (ID: $monitoreoId)', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al cargar monitoreo existente: $e');
      if (mounted) {
        FriendlyErrorDialog.show(
          context,
          title: 'Error',
          message: 'No se pudo cargar el registro: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editMonitoreo(Monitoreo monitoreo, {bool fromNavigation = false}) {
    if (!mounted) return;

    setState(() {
      _currentMonitoreo = monitoreo;
      _isEditing = true;
      _isCreatingNew = false;

      _codigoLoteController.text = monitoreo.pmlt_codigo ?? '';
      _selectedCasa = monitoreo.pmmo_casa;
      _casaController.text = monitoreo.pmmo_casa ?? '';
      _canteroController.text = monitoreo.pmmo_cantero ?? '';
      
      _selectedVariedad = monitoreo.pmmo_variedad ?? monitoreo.pmva_descripcion;
      _selectedPlaga = monitoreo.pmni_nombrecomun;
      
      _responsableController.text = monitoreo.pmmo_grower ?? '';
      _comentariosController.text = monitoreo.pmmo_comentarios ?? '';
      _cantidadController.text = monitoreo.pmmo_cantidad?.toString() ?? '0';
      _cantidadBotadaController.text = monitoreo.pmmo_cant_botada?.toString() ?? '';
      
      _muestra1Controller.text = monitoreo.pmmo_muestra1?.toString() ?? '';
      _muestra2Controller.text = monitoreo.pmmo_muestra2?.toString() ?? '';
      _muestra3Controller.text = monitoreo.pmmo_muestra3?.toString() ?? '';
      
      _selectedNivelMuestra1 = monitoreo.pmmo_nivmuestram1?.toString();
      _selectedNivelMuestra2 = monitoreo.pmmo_nivmuestram2?.toString();
      _selectedNivelMuestra3 = monitoreo.pmmo_nivmuestram3?.toString();

      _isManualEntry = !(monitoreo.pmmo_automatico ?? false);
    });

    if (!fromNavigation && mounted) {
      _tabController.animateTo(1);
    }

    _updateEditMode(true);
  }

  void _prepareFormForNewPartial() {
    if (!mounted) return;
    setState(() {
      _selectedPlaga = null;
      _selectedVariedad = _isManualEntry ? null : _selectedVariedad;
      _comentariosController.clear();
      _cantidadController.text = '0';
      _cantidadBotadaController.clear();
      _muestra1Controller.clear();
      _muestra2Controller.clear();
      _muestra3Controller.clear();
      _selectedNivelMuestra1 = null;
      _selectedNivelMuestra2 = null;
      _selectedNivelMuestra3 = null;
      _currentMonitoreo = null;
      _isCreatingNew = true;
      _isEditing = true;
      _isEditingExistingPartial = false;
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Está seguro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final authService = Provider.of<AuthService>(context, listen: false);
              authService.logout();
              Navigator.of(context).pushNamedAndRemoveUntil(RoutesManager.login, (route) => false);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarInfoApp() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.indigo, size: 28),
              SizedBox(width: 12),
              Text('Información', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Aplicación', packageInfo.appName),
              _buildInfoRow('Versión', '${packageInfo.version}'),
              _buildInfoRow('Build', packageInfo.buildNumber),
              Divider(height: 20),
              _buildInfoRow('Estado', _cachedIntranetService?.isConnected.value == true ? '🟢 Conectado' : '🔴 Offline'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error mostrando info: $e');
      if (mounted) {
        _showMessage('Error mostrando información');
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _handleSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      final columnDef = _columns.firstWhere((col) => col['title'] == column, orElse: () => {});
      if (columnDef.containsKey('valueExtractor')) {
        final valueExtractor = columnDef['valueExtractor'] as Function;
        final isNumeric = columnDef['isNumeric'] == true;
        _filteredMonitoreoData.sort((a, b) {
          var aValue = valueExtractor(a);
          var bValue = valueExtractor(b);
          if (isNumeric) {
            final aNum = int.tryParse(aValue) ?? 0;
            final bNum = int.tryParse(bValue) ?? 0;
            return ascending ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
          }
          return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
        });
      }
    });
  }

  void _handleColumnResize(String columnTitle, double newWidth) {
    if (mounted) {
      setState(() {
        _columnWidths[columnTitle] = newWidth;
        for (var column in _columns) {
          if (column['title'] == columnTitle) {
            column['width'] = newWidth;
            break;
          }
        }
      });
    }
  }

  Future<void> _exportToExcel(String fileName, bool onlyFiltered) async {
    if (!mounted) return;
    try {
      setState(() => _isLoading = true);
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final dataToExport = onlyFiltered ? _filteredMonitoreoData : _monitoreoData;
      final success = await monitoreoService.exportarMonitoreosExcel(dataToExport, fileName, _columns);
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage(success ? 'Exportado correctamente' : 'Error al exportar');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Error: $e');
      }
    }
  }

  void _handlePageChange(int page) {
    if (page > 0 && page <= _totalPages && mounted) {
      setState(() {
        _currentPage = page;
        _applyPagination();
      });
    }
  }

  void _applyPagination() {
    if (!mounted) return;
    _totalItems = _monitoreoData.length;
    _totalPages = (_totalItems / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages && _totalPages > 0) _currentPage = _totalPages;
    
    if (_sortColumn != null) {
      final columnDef = _columns.firstWhere((col) => col['title'] == _sortColumn, orElse: () => {});
      if (columnDef.containsKey('valueExtractor')) {
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
          return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
        });
      }
    }
    
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > _totalItems) endIndex = _totalItems;
    
    if (_monitoreoData.isNotEmpty && startIndex < _monitoreoData.length) {
      _filteredMonitoreoData = _monitoreoData.sublist(
          startIndex, endIndex < _monitoreoData.length ? endIndex : _monitoreoData.length);
    } else {
      _filteredMonitoreoData = [];
    }
  }

  void _handleItemsPerPageChange(int newItemsPerPage) {
    if (mounted) {
      setState(() {
        _itemsPerPage = newItemsPerPage;
        _currentPage = 1;
        _applyPagination();
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
        } catch (e) {
          debugPrint('Error: $e');
        }
      }
    });
  }

  Future<void> _loadInfoPlagaAction(String nombrePlaga) async {
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final nivelesData = await monitoreoService.getNivelesPlaga(nombrePlaga);
      if (mounted && nivelesData.isNotEmpty) {
        setState(() {
          _limiteNivel1 = nivelesData['lmsupniv1'] ?? 10;
          _limiteNivel2 = nivelesData['lmsupniv2'] ?? 20;
          _limiteNivel3 = nivelesData['lmsupniv3'] ?? 30;
        });
      }
    } catch (e) {
      _loadNivelesLimites();
    }
  }

  String _getDefaultLoteCode() => "15207";

  String _obtenerIdVariedad(String? descripcionVariedad) {
    if (descripcionVariedad == null) return '';
    if (descripcionVariedad == 'Variedad genérica') return '0';
    return _variedadesIdMap[descripcionVariedad] ?? '';
  }

  List<String> _obtenerListaCanteros() {
    Set<String> canteros = {'Todos'};
    for (var monitoreo in _monitoreoData) {
      if (monitoreo.pmmo_cantero != null &&
          monitoreo.pmmo_cantero!.isNotEmpty &&
          monitoreo.pmmo_cantero != 'Todos') {
        canteros.add(monitoreo.pmmo_cantero!);
      }
    }
    List<String> resultado = canteros.toList();
    resultado.sort((a, b) => a == 'Todos' ? -1 : b == 'Todos' ? 1 : a.compareTo(b));
    return resultado;
  }

  // ===== CARGA DE DATOS AUXILIARES =====
  
  Future<void> _loadVariedades() async {
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<dynamic>? variedadesList;
      variedadesList = await offlineDbService.getVariedades();
      debugPrint('📦 Variedades en SQLite: ${variedadesList?.length ?? 0}');

      bool tieneDatosValidos = false;
      if (variedadesList != null && variedadesList.isNotEmpty) {
        if (variedadesList[0] is Map) {
          final primerVariedad = variedadesList[0] as Map;
          tieneDatosValidos = primerVariedad.containsKey('codigo') || primerVariedad.containsKey('pmva_codigo');
          
          if (!tieneDatosValidos) {
            debugPrint('⚠️ Datos en SQLite sin campo código - Forzando re-descarga...');
            variedadesList = null;
          }
        }
      }

      if ((variedadesList == null || !tieneDatosValidos) && intranetService.isConnected.value) {
        debugPrint('🌐 Descargando variedades actualizadas de API...');
        try {
          final variedadesData = await monitoreoService.getDatosAuxiliares('variedades');
          if (variedadesData['data'] != null && variedadesData['data'] is List) {
            variedadesList = variedadesData['data'];
            await offlineDbService.saveVariedades(variedadesList!);
            debugPrint('💾 Variedades guardadas en SQLite: ${variedadesList.length}');
          }
        } catch (e) {
          debugPrint('⚠️ Error descargando variedades de API: $e');
        }
      }

      if (mounted && variedadesList != null && variedadesList.isNotEmpty) {
        Map<String, String> nuevoMapa = {};
        Map<String, String> nuevoMapaIds = {};
        
        setState(() {
          _variedades = ['Variedad genérica'];
          
          for (var variedad in variedadesList!) {
            if (variedad is Map) {
              final estatus = variedad['estatus'] ?? variedad['pmva_estatus'] ?? 1;
              if (estatus != 1) continue;
              
              String? descripcion = variedad['descripcion']?.toString() ?? variedad['pmva_descripcion']?.toString();
              String? responsable = variedad['responsable']?.toString() ?? variedad['pmva_responsable']?.toString();
              var codigo = variedad['codigo']?.toString() ?? variedad['pmva_codigo']?.toString();
              
              if (codigo == null || codigo.isEmpty) {
                debugPrint('⚠️ Variedad sin código: $descripcion');
                continue;
              }
              
              if (descripcion != null && descripcion.isNotEmpty) {
                if (!_variedades.contains(descripcion)) _variedades.add(descripcion);
                if (responsable != null) nuevoMapa[descripcion] = responsable;
                nuevoMapaIds[descripcion] = codigo;
                debugPrint('✅ Variedad: $descripcion → Código: $codigo');
              }
            }
          }
          
          _responsablesPorVariedad = nuevoMapa;
          _variedadesIdMap = nuevoMapaIds;
        });
        
        debugPrint('✅ Variedades procesadas: ${_variedades.length}');
      } else {
        if (mounted) setState(() => _variedades = ['Variedad genérica']);
        debugPrint('⚠️ Sin variedades disponibles');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadVariedades: $e');
      if (mounted) setState(() => _variedades = ['Variedad genérica']);
    }
  }

  Future<void> _loadCasas() async {
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<dynamic>? casasList;
      casasList = await offlineDbService.getCasas();
      debugPrint('📦 Casas en SQLite: ${casasList?.length ?? 0}');

      if ((casasList == null || casasList.isEmpty) && intranetService.isConnected.value) {
        debugPrint('🌐 SQLite vacío, descargando casas de API...');
        try {
          final response = await monitoreoService.getDatosAuxiliares('casas');
          if (response['data'] != null && response['data'] is List) {
            casasList = response['data'];
            await offlineDbService.saveCasas(casasList!);
            debugPrint('💾 Casas guardadas en SQLite: ${casasList.length}');
          }
        } catch (e) {
          debugPrint('⚠️ Error descargando casas de API: $e');
        }
      }

      if (mounted && casasList != null && casasList.isNotEmpty) {
        setState(() {
          casasData = {'data': casasList};
          _casas = ['Casa genérica'];
          for (var casa in casasList!) {
            String? codigo;
            if (casa is Map) {
              final estatus = casa['estatus'] ?? casa['pmun_estatus'] ?? 1;
              if (estatus != 1) continue;
              codigo = casa['codigo']?.toString() ?? casa['pmun_codigo']?.toString() ?? casa['pmun_descripcion']?.toString();
            } else if (casa is String) {
              codigo = casa;
            }
            if (codigo != null && codigo.isNotEmpty && !_casas.contains(codigo)) _casas.add(codigo);
          }
        });
        debugPrint('✅ Casas procesadas: ${_casas.length}');
      } else {
        if (mounted) setState(() => _casas = ['Casa genérica']);
        debugPrint('⚠️ Sin casas disponibles');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadCasas: $e');
      if (mounted) setState(() => _casas = ['Casa genérica']);
    }
  }

  Future<void> _loadPlagas() async {
    try {
      setState(() => _isLoading = true);
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<String> plagasNombres = [];
      final plagasFromMethod = await offlineDbService.getPlagas();
      debugPrint('📦 Plagas en SQLite: ${plagasFromMethod?.length ?? 0}');

      if (plagasFromMethod != null && plagasFromMethod.isNotEmpty) {
        plagasNombres = plagasFromMethod;
      }

      if (plagasNombres.isEmpty && intranetService.isConnected.value) {
        debugPrint('🌐 SQLite vacío, descargando plagas de API...');
        try {
          plagasNombres = await monitoreoService.getPlagasActivasNombres();
          if (plagasNombres.isNotEmpty) {
            await offlineDbService.savePlagas(plagasNombres);
            debugPrint('💾 Plagas guardadas en SQLite: ${plagasNombres.length}');
          }
        } catch (e) {
          debugPrint('⚠️ Error descargando plagas de API: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _plagas = plagasNombres.isNotEmpty ? plagasNombres : ['Plaga genérica'];
        });
        debugPrint('✅ Plagas procesadas: ${_plagas.length}');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadPlagas: $e');
      if (mounted) setState(() {
        _isLoading = false;
        _plagas = ['Plaga genérica'];
      });
    }
  }

  Future<void> _loadNivelesLimites() async {
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      Map<String, dynamic>? nivelesData;
      nivelesData = await offlineDbService.getNivelesLimites();
      debugPrint('📦 Niveles en SQLite: ${nivelesData != null ? "SÍ" : "NO"}');

      if (nivelesData == null && intranetService.isConnected.value) {
        debugPrint('🌐 SQLite vacío, descargando niveles de API...');
        try {
          final response = await monitoreoService.getDatosAuxiliares('niveles');
          if (response['data'] != null && response['data'] is Map) {
            nivelesData = Map<String, dynamic>.from(response['data']);
            await offlineDbService.saveNivelesLimites(nivelesData);
            debugPrint('💾 Niveles guardados en SQLite');
          }
        } catch (e) {
          debugPrint('⚠️ Error descargando niveles de API: $e');
        }
      }

      if (mounted && nivelesData != null) {
        setState(() {
          _limiteNivel1 = nivelesData!['lmsupniv1'] ?? 10;
          _limiteNivel2 = nivelesData!['lmsupniv2'] ?? 20;
          _limiteNivel3 = nivelesData!['lmsupniv3'] ?? 30;
        });
        debugPrint('✅ Niveles procesados: $_limiteNivel1/$_limiteNivel2/$_limiteNivel3');
      } else {
        if (mounted) setState(() {
          _limiteNivel1 = 10;
          _limiteNivel2 = 20;
          _limiteNivel3 = 30;
        });
        debugPrint('⚠️ Usando niveles por defecto');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadNivelesLimites: $e');
    }
  }

  void _updateEditMode(bool isEditing) {
    if (widget.onEditModeChanged != null && mounted) {
      if (WidgetsBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onEditModeChanged!(isEditing);
          });
        } catch (e) {
          print('Ignorando: $e');
        }
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      
      List<Monitoreo> monitoreos = [];

      if (intranetService.isConnected.value) {
        try {
          monitoreos = await monitoreoService.getMonitoreos();
          for (final m in monitoreos) {
            await offlineDbService.saveMonitoreoFromMap(m.toJson(), isLocal: false);
          }
          debugPrint('💾 ${monitoreos.length} monitoreos guardados en SQLite');
          await cacheService.saveData('monitoreos_data', monitoreos.map((m) => m.toJson()).toList());
          await cacheService.saveData('last_online_sync', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint('⚠️ Error cargando de API, intentando SQLite: $e');
          final sqliteData = await offlineDbService.getAllMonitoreos();
          if (sqliteData.isNotEmpty) {
            monitoreos = sqliteData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();
            debugPrint('📦 ${monitoreos.length} monitoreos cargados desde SQLite (fallback)');
          } else {
            final cachedData = await cacheService.loadData('monitoreos_data');
            if (cachedData != null && cachedData is List) {
              monitoreos = cachedData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();
              debugPrint('📦 ${monitoreos.length} monitoreos cargados desde cache (fallback)');
            }
          }
        }
      } else {
        debugPrint('📴 Modo OFFLINE - Cargando desde SQLite...');
        final sqliteData = await offlineDbService.getAllMonitoreos();
        if (sqliteData.isNotEmpty) {
          monitoreos = sqliteData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();
          debugPrint('📦 ${monitoreos.length} monitoreos cargados desde SQLite');
        } else {
          final cachedData = await cacheService.loadData('monitoreos_data');
          if (cachedData != null && cachedData is List) {
            monitoreos = cachedData.map<Monitoreo>((json) => Monitoreo.fromJson(json)).toList();
            debugPrint('📦 ${monitoreos.length} monitoreos cargados desde cache (fallback)');
          }
        }
        _showMessage('Modo offline - ${monitoreos.length} registros locales');
      }

      if (authService.mustFilterByUser && authService.getCurrentUserId() != null) {
        final userId = authService.getCurrentUserId();
        monitoreos = monitoreos.where((m) => m.pmmo_creadopor == userId).toList();
      }
      
      if (mounted) {
        setState(() {
          _monitoreoData = monitoreos;
          _currentPage = 1;
          _applyPagination();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
        _showMessage('Error: $e');
      }
    }
  }

  // ===== GUARDADO Y ACTUALIZACIÓN =====
  
  Future<void> _saveMonitoreo() async {
    if (!mounted) return;

    // Validaciones básicas
    if (_isManualEntry && (_selectedVariedad == null || _selectedVariedad!.isEmpty)) {
      setState(() => _errorMessage = 'Seleccione variedad');
      _showMessage('Seleccione variedad');
      return;
    }

    if (_codigoLoteController.text.isEmpty) {
      setState(() => _errorMessage = 'Ingrese código de lote');
      _showMessage('Ingrese código de lote');
      return;
    }

    if (_selectedCasa == null || _selectedCasa!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione casa');
      _showMessage('Seleccione casa');
      return;
    }

    if (_canteroController.text.isEmpty) {
      setState(() => _errorMessage = 'Ingrese cantero');
      _showMessage('Ingrese cantero');
      return;
    }

    if (_selectedPlaga == null || _selectedPlaga!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione plaga');
      _showMessage('Seleccione plaga');
      return;
    }

    if (_cantidadController.text.isEmpty) {
      setState(() => _errorMessage = 'Ingrese cantidad');
      _showMessage('Ingrese cantidad');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
      _lastSaveSuccess = false;
    });

    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;

      final userId = authService.getCurrentUserId();
      final cantidad = int.tryParse(_cantidadController.text) ?? 0;
      final cantidadBotada = int.tryParse(_cantidadBotadaController.text) ?? 0;
      
      final muestra1 = int.tryParse(_muestra1Controller.text) ?? 0;
      final muestra2 = int.tryParse(_muestra2Controller.text) ?? 0;
      final muestra3 = int.tryParse(_muestra3Controller.text) ?? 0;

      final nivelMuestra1 = _selectedNivelMuestra1 != null ? int.tryParse(_selectedNivelMuestra1!) : null;
      final nivelMuestra2 = _selectedNivelMuestra2 != null ? int.tryParse(_selectedNivelMuestra2!) : null;
      final nivelMuestra3 = _selectedNivelMuestra3 != null ? int.tryParse(_selectedNivelMuestra3!) : null;

      final idVariedad = _obtenerIdVariedad(_selectedVariedad);
      
      // IMPORTANTE: En modo wizard, siempre usar el rango completo en pmmo_canteros
      // Ejemplo: si wizard es 4-7, todos los registros tienen pmmo_canteros = "4-7"
      // incluso si solo guardaste el cantero 4 y 5 (guardado parcial)
      final canterosRange = _canterosRangeController.text;
      final canterosParaGuardar = isWizardActive && canterosRange.isNotEmpty 
          ? canterosRange  // Wizard activo → usar rango completo siempre
          : _canteroController.text;  // Modo normal → usar cantero individual
      
      // LOGGING DETALLADO para debug
      debugPrint('💾 [SAVE] Preparando guardado:');
      debugPrint('   - isWizardActive: $isWizardActive');
      debugPrint('   - canterosRange (_canterosRangeController): "$canterosRange"');
      debugPrint('   - cantero actual (_canteroController): "${_canteroController.text}"');
      debugPrint('   - canterosParaGuardar (pmmo_canteros): "$canterosParaGuardar"');

      final monitoreo = Monitoreo(
        pmmo_secuencia: _currentMonitoreo?.pmmo_secuencia,
        pmlt_codigo: _codigoLoteController.text,
        pmmo_casa: _selectedCasa ?? _casaController.text,
        pmmo_cantero: _canteroController.text,  // Cantero individual actual
        pmmo_canteros: canterosParaGuardar,  // Rango completo (en wizard) o individual (normal)
        pmmo_variedad: _selectedVariedad ?? '',
        pmmo_idvariedad: idVariedad,
        pmmo_grower: _responsableController.text,
        pmni_nombrecomun: _selectedPlaga,
        pmmo_cantidad: cantidad,
        pmmo_cant_botada: cantidadBotada,
        pmmo_comentarios: _comentariosController.text,
        pmmo_fecha: DateTime.now(),
        pmmo_automatico: !_isManualEntry,
        pmmo_estatus: 1,
        pmmo_creadopor: userId,
        pmmo_fechacreacion: DateTime.now(),
        pmmo_nivmuestram1: nivelMuestra1,
        pmmo_nivmuestram2: nivelMuestra2,
        pmmo_nivmuestram3: nivelMuestra3,
        pmmo_muestra1: muestra1,
        pmmo_muestra2: muestra2,
        pmmo_muestra3: muestra3,
        lmsupniv1: _limiteNivel1,
        lmsupniv2: _limiteNivel2,
        lmsupniv3: _limiteNivel3,
        pmmo_contenedor: _loteContenedorOriginal,
      );

      if (intranetService == null || !intranetService.isConnected.value) {
        // Modo OFFLINE
        debugPrint('📴 Guardando en modo OFFLINE...');
        
        if (_currentMonitoreo != null) {
          // Actualización
          await offlineDbService.saveMonitoreoFromMap(monitoreo.toJson(), isLocal: true);
          await registerPendingChange('update', monitoreo);
          
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _lastSaveSuccess = true;
            });
            _showMessage('Actualizado offline - Se sincronizará al conectar');
            await _loadData();
            
            // Cerrar formulario después de actualizar
            _clearForm();
            if (mounted) {
              _tabController.animateTo(0);
            }
          }
        } else {
          // Creación
          final tempId = DateTime.now().millisecondsSinceEpoch * -1;
          final monitoreoConId = monitoreo.copyWith(
            pmmo_secuencia: tempId,
            isOfflineCreated: true,
          );
          
          await offlineDbService.saveMonitoreoFromMap(monitoreoConId.toJson(), isLocal: true);
          await registerPendingChange('create', monitoreoConId);
          
          setState(() => _lastSaveSuccess = true);
          
          if (mounted) {
            setState(() => _isSubmitting = false);
            _showMessage('Guardado offline - Se sincronizará al conectar');
            await _loadData();
            
            // Cerrar formulario si NO hay wizard activo
            if (!isWizardActive) {
              _clearForm();
              if (mounted) {
                _tabController.animateTo(0);
              }
            } else {
              // Si wizard está activo, solo limpiar datos del monitoreo
              _clearMonitoreoData();
              debugPrint('🧙 Wizard activo - Formulario permanece abierto para siguiente cantero');
            }
          }
        }
        
        return;
      }

      // Modo ONLINE
      if (_currentMonitoreo != null) {
        // Actualización
        final monitoreoActualizado = await monitoreoService.actualizarMonitoreo(monitoreo);
        await offlineDbService.saveMonitoreoFromMap(monitoreoActualizado.toJson(), isLocal: false);
        
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _lastSaveSuccess = true;
          });
          _showMessage('Monitoreo actualizado correctamente');
          await _loadData();
          
          // Cerrar formulario después de actualizar
          _clearForm();
          if (mounted) {
            _tabController.animateTo(0);
          }
        }
      } else {
        // Creación
        debugPrint('🔵 [SAVE PARCIAL] Paso 1: Llamando a crearMonitoreo...');
        final nuevoMonitoreo = await monitoreoService.crearMonitoreo(monitoreo);
        debugPrint('🔵 [SAVE PARCIAL] Paso 2: Monitoreo creado con ID: ${nuevoMonitoreo.pmmo_secuencia}');
        
        debugPrint('🔵 [SAVE PARCIAL] Paso 3: Guardando en SQLite...');
        await offlineDbService.saveMonitoreoFromMap(nuevoMonitoreo.toJson(), isLocal: false);
        debugPrint('🔵 [SAVE PARCIAL] Paso 4: Guardado en SQLite exitoso');
        
        debugPrint('🔵 [SAVE PARCIAL] Paso 5: Verificando mounted: $mounted');
        if (mounted) {
          debugPrint('🔵 [SAVE PARCIAL] Paso 6: Seteando _lastSaveSuccess = true');
          setState(() {
            _isSubmitting = false;
            _lastSaveSuccess = true;
          });
          debugPrint('🔵 [SAVE PARCIAL] Paso 7: _lastSaveSuccess seteado correctamente');
          
          _showMessage('✅ Monitoreo creado correctamente');
          debugPrint('🔵 [SAVE PARCIAL] Paso 8: Mensaje mostrado');
          
          debugPrint('🔵 [SAVE PARCIAL] Paso 9: Llamando a _loadData...');
          await _loadData();
          debugPrint('🔵 [SAVE PARCIAL] Paso 10: _loadData completado');
          
          // CAMBIO UX: Solo cerrar formulario si NO hay wizard activo
          if (!isWizardActive) {
            debugPrint('🔵 [SAVE PARCIAL] Paso 11: No hay wizard, limpiando formulario');
            _clearForm();
            if (mounted) {
              _tabController.animateTo(0);
            }
          } else {
            // Si wizard está activo, solo limpiar datos del monitoreo (no todo el formulario)
            debugPrint('🔵 [SAVE PARCIAL] Paso 11: Wizard activo, limpiando solo datos monitoreo');
            _clearMonitoreoData();
            debugPrint('🧙 Wizard activo - Formulario permanece abierto para siguiente cantero');
          }
          debugPrint('✅ [SAVE PARCIAL] COMPLETADO EXITOSAMENTE');
        } else {
          debugPrint('⚠️ [SAVE PARCIAL] Widget no montado, saltando setState');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [SAVE PARCIAL] Error capturado en catch: $e');
      debugPrint('❌ [SAVE PARCIAL] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
          _lastSaveSuccess = false;
        });
        debugPrint('❌ [SAVE PARCIAL] _lastSaveSuccess seteado a false por error');
        
        if (e.toString().contains('duplicado')) {
          final match = RegExp(r'ID: (\d+)').firstMatch(e.toString());
          if (match != null) {
            final duplicateId = int.tryParse(match.group(1)!);
            await _showDuplicateDialog(e.toString(), duplicateId);
          } else {
            _showMessage('Error: ${e.toString()}');
          }
        } else {
          FriendlyErrorDialog.show(context, title: 'Error', message: e.toString());
        }
      }
    }
  }

  Future<void> _saveMonitoreoParcial() async {
    if (!mounted) return;

    // Validaciones
    if (_isManualEntry && (_selectedVariedad == null || _selectedVariedad!.isEmpty)) {
      _showMessage('Seleccione variedad para guardado parcial');
      return;
    }

    if (_codigoLoteController.text.isEmpty || _selectedCasa == null || _canteroController.text.isEmpty) {
      _showMessage('Complete lote, casa y cantero');
      return;
    }

    if (_selectedPlaga == null || _selectedPlaga!.isEmpty) {
      _showMessage('Seleccione plaga');
      return;
    }

    // Validar duplicado en guardado parcial
    final clave = _isManualEntry
        ? '${_canteroController.text}|$_selectedVariedad|$_selectedPlaga'
        : _selectedPlaga!;
    
    if (_plagasRegistradasParcial.contains(clave) && !_isEditingExistingPartial) {
      _showMessage('Plaga ya registrada en este guardado parcial');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;

      final userId = authService.getCurrentUserId();
      final cantidad = int.tryParse(_cantidadController.text) ?? 0;
      final cantidadBotada = int.tryParse(_cantidadBotadaController.text) ?? 0;
      
      final muestra1 = int.tryParse(_muestra1Controller.text) ?? 0;
      final muestra2 = int.tryParse(_muestra2Controller.text) ?? 0;
      final muestra3 = int.tryParse(_muestra3Controller.text) ?? 0;

      final nivelMuestra1 = _selectedNivelMuestra1 != null ? int.tryParse(_selectedNivelMuestra1!) : null;
      final nivelMuestra2 = _selectedNivelMuestra2 != null ? int.tryParse(_selectedNivelMuestra2!) : null;
      final nivelMuestra3 = _selectedNivelMuestra3 != null ? int.tryParse(_selectedNivelMuestra3!) : null;

      final idVariedad = _obtenerIdVariedad(_selectedVariedad);
      
      // IMPORTANTE: En modo wizard, siempre usar el rango completo en pmmo_canteros
      // Mismo código que en _saveMonitoreo() para consistencia
      final canterosRange = _canterosRangeController.text;
      final canterosParaGuardar = isWizardActive && canterosRange.isNotEmpty 
          ? canterosRange  // Wizard activo → usar rango completo siempre
          : _canteroController.text;  // Modo normal → usar cantero individual
      
      // LOGGING DETALLADO para debug de guardado parcial
      debugPrint('💾 [SAVE PARCIAL] Preparando guardado:');
      debugPrint('   - isWizardActive: $isWizardActive');
      debugPrint('   - canterosRange (_canterosRangeController): "$canterosRange"');
      debugPrint('   - cantero actual (_canteroController): "${_canteroController.text}"');
      debugPrint('   - canterosParaGuardar (pmmo_canteros): "$canterosParaGuardar"');

      final monitoreo = Monitoreo(
        pmmo_secuencia: _currentMonitoreo?.pmmo_secuencia,
        pmlt_codigo: _codigoLoteController.text,
        pmmo_casa: _selectedCasa!,
        pmmo_cantero: _canteroController.text,  // Cantero individual actual
        pmmo_canteros: canterosParaGuardar,  // Rango completo (en wizard) o individual (normal)
        pmmo_variedad: _selectedVariedad ?? '',
        pmmo_idvariedad: idVariedad,
        pmmo_grower: _responsableController.text,
        pmni_nombrecomun: _selectedPlaga,
        pmmo_cantidad: cantidad,
        pmmo_cant_botada: cantidadBotada,
        pmmo_comentarios: _comentariosController.text,
        pmmo_fecha: DateTime.now(),
        pmmo_automatico: !_isManualEntry,
        pmmo_estatus: 1,
        pmmo_creadopor: userId,
        pmmo_fechacreacion: DateTime.now(),
        pmmo_nivmuestram1: nivelMuestra1,
        pmmo_nivmuestram2: nivelMuestra2,
        pmmo_nivmuestram3: nivelMuestra3,
        pmmo_muestra1: muestra1,
        pmmo_muestra2: muestra2,
        pmmo_muestra3: muestra3,
        lmsupniv1: _limiteNivel1,
        lmsupniv2: _limiteNivel2,
        lmsupniv3: _limiteNivel3,
        pmmo_contenedor: _loteContenedorOriginal,
      );

      Monitoreo? resultado;

      if (intranetService == null || !intranetService.isConnected.value) {
        // Modo OFFLINE
        if (_currentMonitoreo != null) {
          await offlineDbService.saveMonitoreoFromMap(monitoreo.toJson(), isLocal: true);
          await registerPendingChange('update', monitoreo);
          resultado = monitoreo;
        } else {
          final tempId = DateTime.now().millisecondsSinceEpoch * -1;
          resultado = monitoreo.copyWith(pmmo_secuencia: tempId, isOfflineCreated: true);
          await offlineDbService.saveMonitoreoFromMap(resultado.toJson(), isLocal: true);
          await registerPendingChange('create', resultado);
        }
      } else {
        // Modo ONLINE
        if (_currentMonitoreo != null) {
          resultado = await monitoreoService.actualizarMonitoreo(monitoreo);
        } else {
          resultado = await monitoreoService.crearMonitoreo(monitoreo);
        }
        await offlineDbService.saveMonitoreoFromMap(resultado.toJson(), isLocal: false);
        
        // ✅ CRÍTICO: Setear flag de éxito para que wizardNext() pueda avanzar
        setState(() {
          _lastSaveSuccess = true;
        });
      }

      if (mounted) {
        // Registrar plaga como guardada
        _plagasRegistradasParcial.add(clave);
        if (_isManualEntry && _selectedVariedad != null) {
          _variedadesUsadasParcial.add(_selectedVariedad!);
        }

        setState(() {
          _isInPartialSaveMode = true;
          _isPartialSave = true;
          _isEditingExistingPartial = false;
          partialSaveCasa = _selectedCasa;
          partialSaveLote = _codigoLoteController.text;
          partialSaveCantero = _canteroController.text;
          partialSaveVariedad = _selectedVariedad;
          partialSaveDay = DateTime.now();
          _isSubmitting = false;
        });

        // IMPORTANTE: Registrar en wizard si está activo
        if (isWizardActive && resultado.pmmo_secuencia != null) {
          registerWizardPartialSave(resultado.pmmo_secuencia!);
        }

        _clearMonitoreoData();
        await _loadData();
        prepareNavigationData();
        _showMessage('Guardado parcial - Puede agregar más plagas');
      }
    } catch (e) {
      debugPrint('❌ Error en guardado parcial: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
        FriendlyErrorDialog.show(context, title: 'Error', message: e.toString());
      }
    }
  }

  Future<void> _deleteMonitoreo(int secuencia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de eliminar este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      setState(() => _isLoading = true);
      
      final monitoreoService = Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService = Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;

      if (intranetService == null || !intranetService.isConnected.value) {
        // Modo OFFLINE
        final monitoreo = _monitoreoData.firstWhere((m) => m.pmmo_secuencia == secuencia);
        await offlineDbService.deleteMonitoreo(secuencia);
        await registerPendingChange('delete', monitoreo);
      } else {
        // Modo ONLINE
        await monitoreoService.eliminarMonitoreo(secuencia);
        await offlineDbService.deleteMonitoreo(secuencia);
      }

      if (mounted) {
        _showMessage('Registro eliminado');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        FriendlyErrorDialog.show(context, title: 'Error', message: e.toString());
      }
    }
  }

  void _clearForm() {
    if (!mounted) return;
    
    _codigoLoteController.clear();
    _casaController.clear();
    _canteroController.clear();
    _responsableController.clear();
    _comentariosController.clear();
    _cantidadController.clear();
    _cantidadBotadaController.clear();
    _muestra1Controller.clear();
    _muestra2Controller.clear();
    _muestra3Controller.clear();
    _canterosRangeController.clear();

    setState(() {
      _selectedVariedad = null;
      _selectedPlaga = null;
      _selectedCasa = null;
      _selectedNivelMuestra1 = null;
      _selectedNivelMuestra2 = null;
      _selectedNivelMuestra3 = null;
      _currentMonitoreo = null;
      _isEditing = false;
      _isCreatingNew = false;
      _isManualEntry = false;
      _isInPartialSaveMode = false;
      _isPartialSave = false;
      _isEditingExistingPartial = false;
      _errorMessage = '';
      _loteCanterosOriginal = null;
      _loteContenedorOriginal = null;
      _cantidadController.text = '0';
      _plagasRegistradasParcial.clear();
      _variedadesUsadasParcial.clear();
      
      clearNavigationData(); // Del NavigationMixin
    });

    _updateEditMode(false);
  }

  /// Maneja el botón "Cancelar" con confirmación si hay datos sin guardar
  Future<void> _handleCancel() async {
    // Verificar si hay datos sin guardar
    final tieneDatos = _selectedPlaga != null ||
        _comentariosController.text.isNotEmpty ||
        _muestra1Controller.text.isNotEmpty ||
        _muestra2Controller.text.isNotEmpty ||
        _muestra3Controller.text.isNotEmpty ||
        (_cantidadBotadaController.text.isNotEmpty && _cantidadBotadaController.text != '0');
    
    if (tieneDatos) {
      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 56),
          title: Text('Datos sin guardar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiene datos sin guardar. ¿Desea descartarlos?', style: TextStyle(fontSize: 14)),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los datos se perderán permanentemente',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade900, fontSize: 13),
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
              child: Text('Volver', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icon(Icons.check, size: 18),
              label: Text('Descartar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
        ),
      );

      if (confirmar != true) {
        // Usuario canceló - no hacer nada
        return;
      }
    }
    
    // Limpiar formulario y cambiar a tab Consulta
    _clearForm();
    if (mounted) {
      _tabController.animateTo(0);
      await loadData();
    }
  }

  void _clearMonitoreoData() {
    if (!mounted) return;
    
    _comentariosController.clear();
    _cantidadController.clear();
    _cantidadBotadaController.clear();
    
    // CAMBIO UX: Limpiar muestras SIEMPRE (incluso en modo parcial)
    _muestra1Controller.clear();
    _muestra2Controller.clear();
    _muestra3Controller.clear();

    setState(() {
      _selectedPlaga = null;
      _selectedNivelMuestra1 = null;
      _selectedNivelMuestra2 = null;
      _selectedNivelMuestra3 = null;
      _cantidadController.text = '0';
    });
  }

  // ========================================================================
  // IMPLEMENTACIÓN DE MÉTODOS ABSTRACTOS REQUERIDOS POR LOS MIXINS
  // ========================================================================
  
  // --- Para CanteroWizardMixin ---
  @override
  TextEditingController get canteroController => _canteroController;
  
  @override
  TextEditingController get canterosRangeController => _canterosRangeController;
  
  @override
  bool get isManualEntry => _isManualEntry;
  
  @override
  String? get loteCanterosOriginal => _loteCanterosOriginal;
  
  @override
  set loteCanterosOriginal(String? value) => _loteCanterosOriginal = value;
  
  @override
  List<Monitoreo> get monitoreoData => _monitoreoData;
  
  @override
  String get currentLoteCode => _codigoLoteController.text;
  
  @override
  String get currentCasa => _casaController.text;
  
  @override
  TextEditingController get codigoLoteController => _codigoLoteController;
  
  @override
  TextEditingController get casaController => _casaController;
  
  @override
  TextEditingController get comentariosController => _comentariosController;
  
  @override
  TextEditingController get cantidadController => _cantidadController;
  
  @override
  TextEditingController get cantidadBotadaController => _cantidadBotadaController;
  
  @override
  TextEditingController get muestra1Controller => _muestra1Controller;
  
  @override
  TextEditingController get muestra2Controller => _muestra2Controller;
  
  @override
  TextEditingController get muestra3Controller => _muestra3Controller;
  
  @override
  String? get selectedPlaga => _selectedPlaga;
  
  @override
  set selectedPlaga(String? value) => _selectedPlaga = value;
  
  @override
  String? get selectedNivelMuestra1 => _selectedNivelMuestra1;
  
  @override
  set selectedNivelMuestra1(String? value) => _selectedNivelMuestra1 = value;
  
  @override
  String? get selectedNivelMuestra2 => _selectedNivelMuestra2;
  
  @override
  set selectedNivelMuestra2(String? value) => _selectedNivelMuestra2 = value;
  
  @override
  String? get selectedNivelMuestra3 => _selectedNivelMuestra3;
  
  @override
  set selectedNivelMuestra3(String? value) => _selectedNivelMuestra3 = value;
  
  @override
  Monitoreo? get currentMonitoreo => _currentMonitoreo;
  
  @override
  set currentMonitoreo(Monitoreo? value) => _currentMonitoreo = value;
  
  @override
  bool get isEditingExistingPartial => _isEditingExistingPartial;
  
  @override
  set isEditingExistingPartial(bool value) => _isEditingExistingPartial = value;
  
  @override
  Set<String> get plagasRegistradasParcial => _plagasRegistradasParcial;
  
  @override
  Set<String> get variedadesUsadasParcial => _variedadesUsadasParcial;
  
  @override
  bool get isInPartialSaveMode => _isInPartialSaveMode;
  
  @override
  set isInPartialSaveMode(bool value) => _isInPartialSaveMode = value;
  
  @override
  bool get lastSaveSuccess => _lastSaveSuccess;
  
  @override
  Future<void> saveMonitoreo() => _saveMonitoreo();
  
  @override
  void showMessage(String message) => _showMessage(message);
  
  @override
  Future<void> loadData() => _loadData();
  
  @override
  void clearMonitoreoData() => _clearMonitoreoData();
  
  // --- Para MonitoreoNavigationMixin ---
  @override
  void editMonitoreo(Monitoreo monitoreo, {bool fromNavigation = false}) =>
      _editMonitoreo(monitoreo, fromNavigation: fromNavigation);
  
  @override
  void prepareFormForNewPartial() => _prepareFormForNewPartial();
  
  // --- Para MonitoreoDataLoaderMixin ---
  @override
  bool get isLoading => _isLoading;
  
  @override
  set isLoading(bool value) => _isLoading = value;
  
  @override
  IntranetService? get cachedIntranetService => _cachedIntranetService;
  
  @override
  void _updateNivelesLimites(int nivel1, int nivel2, int nivel3) {
    if (mounted) {
      setState(() {
        _limiteNivel1 = nivel1;
        _limiteNivel2 = nivel2;
        _limiteNivel3 = nivel3;
      });
    }
  }

  // ========================================================================
  // MÉTODOS DEL HEADER PERSONALIZADO - UI OPTIMIZADA
  // ========================================================================
  
  Widget _buildCustomHeader(BuildContext context) {
    final intranetService = Provider.of<IntranetService>(context);
    final isOnline = intranetService.isConnected.value;
    
    // Calcular pendientes y estado de sincronización del Mixin
    final pendingCount = pendingChangesCount;  // Getter del MonitoreoSyncMixin
    final isSyncing = this.isSyncing;          // Getter del MonitoreoSyncMixin
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Espacio para balance visual
          const SizedBox(width: 8),
          
          const Spacer(),
          
          // Notificaciones (iconos compactos)
          _buildNotificationIcons(isOnline, pendingCount, isSyncing),
          
          const SizedBox(width: 16),
          
          // Tabs integrados
          _buildCompactTabs(),
          
          const SizedBox(width: 16),
          
          // Info de usuario
          _buildUserInfo(),
        ],
      ),
    );
  }
  
  Widget _buildNotificationIcons(bool isOnline, int pendingCount, bool isSyncing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono de conexión
        Tooltip(
          message: isOnline ? 'Conectado' : 'Sin conexión',
          child: Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        
        // Icono de pendientes/sync
        if (pendingCount > 0) ...[
          const SizedBox(width: 12),
          Tooltip(
            message: 'Sincronizar $pendingCount cambios pendientes',
            child: InkWell(
              onTap: isSyncing ? null : sincronizarCambiosPendientes,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: isSyncing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                            ),
                          )
                        : Icon(
                            Icons.sync,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                  ),
                  if (!isSyncing)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildCompactTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            icon: Icons.list_alt,
            label: 'Consulta',
            isActive: _tabController.index == 0,
            onTap: () => _tabController.animateTo(0),
          ),
          _buildTabButton(
            icon: Icons.add_circle_outline,
            label: 'Registro',
            isActive: _tabController.index == 1,
            onTap: () => _tabController.animateTo(1),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),  // Padding cuadrado para iconos
        decoration: BoxDecoration(
          color: isActive ? Colors.indigo[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,  // Icono un poco más grande sin texto
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserInfo() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUser?.name ?? 
                     authService.currentUser?.username ?? 
                     'Usuario';
    
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.indigo[600],
              child: Text(
                userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              userName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.indigo[800],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Colors.indigo[600],
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        // Información de la app
        const PopupMenuItem(
          value: 'info',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.indigo),
              SizedBox(width: 12),
              Text('Información'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        
        // === MANTENIMIENTO ===
        // Hard Refresh
        const PopupMenuItem(
          value: 'hard_refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: Colors.purple),
              SizedBox(width: 12),
              Text('Hard Refresh'),
            ],
          ),
        ),
        
        // Limpiar registros locales
        const PopupMenuItem(
          value: 'clear_local',
          child: Row(
            children: [
              Icon(Icons.delete_sweep, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Limpiar registros locales'),
            ],
          ),
        ),
        
        // Borrar base de datos
        const PopupMenuItem(
          value: 'delete_db',
          child: Row(
            children: [
              Icon(Icons.delete_forever, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Borrar base de datos'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        
        // Cerrar sesión
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        // Crear instancia del MaintenanceHelper con callback para recargar datos
        final maintenance = MaintenanceHelper(
          context,
          onSuccess: () async {
            if (mounted) {
              await loadData(); // Recargar datos después de operación exitosa
            }
          },
        );
        
        switch (value) {
          case 'info':
            _mostrarInfoApp();
            break;
            
          case 'hard_refresh':
            await maintenance.hardRefresh();
            break;
            
          case 'clear_local':
            await maintenance.limpiarRegistrosLocales();
            break;
            
          case 'delete_db':
            await maintenance.borrarBaseDatos();
            break;
            
          case 'logout':
            _logout();
            break;
        }
      },
    );
  }

  // ========================================================================
  // BUILD - INTERFAZ DE USUARIO
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;
    final intranetService = Provider.of<IntranetService>(context);
    final isOnline = intranetService.isConnected.value;
    
    // Variables de sincronización del mixin (getters públicos)
    final pendingChangesCount = this.pendingChangesCount;  // Del MonitoreoSyncMixin
    final isSyncing = this.isSyncing;                      // Del MonitoreoSyncMixin
    final lastSyncStatus = this.lastSyncStatus;            // Del MonitoreoSyncMixin

    return Scaffold(
      body: Column(
        children: [
          // Header personalizado compacto (reemplaza AppBar y SyncStatusBar)
          _buildCustomHeader(context),
          
          // Wizard Bar (si está activo)
          if (isWizardActive)
            CanteroWizardBar(
              canterosRange: _canterosRangeController.text,
              canteroActual: wizardCanteroActual,
              canteroInicio: wizardCanteroInicio,
              canteroFin: wizardCanteroFin,
              totalCanteros: wizardTotalCanteros,
              isWizardActive: isWizardActive,
              isRangeLocked: isWizardRangeLocked,
              formState: getWizardFormState(),
              loteInfo: _codigoLoteController.text,
              casaInfo: _selectedCasa,
              canGoNext: canWizardGoNext(),
              canGoPrevious: canWizardGoPrevious(),
              onNext: wizardNext,
              onPrevious: wizardPrevious,
              onSkip: wizardSkip,
              onFinish: _handleWizardFinish,  // Método inteligente: sin guardar vs con guardado
              parcialInfo: getWizardParcialInfo(),
              canteroTieneDatos: wizardCanterosMonitoreos[wizardCanteroActual]?.isNotEmpty ?? false,
              canParcialNext: canWizardParcialNext(),
              canParcialPrevious: canWizardParcialPrevious(),
              onParcialNext: wizardParcialNext,
              onParcialPrevious: wizardParcialPrevious,
              isEditingParcial: _isEditingExistingPartial,
              onRangeChanged: onCanterosRangeChanged,
            ),
          
          // Contenido principal con tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe
              children: [
                // Tab 1: Consulta
                ConsultaTab(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  monitoreos: _filteredMonitoreoData,
                  columns: _columns,
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  totalItems: _totalItems,
                  itemsPerPage: _itemsPerPage,
                  onSort: _handleSort,
                  onColumnResize: _handleColumnResize,
                  onPageChanged: _handlePageChange,
                  onItemsPerPageChanged: _handleItemsPerPageChange,
                  onEdit: _editMonitoreo,
                  onDelete: (monitoreo) => _deleteMonitoreo(monitoreo.pmmo_secuencia!),
                  onDetails: (monitoreo) {
                    MonitoreoDetailsDialog.showMonitoreoDetails(
                      context,
                      monitoreo,
                      () => _editMonitoreo(monitoreo),
                    );
                  },
                  onSearch: _loadData,
                  onReload: _loadData,
                  searchController: _searchController,
                  fechaInicioController: _fechaInicioController,
                  fechaFinController: _fechaFinController,
                  selectedEstado: _selectedEstado,
                  selectedPlaga: _selectedPlaga,
                  selectedCasa: _selectedCasaFiltro,
                  selectedCantero: _selectedCanteroFiltro,
                  selectedVariedad: _selectedVariedadFiltro,
                  fechaInicio: _fechaInicio,
                  fechaFin: _fechaFin,
                  casas: _casas,
                  canteros: _obtenerListaCanteros(),
                  variedades: _variedades,
                  plagas: _plagas,
                  onEstadoChanged: (value) => setState(() => _selectedEstado = value),
                  onPlagaChanged: (value) => setState(() => _selectedPlaga = value),
                  onCasaChanged: (value) => setState(() => _selectedCasaFiltro = value),
                  onCanteroChanged: (value) => setState(() => _selectedCanteroFiltro = value),
                  onVariedadChanged: (value) => setState(() => _selectedVariedadFiltro = value),
                  onSelectDateRange: (context) async {
                    // Implementar selector de rango de fechas
                  },
                  onFechaReset: () {
                    setState(() {
                      _fechaInicio = null;
                      _fechaFin = null;
                      _fechaInicioController.clear();
                      _fechaFinController.clear();
                    });
                  },
                  onExportExcel: _exportToExcel,
                  columnWidths: _columnWidths,
                  pendingChangesCount: pendingChangesCount,
                  isSmallScreen: isSmallScreen,
                  onNuevoMonitoreo: _nuevoMonitoreo,
                ),
                
                // Tab 2: Registro
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
                  canterosRangeController: _canterosRangeController,
                  responsableController: _responsableController,
                  comentariosController: _comentariosController,
                  cantidadController: _cantidadController,
                  cantidadBotadaController: _cantidadBotadaController,
                  muestra1Controller: _muestra1Controller,
                  muestra2Controller: _muestra2Controller,
                  muestra3Controller: _muestra3Controller,
                  selectedVariedad: _selectedVariedad,
                  selectedCasa: _selectedCasa,
                  selectedPlaga: _selectedPlaga,
                  selectedNivelMuestra1: _selectedNivelMuestra1,
                  selectedNivelMuestra2: _selectedNivelMuestra2,
                  selectedNivelMuestra3: _selectedNivelMuestra3,
                  variedades: _variedades,
                  casas: _casas,
                  plagas: _plagas,
                  limiteNivel1: _limiteNivel1,
                  limiteNivel2: _limiteNivel2,
                  limiteNivel3: _limiteNivel3,
                  isInPartialSaveMode: _isInPartialSaveMode,
                  isEditingExistingPartial: _isEditingExistingPartial,
                  plagasRegistradas: _plagasRegistradasParcial,
                  variedadesUsadas: _variedadesUsadasParcial,
                  isWizardActive: isWizardActive,
                  isWizardRangeLocked: isWizardRangeLocked,
                  wizardCanteroActual: wizardCanteroActual,
                  wizardTotalCanteros: wizardTotalCanteros,
                  onToggleEntryMode: () {
                    setState(() {
                      _isManualEntry = !_isManualEntry;
                      
                      if (_isManualEntry) {
                        // MODO MANUAL: Cargar lote por defecto
                        _codigoLoteController.text = _getDefaultLoteCode();
                        debugPrint('📝 Modo Manual activado - Lote por defecto: ${_getDefaultLoteCode()}');
                      } else {
                        // MODO CÓDIGO: Limpiar variedad manual
                        _selectedVariedad = null;
                        _responsableController.clear();
                      }
                    });
                  },
                  onVariedadChanged: (value) {
                    setState(() {
                      _selectedVariedad = value;
                      if (value != null && value != 'Variedad genérica') {
                        if (_responsablesPorVariedad.containsKey(value)) {
                          _responsableController.text = _responsablesPorVariedad[value] ?? '';
                        } else {
                          _responsableController.clear();
                        }
                      } else {
                        _responsableController.clear();
                      }
                    });
                  },
                  onCasaChanged: (value) {
                    setState(() => _selectedCasa = value);
                  },
                  onPlagaChanged: (value) {
                    setState(() => _selectedPlaga = value);
                    if (value != null) _loadInfoPlagaAction(value);
                  },
                  onNivelMuestra1Changed: (value) {
                    setState(() => _selectedNivelMuestra1 = value);
                  },
                  onNivelMuestra2Changed: (value) {
                    setState(() => _selectedNivelMuestra2 = value);
                  },
                  onNivelMuestra3Changed: (value) {
                    setState(() => _selectedNivelMuestra3 = value);
                  },
                  onMuestra1Changed: (value) {
                    setState(() {
                      final total = (int.tryParse(_muestra1Controller.text) ?? 0) +
                          (int.tryParse(_muestra2Controller.text) ?? 0) +
                          (int.tryParse(_muestra3Controller.text) ?? 0);
                      _cantidadController.text = total.toString();
                    });
                  },
                  onMuestra2Changed: (value) {
                    setState(() {
                      final total = (int.tryParse(_muestra1Controller.text) ?? 0) +
                          (int.tryParse(_muestra2Controller.text) ?? 0) +
                          (int.tryParse(_muestra3Controller.text) ?? 0);
                      _cantidadController.text = total.toString();
                    });
                  },
                  onMuestra3Changed: (value) {
                    setState(() {
                      final total = (int.tryParse(_muestra1Controller.text) ?? 0) +
                          (int.tryParse(_muestra2Controller.text) ?? 0) +
                          (int.tryParse(_muestra3Controller.text) ?? 0);
                      _cantidadController.text = total.toString();
                    });
                  },
                  onSave: _saveMonitoreo,
                  onSavePartial: _saveMonitoreoParcial,
                  onCancel: _handleCancel,
                  onScanBarcode: _scanBarcode,
                  onCanterosRangeChanged: (value) {
                    if (!isWizardRangeLocked) {
                      onCanterosRangeChanged(value);
                    }
                  },
                  isSmallScreen: isSmallScreen,
                  isOfflineMode: !isOnline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}