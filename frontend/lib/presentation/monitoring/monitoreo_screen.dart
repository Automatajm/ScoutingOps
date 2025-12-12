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
import '../../screens/monitoreo/widgets/cantero_wizard_bar.dart';
import '../../core/routes/routes_manager.dart';
import '../../services/offline_database_service.dart';
import 'dart:convert';

class MonitoreoScreen extends StatefulWidget {
  final Function(bool)? onEditModeChanged;
  const MonitoreoScreen({Key? key, this.onEditModeChanged}) : super(key: key);
  @override
  State<MonitoreoScreen> createState() => _MonitoreoScreenState();
}

class _MonitoreoScreenState extends State<MonitoreoScreen>
    with SingleTickerProviderStateMixin {
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
  final TextEditingController _cantidadBotadaController =
      TextEditingController();
  final TextEditingController _muestra1Controller = TextEditingController();
  final TextEditingController _muestra2Controller = TextEditingController();
  final TextEditingController _muestra3Controller = TextEditingController();
  final TextEditingController _canterosRangeController =
      TextEditingController();

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

  // Navegación
  List<Monitoreo> _navigationData = [];
  int _currentNavigationIndex = -1;
  String? _partialSaveCantero;
  String? _partialSaveCasa;
  String? _partialSaveLote;
  String? _partialSaveVariedad;
  DateTime? _partialSaveDay;
  bool _isInPartialSaveMode = false;
  bool _isEditingExistingPartial = false;
  Set<String> _plagasRegistradasParcial = {};
  Set<String> _variedadesUsadasParcial = {};

  // WIZARD DE CANTEROS
  bool _isWizardActive = false;
  bool _isWizardRangeLocked = false;
  int _wizardCanteroActual = 0;
  int _wizardCanteroInicio = 0;
  int _wizardCanteroFin = 0;
  int _wizardTotalCanteros = 0;
  String _wizardFormState = 'clean';
  Map<int, List<int>> _wizardCanterosMonitoreos = {};
  int _wizardParcialIndex = 0;
  int? _lastCreatedSequence;

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

  // Sincronización
  bool _isSyncing = false;
  int _pendingChangesCount = 0;
  String _lastSyncStatus = '';
  IntranetService? _cachedIntranetService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        if (_isWizardActive || _isWizardRangeLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tabController.animateTo(1);
              _showMessage(
                  'Debe finalizar el wizard antes de cambiar de pestaña');
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
        _cachedIntranetService =
            Provider.of<IntranetService>(context, listen: false);
        _cachedIntranetService!.isConnected
            .addListener(_handleConnectivityChange);
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
    _cachedIntranetService =
        Provider.of<IntranetService>(context, listen: false);
  }

  // ===== WIZARD DE CANTEROS =====
  void _initWizard(String range) {
    final parser = CanteroRangeParser.parse(range);
    if (!parser.isValid) {
      _showMessage('Rango inválido: ${parser.error}');
      return;
    }

    // ✅ Usar el rango normalizado (formato "X-X")
    final normalizedRange = parser.normalizedRange ?? range;

    if (parser.isSingleCantero) {
      setState(() {
        _isWizardActive = false;
        _canteroController.text = parser.inicio.toString();
        // ✅ FIX: Guardar en formato "X-X" incluso para cantero único
        if (_isManualEntry) {
          _loteCanterosOriginal = normalizedRange;
        }
      });
      return;
    }

    setState(() {
      _isWizardActive = true;
      _isWizardRangeLocked = false;
      _wizardCanteroInicio = parser.inicio;
      _wizardCanteroFin = parser.fin;
      _wizardTotalCanteros = parser.total;
      _wizardCanteroActual = parser.inicio;
      _wizardFormState = 'clean';
      _wizardCanterosMonitoreos = {};
      _wizardParcialIndex = 0;
      _canteroController.text = parser.inicio.toString();
      _canterosRangeController.text = normalizedRange; // ✅ Usar normalizado

      // ✅ FIX CRÍTICO: Guardar el rango normalizado en modo manual
      if (_isManualEntry) {
        _loteCanterosOriginal = normalizedRange;
      }
    });
    _preloadExistingMonitoreos();
  }

  void _preloadExistingMonitoreos() {
    if (_codigoLoteController.text.isEmpty) return;

    final lote = _codigoLoteController.text;
    final casa = _casaController.text;
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    final monitoreosHoy = _monitoreoData.where((m) {
      if (m.pmlt_codigo != lote) return false;
      if (casa.isNotEmpty && m.pmmo_casa != casa) return false;
      if (m.pmmo_fecha == null) return false;
      final fecha = m.pmmo_fecha!;
      return fecha.isAfter(inicioHoy) && fecha.isBefore(finHoy);
    }).toList();

    if (monitoreosHoy.isEmpty) return;

    final Map<int, List<int>> canteroSecuencias = {};
    for (var m in monitoreosHoy) {
      final canteroStr = m.pmmo_cantero;
      if (canteroStr == null) continue;
      final cantero = int.tryParse(canteroStr);
      if (cantero == null) continue;

      if (cantero < _wizardCanteroInicio || cantero > _wizardCanteroFin)
        continue;

      if (!canteroSecuencias.containsKey(cantero)) {
        canteroSecuencias[cantero] = [];
      }
      if (m.pmmo_secuencia != null) {
        canteroSecuencias[cantero]!.add(m.pmmo_secuencia!);
      }
    }

    if (canteroSecuencias.isNotEmpty) {
      setState(() {
        _wizardCanterosMonitoreos = canteroSecuencias;
      });

      final secuenciasActual = _wizardCanterosMonitoreos[_wizardCanteroActual];
      if (secuenciasActual != null && secuenciasActual.isNotEmpty) {
        _loadWizardCanteroMonitoreos(_wizardCanteroActual, secuenciasActual);
      }
    }
  }

  String _getWizardFormState() {
    if (_isInPartialSaveMode && _plagasRegistradasParcial.isNotEmpty)
      return 'post_partial';
    final hasPlaga = _selectedPlaga != null && _selectedPlaga!.isNotEmpty;
    final hasMuestras = _muestra1Controller.text.isNotEmpty ||
        _muestra2Controller.text.isNotEmpty ||
        _muestra3Controller.text.isNotEmpty;
    final hasComentarios = _comentariosController.text.isNotEmpty;
    final hasCantidadBotada = _cantidadBotadaController.text.isNotEmpty &&
        _cantidadBotadaController.text != '0';
    if (hasPlaga || hasMuestras || hasComentarios || hasCantidadBotada)
      return 'dirty';
    return 'clean';
  }

  Future<void> _wizardNext() async {
    if (!_isWizardActive) return;
    final formState = _getWizardFormState();
    if (formState == 'dirty') {
      final confirmar = await _showWizardConfirmDialog(
        title: 'Datos sin guardar',
        message: '¿Desea guardar los datos antes de continuar?',
        confirmText: 'Guardar y continuar',
        cancelText: 'Descartar',
        showThirdOption: true,
        thirdOptionText: 'Cancelar',
      );
      if (confirmar == null) return;
      if (confirmar == true) await _saveMonitoreoParcial();
    }
    if (!_isWizardRangeLocked)
      setState(() {
        _isWizardRangeLocked = true;
      });
    final siguienteCantero = _wizardCanteroActual + 1;
    if (siguienteCantero <= _wizardCanteroFin) {
      _goToCantero(siguienteCantero);
    } else {
      _wizardFinish();
    }
  }

  void _wizardPrevious() {
    if (!_isWizardActive) return;
    if (_wizardCanteroActual > _wizardCanteroInicio)
      _goToCantero(_wizardCanteroActual - 1);
  }

  Future<void> _wizardSkip() async {
    if (!_isWizardActive) return;
    final formState = _getWizardFormState();
    String title = formState == 'dirty'
        ? 'Datos sin guardar'
        : formState == 'post_partial'
            ? 'Guardado parcial'
            : 'Saltar cantero';
    String message = formState == 'dirty'
        ? 'Tiene datos sin guardar. ¿Descartar y saltar?'
        : formState == 'post_partial'
            ? '¿Continuar sin agregar más plagas?'
            : '¿Saltar cantero $_wizardCanteroActual?';
    final confirmar = await _showWizardConfirmDialog(
        title: title,
        message: message,
        confirmText: 'Saltar',
        cancelText: 'Cancelar');
    if (confirmar != true) return;
    if (!_isWizardRangeLocked)
      setState(() {
        _isWizardRangeLocked = true;
      });
    final siguienteCantero = _wizardCanteroActual + 1;
    if (siguienteCantero <= _wizardCanteroFin) {
      _goToCantero(siguienteCantero);
    } else {
      _wizardFinish();
    }
  }

  void _goToCantero(int cantero) {
    if (cantero < _wizardCanteroInicio || cantero > _wizardCanteroFin) return;

    final secuencias = _wizardCanterosMonitoreos[cantero] ?? [];

    setState(() {
      _wizardCanteroActual = cantero;
      _canteroController.text = cantero.toString();
      _wizardParcialIndex = 0;

      _selectedPlaga = null;
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
      _isEditingExistingPartial = false;

      _plagasRegistradasParcial.clear();
      _variedadesUsadasParcial.clear();
    });

    if (secuencias.isNotEmpty) {
      _loadWizardCanteroMonitoreos(cantero, secuencias);
    } else {
      setState(() {
        _wizardFormState = 'clean';
        if (!_isWizardRangeLocked) {
          _isInPartialSaveMode = false;
        }
      });
    }
  }

  Future<void> _loadWizardCanteroMonitoreos(
      int cantero, List<int> secuencias) async {
    if (secuencias.isEmpty) return;

    final monitoreosCantero = _monitoreoData
        .where((m) =>
            secuencias.contains(m.pmmo_secuencia) &&
            m.pmmo_cantero == cantero.toString())
        .toList();

    if (monitoreosCantero.isEmpty) {
      await _loadData();
      return;
    }

    for (var m in monitoreosCantero) {
      if (_isManualEntry) {
        final clave =
            '${m.pmmo_cantero}|${m.pmmo_variedad}|${m.pmni_nombrecomun}';
        _plagasRegistradasParcial.add(clave);
        if (m.pmmo_variedad != null)
          _variedadesUsadasParcial.add(m.pmmo_variedad!);
      } else {
        if (m.pmni_nombrecomun != null)
          _plagasRegistradasParcial.add(m.pmni_nombrecomun!);
      }
    }

    if (monitoreosCantero.isNotEmpty) {
      final primerMonitoreo = monitoreosCantero.first;
      await _editMonitoreoForWizard(primerMonitoreo);
      setState(() {
        _wizardFormState = 'post_partial';
        _wizardParcialIndex = 0;
      });
    }
  }

  Future<void> _editMonitoreoForWizard(Monitoreo monitoreo) async {
    setState(() {
      _currentMonitoreo = monitoreo;
      _isEditingExistingPartial = true;
      _selectedPlaga = monitoreo.pmni_nombrecomun;
      _comentariosController.text = monitoreo.pmmo_comentarios ?? '';
      _cantidadController.text = monitoreo.pmmo_cantidad?.toString() ?? '0';
      _cantidadBotadaController.text =
          monitoreo.pmmo_cant_botada?.toString() ?? '';
      _muestra1Controller.text = monitoreo.pmmo_muestra1?.toString() ?? '';
      _muestra2Controller.text = monitoreo.pmmo_muestra2?.toString() ?? '';
      _muestra3Controller.text = monitoreo.pmmo_muestra3?.toString() ?? '';
      _selectedNivelMuestra1 = monitoreo.pmmo_nivmuestram1?.toString();
      _selectedNivelMuestra2 = monitoreo.pmmo_nivmuestram2?.toString();
      _selectedNivelMuestra3 = monitoreo.pmmo_nivmuestram3?.toString();
    });
  }

  void _wizardParcialPrevious() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    if (secuencias.isEmpty || _wizardParcialIndex <= 0) return;

    setState(() {
      _wizardParcialIndex--;
    });

    final secuencia = secuencias[_wizardParcialIndex];
    final monitoreo = _monitoreoData.firstWhere(
      (m) => m.pmmo_secuencia == secuencia,
      orElse: () => _monitoreoData.first,
    );
    _editMonitoreoForWizard(monitoreo);
  }

  void _wizardParcialNext() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    if (secuencias.isEmpty) return;

    if (_wizardParcialIndex < secuencias.length - 1) {
      setState(() {
        _wizardParcialIndex++;
      });
      final secuencia = secuencias[_wizardParcialIndex];
      final monitoreo = _monitoreoData.firstWhere(
        (m) => m.pmmo_secuencia == secuencia,
        orElse: () => _monitoreoData.first,
      );
      _editMonitoreoForWizard(monitoreo);
    } else {
      setState(() {
        _wizardParcialIndex = secuencias.length;
        _currentMonitoreo = null;
        _isEditingExistingPartial = false;
        _selectedPlaga = null;
        _comentariosController.clear();
        _cantidadController.text = '0';
        _cantidadBotadaController.clear();
        _muestra1Controller.clear();
        _muestra2Controller.clear();
        _muestra3Controller.clear();
        _selectedNivelMuestra1 = null;
        _selectedNivelMuestra2 = null;
        _selectedNivelMuestra3 = null;
      });
    }
  }

  bool _canWizardParcialPrevious() {
    return _wizardParcialIndex > 0;
  }

  bool _canWizardParcialNext() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    return secuencias.isNotEmpty || _wizardParcialIndex == 0;
  }

  String _getWizardParcialInfo() {
    final secuencias = _wizardCanterosMonitoreos[_wizardCanteroActual] ?? [];
    if (secuencias.isEmpty) return 'Nuevo';
    final total = secuencias.length;
    final current = _wizardParcialIndex + 1;
    if (_wizardParcialIndex >= total) return 'Nuevo (${total} existentes)';
    return 'Parcial $current de $total';
  }

  Future<void> _wizardFinish() async {
    if (!_isWizardActive) return;
    final formState = _getWizardFormState();
    if (formState == 'dirty') {
      final confirmar = await _showWizardConfirmDialog(
        title: 'Finalizar wizard',
        message: 'Tiene datos sin guardar. ¿Guardar antes de finalizar?',
        confirmText: 'Guardar y finalizar',
        cancelText: 'Descartar',
        showThirdOption: true,
        thirdOptionText: 'Cancelar',
      );
      if (confirmar == null) return;
      if (confirmar == true) await _saveMonitoreo();
    } else if (formState == 'post_partial') {
      final confirmar = await _showWizardConfirmDialog(
          title: 'Finalizar',
          message: '¿Finalizar wizard?',
          confirmText: 'Finalizar',
          cancelText: 'Continuar');
      if (confirmar != true) return;
    }
    final canterosConDatos = _wizardCanterosMonitoreos.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    setState(() {
      _isWizardActive = false;
      _isWizardRangeLocked = false;
      _wizardCanteroActual = 0;
      _wizardCanteroInicio = 0;
      _wizardCanteroFin = 0;
      _wizardTotalCanteros = 0;
      _wizardFormState = 'clean';
      _wizardCanterosMonitoreos.clear();
      _wizardParcialIndex = 0;
      _canterosRangeController.clear();
    });
    _clearForm();
    _tabController.animateTo(0);
    _showMessage(
        'Wizard finalizado. ${canterosConDatos.length} canteros con datos.');
  }

  Future<bool?> _showWizardConfirmDialog(
      {required String title,
      required String message,
      required String confirmText,
      required String cancelText,
      bool showThirdOption = false,
      String? thirdOptionText}) async {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(Icons.help_outline, color: Colors.indigo.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(title))
        ]),
        content: Text(message),
        actions: [
          if (showThirdOption && thirdOptionText != null)
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(thirdOptionText)),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              child: Text(cancelText)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600),
              child: Text(confirmText)),
        ],
      ),
    );
  }

  bool _canWizardGoNext() =>
      _isWizardActive && (_wizardCanteroActual + 1) <= _wizardCanteroFin;
  bool _canWizardGoPrevious() =>
      _isWizardActive && _wizardCanteroActual > _wizardCanteroInicio;

  void _onCanterosRangeChanged(String range) {
    if (_isWizardRangeLocked) return;
    final parser = CanteroRangeParser.parse(range);
    if (parser.isValid) {
      setState(() {
        _wizardCanteroInicio = parser.inicio;
        _wizardCanteroFin = parser.fin;
        _wizardTotalCanteros = parser.total;
        _wizardCanteroActual = parser.inicio;
        _isWizardActive = !parser.isSingleCantero;
        _canteroController.text = parser.inicio.toString();
      });
    }
  }
  // ===== FIN WIZARD =====

  // ===== NAVEGACIÓN =====
  void _prepareNavigationData() {
    if (_isInPartialSaveMode &&
        _partialSaveCasa != null &&
        _partialSaveLote != null) {
      final DateTime referenciaDay = _partialSaveDay ?? DateTime.now();
      final DateTime inicioDelDia = DateTime(
          referenciaDay.year, referenciaDay.month, referenciaDay.day, 0, 0, 0);
      final DateTime finDelDia = DateTime(referenciaDay.year,
          referenciaDay.month, referenciaDay.day, 23, 59, 59, 999);

      if (_isManualEntry && _partialSaveCantero != null) {
        _navigationData = _monitoreoData.where((m) {
          return m.pmmo_casa == _partialSaveCasa &&
              m.pmlt_codigo == _partialSaveLote &&
              m.pmmo_cantero == _partialSaveCantero &&
              m.pmmo_fecha != null &&
              !m.pmmo_fecha!.toLocal().isBefore(inicioDelDia) &&
              !m.pmmo_fecha!.toLocal().isAfter(finDelDia);
        }).toList();
      } else {
        _navigationData = _monitoreoData.where((m) {
          return m.pmmo_casa == _partialSaveCasa &&
              m.pmlt_codigo == _partialSaveLote &&
              m.pmmo_fecha != null &&
              !m.pmmo_fecha!.toLocal().isBefore(inicioDelDia) &&
              !m.pmmo_fecha!.toLocal().isAfter(finDelDia);
        }).toList();
      }
      _navigationData.sort(
          (a, b) => (a.pmmo_secuencia ?? 0).compareTo(b.pmmo_secuencia ?? 0));
      _navigationData.insert(0, _createVirtualPartialZero());
    } else {
      _navigationData = List.from(_monitoreoData);
      _navigationData.sort(
          (a, b) => (a.pmmo_secuencia ?? 0).compareTo(b.pmmo_secuencia ?? 0));
    }
  }

  Monitoreo _createVirtualPartialZero() {
    return Monitoreo(
      pmmo_secuencia: 0,
      pmmo_fecha: DateTime.now(),
      pmmo_estatus: 1,
      pmlt_codigo: _partialSaveLote ?? _codigoLoteController.text,
      pmmo_casa: _partialSaveCasa ?? _casaController.text,
      pmmo_cantero: _partialSaveCantero ?? _canteroController.text,
      pmmo_variedad: null,
      pmni_nombrecomun: null,
      pmmo_cantidad: 0,
      pmmo_automatico: !_isManualEntry,
    );
  }

  void _navigateNext() {
    if (_navigationData.isEmpty) return;
    int nextIndex = _currentNavigationIndex + 1;
    if (nextIndex >= _navigationData.length) {
      _showMessage('Último registro');
      return;
    }
    _navigateToIndex(nextIndex);
  }

  void _navigatePrevious() {
    if (_navigationData.isEmpty) return;
    int prevIndex = _currentNavigationIndex - 1;
    if (prevIndex < 0) {
      _showMessage('Primer registro');
      return;
    }
    _navigateToIndex(prevIndex);
  }

  void _navigateToIndex(int index) {
    if (index < 0 || index >= _navigationData.length) return;
    final monitoreo = _navigationData[index];
    setState(() {
      _currentNavigationIndex = index;
    });
    if (index == 0 && _isInPartialSaveMode && monitoreo.pmmo_secuencia == 0) {
      _prepareFormForNewPartial();
    } else {
      setState(() {
        _isEditingExistingPartial = true;
      });
      _editMonitoreo(monitoreo, fromNavigation: true);
    }
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

  String _getNavigationInfo() {
    if (_navigationData.isEmpty) return '';
    if (_currentNavigationIndex == 0 && _isInPartialSaveMode) {
      return _isManualEntry && _partialSaveCantero != null
          ? 'Casa $_partialSaveCasa, Cantero $_partialSaveCantero | Nuevo'
          : 'Casa $_partialSaveCasa, Lote $_partialSaveLote | Nuevo';
    }
    final current = _currentNavigationIndex + 1;
    final total = _navigationData.length;
    return _isInPartialSaveMode
        ? (_isManualEntry
            ? 'Casa $_partialSaveCasa, Cantero $_partialSaveCantero | $current de $total'
            : 'Casa $_partialSaveCasa | $current de $total')
        : 'Registro $current de $total';
  }

  bool _canNavigateNext() =>
      _navigationData.isNotEmpty &&
      _currentNavigationIndex < _navigationData.length - 1;
  bool _canNavigatePrevious() =>
      _navigationData.isNotEmpty && _currentNavigationIndex > 0;

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
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              authService.logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                  RoutesManager.login, (route) => false);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePendingChangesCount() async {
    if (!mounted) return;
    final cacheService = Provider.of<CacheService>(context, listen: false);
    final pendingChanges =
        await cacheService.loadData('pending_monitoreos') ?? [];
    setState(() {
      _pendingChangesCount = pendingChanges is List ? pendingChanges.length : 0;
    });
  }

  void _handleConnectivityChange() async {
    if (!mounted) return;
    final intranetService = _cachedIntranetService;
    if (intranetService == null) return;

    final isOnline = intranetService.isConnected.value;
    debugPrint('🌐 Conectividad cambió: ${isOnline ? "ONLINE" : "OFFLINE"}');

    if (isOnline) {
      if (_pendingChangesCount > 0 && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi, color: Colors.green),
                SizedBox(width: 8),
                Text('Conexión restablecida'),
              ],
            ),
            content: Text(
                '$_pendingChangesCount cambios pendientes. ¿Sincronizar ahora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Después'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _sincronizarCambiosPendientes();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar'),
              ),
            ],
          ),
        );
      }
      _loadCasas();
      _loadVariedades();
      _loadPlagas();
      _loadNivelesLimites();
      _loadData();
    } else {
      debugPrint('📴 Cambiando a modo OFFLINE - Cargando datos de SQLite');
      _showMessage('Sin conexión - Usando datos locales');
      await _loadDataFromLocalOnly();
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadDataFromLocalOnly() async {
    if (!mounted) return;

    try {
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);

      debugPrint('📦 Cargando datos locales de SQLite...');

      // 1. Cargar variedades desde SQLite
      final variedadesList = await offlineDbService.getVariedades();
      if (variedadesList != null && variedadesList.isNotEmpty && mounted) {
        Map<String, String> nuevoMapa = {};
        Map<String, String> nuevoMapaIds = {};
        setState(() {
          _variedades = ['Variedad genérica'];
          for (var variedad in variedadesList) {
            if (variedad is Map) {
              final estatus =
                  variedad['estatus'] ?? variedad['pmva_estatus'] ?? 1;
              if (estatus != 1) continue;
              String? descripcion = variedad['descripcion']?.toString() ??
                  variedad['pmva_descripcion']?.toString();
              String? responsable = variedad['responsable']?.toString() ??
                  variedad['pmva_responsable']?.toString();
              var id = variedad['id'] ?? variedad['pmva_id'];
              if (descripcion != null && descripcion.isNotEmpty) {
                if (!_variedades.contains(descripcion))
                  _variedades.add(descripcion);
                if (responsable != null) nuevoMapa[descripcion] = responsable;
                if (id != null) nuevoMapaIds[descripcion] = id.toString();
              }
            }
          }
          _responsablesPorVariedad = nuevoMapa;
          _variedadesIdMap = nuevoMapaIds;
        });
        debugPrint('✅ Variedades offline: ${_variedades.length}');
      }

      // 2. Cargar casas desde SQLite
      final casasList = await offlineDbService.getCasas();
      if (casasList != null && casasList.isNotEmpty && mounted) {
        setState(() {
          _casas = ['Todas'];
          for (var casa in casasList) {
            String? casaStr;
            if (casa is Map) {
              casaStr = casa['codigo']?.toString() ??
                  casa['pmun_codigo']?.toString() ??
                  casa['pmun_descripcion']?.toString();
            } else if (casa is String) {
              casaStr = casa;
            }
            if (casaStr != null &&
                casaStr.isNotEmpty &&
                !_casas.contains(casaStr)) {
              _casas.add(casaStr);
            }
          }
        });
        debugPrint('✅ Casas offline: ${_casas.length}');
      }

      // 3. Cargar plagas desde SQLite
      final plagasList = await offlineDbService.getPlagas();
      if (plagasList != null && plagasList.isNotEmpty && mounted) {
        setState(() {
          _plagas = plagasList;
        });
        debugPrint('✅ Plagas offline: ${_plagas.length}');
      }

      // 4. Cargar niveles límites desde SQLite
      final nivelesData = await offlineDbService.getNivelesLimites();
      if (nivelesData != null && mounted) {
        setState(() {
          _limiteNivel1 = nivelesData['lmsupniv1'] ?? 10;
          _limiteNivel2 = nivelesData['lmsupniv2'] ?? 20;
          _limiteNivel3 = nivelesData['lmsupniv3'] ?? 30;
        });
        debugPrint('✅ Niveles offline: OK');
      }

      // 5. Cargar monitoreos desde SQLite
      final monitoreosData = await offlineDbService.getAllMonitoreos();
      if (monitoreosData.isNotEmpty && mounted) {
        final monitoreos = monitoreosData
            .map<Monitoreo>((json) => Monitoreo.fromJson(json))
            .toList();
        setState(() {
          _monitoreoData = monitoreos;
          _currentPage = 1;
          _applyPagination();
        });
        debugPrint('✅ Monitoreos offline desde SQLite: ${monitoreos.length}');
      } else {
        final cachedData = await cacheService.loadData('monitoreos_data');
        if (cachedData != null && cachedData is List && mounted) {
          final monitoreos = cachedData
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();
          setState(() {
            _monitoreoData = monitoreos;
            _currentPage = 1;
            _applyPagination();
          });
          debugPrint(
              '✅ Monitoreos offline desde cache (fallback): ${monitoreos.length}');
        }
      }

      debugPrint('📦 Carga offline completada');
    } catch (e) {
      debugPrint('❌ Error cargando datos offline: $e');
      if (mounted) {
        _showMessage('Error cargando datos locales');
      }
    }
  }

  Future<void> _sincronizarCambiosPendientes() async {
    if (!mounted) return;
    final intranetService = _cachedIntranetService;
    if (intranetService == null || !intranetService.isConnected.value) {
      _showMessage('Sin conexión');
      return;
    }

    setState(() {
      _isSyncing = true;
      _lastSyncStatus = 'Sincronizando...';
    });
    try {
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);

      final cachedPending = await cacheService.loadData('pending_monitoreos');
      if (cachedPending == null ||
          cachedPending is! List ||
          cachedPending.isEmpty) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = 'Sin cambios pendientes';
        });
        return;
      }
      List<dynamic> pendingChanges = cachedPending;
      List<dynamic> failedChanges = [];
      List<int> syncedTempIds = [];
      int successCount = 0;

      for (final change in pendingChanges) {
        try {
          final operation = change['operation'];
          final monitoreo = Monitoreo.fromJson(change['monitoreo']);
          final tempId = monitoreo.pmmo_secuencia;

          if (operation == 'create') {
            if (monitoreo.isTemporary()) {
              await monitoreoService.crearMonitoreo(monitoreo.copyWith(
                  pmmo_secuencia: null, isOfflineCreated: false));
              if (tempId != null) syncedTempIds.add(tempId);
            } else {
              await monitoreoService.crearMonitoreo(monitoreo);
            }
            successCount++;
          } else if (operation == 'update') {
            if (monitoreo.isTemporary()) {
              await monitoreoService.crearMonitoreo(monitoreo.copyWith(
                  pmmo_secuencia: null, isOfflineCreated: false));
              if (tempId != null) syncedTempIds.add(tempId);
            } else {
              await monitoreoService.actualizarMonitoreo(monitoreo);
            }
            successCount++;
          } else if (operation == 'delete') {
            if (!monitoreo.isTemporary())
              await monitoreoService
                  .eliminarMonitoreo(monitoreo.pmmo_secuencia!);
            if (tempId != null) syncedTempIds.add(tempId);
            successCount++;
          }
        } catch (e) {
          failedChanges.add(change);
        }
      }

      for (final tempId in syncedTempIds) {
        try {
          await offlineDbService.deleteMonitoreo(tempId);
          debugPrint('🗑️ Eliminado de SQLite: $tempId (sincronizado)');
        } catch (e) {
          debugPrint('⚠️ No se pudo eliminar $tempId de SQLite: $e');
        }
      }

      await cacheService.saveData('pending_monitoreos', failedChanges);
      await _updatePendingChangesCount();
      await _loadData();

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = failedChanges.isEmpty
              ? 'Sincronización completa'
              : 'Sincronización parcial';
        });
        _showMessage(failedChanges.isEmpty
            ? 'Sincronizado correctamente'
            : 'Sincronización parcial');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncStatus = 'Error: $e';
        });
        _showMessage('Error en sincronización');
      }
    }
  }

  void _handleSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      final columnDef = _columns.firstWhere((col) => col['title'] == column,
          orElse: () => {});
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
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
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
      setState(() {
        _isLoading = true;
      });
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final dataToExport =
          onlyFiltered ? _filteredMonitoreoData : _monitoreoData;
      final success = await monitoreoService.exportarMonitoreosExcel(
          dataToExport, fileName, _columns);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessage(success ? 'Exportado correctamente' : 'Error al exportar');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    if (_currentPage > _totalPages && _totalPages > 0)
      _currentPage = _totalPages;
    if (_sortColumn != null) {
      final columnDef = _columns
          .firstWhere((col) => col['title'] == _sortColumn, orElse: () => {});
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
          return _sortAscending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        });
      }
    }
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > _totalItems) endIndex = _totalItems;
    if (_monitoreoData.isNotEmpty && startIndex < _monitoreoData.length) {
      _filteredMonitoreoData = _monitoreoData.sublist(startIndex,
          endIndex < _monitoreoData.length ? endIndex : _monitoreoData.length);
    } else {
      _filteredMonitoreoData = [];
    }
  }

  void _handleItemsPerPageChange(int newItemsPerPage) {
    if (mounted)
      setState(() {
        _itemsPerPage = newItemsPerPage;
        _currentPage = 1;
        _applyPagination();
      });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(message), duration: const Duration(seconds: 2)));
        } catch (e) {
          debugPrint('Error: $e');
        }
      }
    });
  }

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
      _loadNivelesLimites();
    }
  }

  String _getDefaultLoteCode() => "15207";

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
    resultado.sort((a, b) => a == 'Todos'
        ? -1
        : b == 'Todos'
            ? 1
            : a.compareTo(b));
    return resultado;
  }

  // ===== MÉTODOS DE CARGA =====
  Future<void> _loadVariedades() async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<dynamic>? variedadesList;

      variedadesList = await offlineDbService.getVariedades();
      debugPrint('📦 Variedades en SQLite: ${variedadesList?.length ?? 0}');

      if ((variedadesList == null || variedadesList.isEmpty) &&
          intranetService.isConnected.value) {
        debugPrint('🌐 SQLite vacío, descargando variedades de API...');
        try {
          final variedadesData =
              await monitoreoService.getDatosAuxiliares('variedades');
          if (variedadesData['data'] != null &&
              variedadesData['data'] is List) {
            variedadesList = variedadesData['data'];
            await offlineDbService.saveVariedades(variedadesList!);
            debugPrint(
                '💾 Variedades guardadas en SQLite: ${variedadesList.length}');
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
              final estatus =
                  variedad['estatus'] ?? variedad['pmva_estatus'] ?? 1;
              if (estatus != 1) continue;
              String? descripcion = variedad['descripcion']?.toString() ??
                  variedad['pmva_descripcion']?.toString();
              String? responsable = variedad['responsable']?.toString() ??
                  variedad['pmva_responsable']?.toString();
              var id = variedad['id'] ?? variedad['pmva_id'];
              if (descripcion != null && descripcion.isNotEmpty) {
                if (!_variedades.contains(descripcion))
                  _variedades.add(descripcion);
                if (responsable != null) nuevoMapa[descripcion] = responsable;
                if (id != null) nuevoMapaIds[descripcion] = id.toString();
              }
            }
          }
          _responsablesPorVariedad = nuevoMapa;
          _variedadesIdMap = nuevoMapaIds;
        });
        debugPrint('✅ Variedades procesadas: ${_variedades.length}');
      } else {
        if (mounted)
          setState(() {
            _variedades = ['Variedad genérica'];
          });
        debugPrint('⚠️ Sin variedades disponibles');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadVariedades: $e');
      if (mounted)
        setState(() {
          _variedades = ['Variedad genérica'];
        });
    }
  }

  String _obtenerIdVariedad(String? descripcionVariedad) {
    if (descripcionVariedad == null) return '';
    if (descripcionVariedad == 'Variedad genérica') return '0';
    return _variedadesIdMap[descripcionVariedad] ?? '';
  }

  Future<void> _loadCasas() async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      List<dynamic>? casasList;

      casasList = await offlineDbService.getCasas();
      debugPrint('📦 Casas en SQLite: ${casasList?.length ?? 0}');

      if ((casasList == null || casasList.isEmpty) &&
          intranetService.isConnected.value) {
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
              codigo = casa['codigo']?.toString() ??
                  casa['pmun_codigo']?.toString() ??
                  casa['pmun_descripcion']?.toString();
            } else if (casa is String) {
              codigo = casa;
            }
            if (codigo != null && codigo.isNotEmpty && !_casas.contains(codigo))
              _casas.add(codigo);
          }
        });
        debugPrint('✅ Casas procesadas: ${_casas.length}');
      } else {
        if (mounted)
          setState(() {
            _casas = ['Casa genérica'];
          });
        debugPrint('⚠️ Sin casas disponibles');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadCasas: $e');
      if (mounted)
        setState(() {
          _casas = ['Casa genérica'];
        });
    }
  }

  Future<void> _loadPlagas() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
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
            debugPrint(
                '💾 Plagas guardadas en SQLite: ${plagasNombres.length}');
          }
        } catch (e) {
          debugPrint('⚠️ Error descargando plagas de API: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _plagas =
              plagasNombres.isNotEmpty ? plagasNombres : ['Plaga genérica'];
        });
        debugPrint('✅ Plagas procesadas: ${_plagas.length}');
      }
    } catch (e) {
      debugPrint('❌ Error en _loadPlagas: $e');
      if (mounted)
        setState(() {
          _isLoading = false;
          _plagas = ['Plaga genérica'];
        });
    }
  }

  Future<void> _loadNivelesLimites() async {
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
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
        debugPrint(
            '✅ Niveles procesados: $_limiteNivel1/$_limiteNivel2/$_limiteNivel3');
      } else {
        if (mounted)
          setState(() {
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
      if (WidgetsBinding.instance.schedulerPhase !=
          SchedulerPhase.persistentCallbacks) {
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
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      List<Monitoreo> monitoreos = [];

      if (intranetService.isConnected.value) {
        try {
          monitoreos = await monitoreoService.getMonitoreos();

          for (final m in monitoreos) {
            await offlineDbService.saveMonitoreoFromMap(m.toJson(),
                isLocal: false);
          }
          debugPrint('💾 ${monitoreos.length} monitoreos guardados en SQLite');

          await cacheService.saveData(
              'monitoreos_data', monitoreos.map((m) => m.toJson()).toList());
          await cacheService.saveData(
              'last_online_sync', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint('⚠️ Error cargando de API, intentando SQLite: $e');
          final sqliteData = await offlineDbService.getAllMonitoreos();
          if (sqliteData.isNotEmpty) {
            monitoreos = sqliteData
                .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                .toList();
            debugPrint(
                '📦 ${monitoreos.length} monitoreos cargados desde SQLite (fallback)');
          } else {
            final cachedData = await cacheService.loadData('monitoreos_data');
            if (cachedData != null && cachedData is List) {
              monitoreos = cachedData
                  .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                  .toList();
              debugPrint(
                  '📦 ${monitoreos.length} monitoreos cargados desde cache (fallback)');
            }
          }
        }
      } else {
        debugPrint('📴 Modo OFFLINE - Cargando desde SQLite...');
        final sqliteData = await offlineDbService.getAllMonitoreos();
        if (sqliteData.isNotEmpty) {
          monitoreos = sqliteData
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();
          debugPrint(
              '📦 ${monitoreos.length} monitoreos cargados desde SQLite');
        } else {
          final cachedData = await cacheService.loadData('monitoreos_data');
          if (cachedData != null && cachedData is List) {
            monitoreos = cachedData
                .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                .toList();
            debugPrint(
                '📦 ${monitoreos.length} monitoreos cargados desde cache (fallback)');
          }
        }
        _showMessage('Modo offline - ${monitoreos.length} registros locales');
      }

      if (authService.mustFilterByUser &&
          authService.getCurrentUserId() != null) {
        final userId = authService.getCurrentUserId();
        monitoreos =
            monitoreos.where((m) => m.pmmo_creadopor == userId).toList();
      }
      if (mounted)
        setState(() {
          _monitoreoData = monitoreos;
          _currentPage = 1;
          _applyPagination();
          _isLoading = false;
        });
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

  Future<void> _searchMonitoreos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      int? estatus;
      if (_selectedEstado == 'Activo')
        estatus = 1;
      else if (_selectedEstado == 'Inactivo') estatus = 0;
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;
      List<Monitoreo> monitoreos = [];
      DateTime? fechaInicioParaAPI = _fechaInicio != null
          ? DateTime(_fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day,
              0, 0, 0, 0)
          : null;
      DateTime? fechaFinParaAPI = _fechaFin != null
          ? DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day, 23, 59,
              59, 999)
          : null;
      if (intranetService.isConnected.value) {
        monitoreos = await monitoreoService.getMonitoreos(
          lote:
              _searchController.text.isNotEmpty ? _searchController.text : null,
          plaga: _selectedPlaga,
          casa: _selectedCasaFiltro,
          cantero: _selectedCanteroFiltro,
          variedad: _selectedVariedadFiltro,
          estatus: estatus,
          fechaInicio: fechaInicioParaAPI,
          fechaFin: fechaFinParaAPI,
        );
      } else {
        final offlineDbService =
            Provider.of<OfflineDatabaseService>(context, listen: false);
        final sqliteData = await offlineDbService.getAllMonitoreos();
        if (sqliteData.isNotEmpty) {
          monitoreos = sqliteData
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();
          debugPrint('📦 Búsqueda offline: ${monitoreos.length} desde SQLite');
        } else {
          final cachedData = await cacheService.loadData('monitoreos_data');
          if (cachedData != null && cachedData is List) {
            monitoreos = cachedData
                .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                .toList();
            debugPrint(
                '📦 Búsqueda offline: ${monitoreos.length} desde cache (fallback)');
          }
        }
        monitoreos = monitoreos.where((m) {
          bool match = true;
          if (_searchController.text.isNotEmpty)
            match = match &&
                (m.pmlt_codigo
                        ?.toLowerCase()
                        .contains(_searchController.text.toLowerCase()) ??
                    false);
          if (_selectedPlaga != null && _selectedPlaga!.isNotEmpty)
            match = match && (m.pmni_nombrecomun == _selectedPlaga);
          if (_selectedCasaFiltro != null &&
              _selectedCasaFiltro!.isNotEmpty &&
              _selectedCasaFiltro != 'Todas')
            match = match && (m.pmmo_casa == _selectedCasaFiltro);
          if (_selectedCanteroFiltro != null &&
              _selectedCanteroFiltro!.isNotEmpty &&
              _selectedCanteroFiltro != 'Todos')
            match = match && (m.pmmo_cantero == _selectedCanteroFiltro);
          if (_selectedVariedadFiltro != null &&
              _selectedVariedadFiltro!.isNotEmpty &&
              _selectedVariedadFiltro != 'Todas')
            match = match &&
                ((m.pmmo_variedad == _selectedVariedadFiltro) ||
                    (m.pmva_descripcion == _selectedVariedadFiltro));
          if (estatus != null) match = match && (m.pmmo_estatus == estatus);
          if (_fechaInicio != null && m.pmmo_fecha != null) {
            final fechaMonitoreo = DateTime(
                m.pmmo_fecha!.year, m.pmmo_fecha!.month, m.pmmo_fecha!.day);
            final fechaInicioLocal = DateTime(
                _fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day);
            match = match && !fechaMonitoreo.isBefore(fechaInicioLocal);
          }
          if (_fechaFin != null && m.pmmo_fecha != null) {
            final fechaMonitoreo = DateTime(
                m.pmmo_fecha!.year, m.pmmo_fecha!.month, m.pmmo_fecha!.day);
            final fechaFinLocal =
                DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day);
            match = match && !fechaMonitoreo.isAfter(fechaFinLocal);
          }
          return match;
        }).toList();
      }
      if (mounted)
        setState(() {
          _monitoreoData = monitoreos;
          _currentPage = 1;
          _applyPagination();
          _isLoading = false;
        });
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

  @override
  void dispose() {
    if (_cachedIntranetService != null)
      _cachedIntranetService!.isConnected
          .removeListener(_handleConnectivityChange);
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
          _loteCanterosOriginal = null;
          if (!_isEditing) _loteContenedorOriginal = null;
          _selectedNivelMuestra1 = null;
          _selectedNivelMuestra2 = null;
          _selectedNivelMuestra3 = null;
          _cantidadController.text = '0';
          _navigationData.clear();
          _currentNavigationIndex = -1;
          _partialSaveCantero = null;
          _partialSaveCasa = null;
          _partialSaveLote = null;
          _partialSaveDay = null;
          _isInPartialSaveMode = false;
          _plagasRegistradasParcial.clear();
          _variedadesUsadasParcial.clear();
          _isWizardActive = false;
          _isWizardRangeLocked = false;
          _wizardCanteroActual = 0;
          _wizardCanteroInicio = 0;
          _wizardCanteroFin = 0;
          _wizardTotalCanteros = 0;
          _wizardFormState = 'clean';
          _wizardCanterosMonitoreos.clear();
          _wizardParcialIndex = 0;
          _canterosRangeController.clear();
        });
        if (mounted &&
            WidgetsBinding.instance.schedulerPhase !=
                SchedulerPhase.persistentCallbacks) _updateEditMode(false);
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  void _clearMonitoreoData() {
    if (!mounted) return;
    _comentariosController.clear();
    _cantidadController.clear();
    _cantidadBotadaController.clear();
    if (!_isInPartialSaveMode) {
      _muestra1Controller.clear();
      _muestra2Controller.clear();
      _muestra3Controller.clear();
    }
  }

  void _nuevoMonitoreo() {
    if (_isWizardActive || _isWizardRangeLocked) {
      _showMessage(
          'Debe finalizar el wizard antes de crear un nuevo monitoreo');
      return;
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      FriendlyErrorDialog.show(context,
          title: 'Sesión expirada',
          message: 'Por favor inicie sesión.',
          actionText: 'Login', onAction: () {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(RoutesManager.login, (route) => false);
      }, icon: Icons.logout, iconColor: Colors.red);
      return;
    }
    final userId = authService.getCurrentUserId();
    if (userId == null || userId == 1) {
      FriendlyErrorDialog.show(context,
          title: 'Usuario no válido',
          message: 'Inicie sesión nuevamente.',
          actionText: 'Login', onAction: () {
        authService.logout();
        Navigator.of(context)
            .pushNamedAndRemoveUntil(RoutesManager.login, (route) => false);
      }, icon: Icons.person_off, iconColor: Colors.orange);
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

  Future<void> _scanBarcode() async {
    if (_codigoLoteController.text.isNotEmpty) {
      final String existingCode = _codigoLoteController.text.trim();
      if (mounted) {
        setState(() {
          _isManualEntry = false;
          _errorMessage = '';
          _isLoading = true;
        });
        await _loadLoteData(existingCode);
      }
      return;
    }
    final String? scannedCode = await BarcodeScanner.scanBarcode(context);
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      setState(() {
        _codigoLoteController.text = scannedCode;
        _isManualEntry = false;
        _errorMessage = '';
        _isLoading = true;
      });
      await _loadLoteData(scannedCode);
    }
  }

  // PASO 2: REEMPLAZAR el método _loadLoteData COMPLETO con este:

  Future<void> _loadLoteData(String codigoLote) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final offlineDbService =
          Provider.of<OfflineDatabaseService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) return;

      dynamic loteInfo;

      // 1. PRIMERO: Buscar en lote_info (lotes consultados previamente)
      loteInfo = await offlineDbService.getLoteInfo(codigoLote);
      if (loteInfo != null) {
        final estatus = loteInfo['estatus'] ?? loteInfo['pmlt_estatus'] ?? 1;
        if (estatus != 1) {
          debugPrint(
              '⚠️ Lote $codigoLote encontrado en lote_info pero inactivo');
          loteInfo = null;
        } else {
          debugPrint('📦 Lote $codigoLote encontrado en lote_info (SQLite)');
        }
      }

      // 2. SEGUNDO: Si no está en lote_info, buscar en catálogo general de lotes
      if (loteInfo == null) {
        debugPrint('🔍 Buscando lote $codigoLote en catálogo general...');
        loteInfo = await _buscarLoteEnCatalogo(codigoLote, offlineDbService);
        if (loteInfo != null) {
          debugPrint(
              '📦 Lote $codigoLote encontrado en catálogo lotes (SQLite)');
        }
      }

      // 3. TERCERO: Si no está en SQLite Y estamos ONLINE, consultar API
      if (loteInfo == null && intranetService.isConnected.value) {
        debugPrint('🌐 Consultando lote $codigoLote desde API...');
        try {
          loteInfo = await monitoreoService.getLoteInfo(codigoLote);
          if (loteInfo != null) {
            final estatus =
                loteInfo['estatus'] ?? loteInfo['pmlt_estatus'] ?? 1;
            if (estatus != 1) {
              _showMessage('Lote $codigoLote no activo.');
              loteInfo = null;
            } else {
              // Guardar en SQLite para uso futuro offline
              await offlineDbService.saveLoteInfo(
                  codigoLote, Map<String, dynamic>.from(loteInfo));
              debugPrint(
                  '💾 Lote $codigoLote guardado en lote_info para offline');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error consultando API: $e');
        }
      }

      // 4. Si estamos OFFLINE y no encontramos el lote, mostrar mensaje apropiado
      if (loteInfo == null && !intranetService.isConnected.value) {
        debugPrint('📴 Lote $codigoLote no encontrado en datos offline');
        _showMessage('Lote $codigoLote no disponible offline');
        // Usar valores por defecto para permitir registro manual
        loteInfo = {
          'pmlt_codigo': codigoLote,
          'pmlt_contenedor': 'CONT_GENERAL',
          'pmlt_variedad': null,
          'pmva_descripcion': null,
          'pmlt_idvariedad': null,
          'pmlt_casa': null,
          'pmlt_cantero': '',
          'pmlt_canteros': '',
          'pmva_responsable': '',
          'pmlt_grower': ''
        };
      }

      // 5. Si después de todo no hay loteInfo (online pero no encontrado)
      if (loteInfo == null) {
        _showMessage('Lote no encontrado.');
        loteInfo = {
          'pmlt_contenedor': 'CONT_GENERAL',
          'pmlt_variedad': 'Variedad genérica',
          'pmva_descripcion': null,
          'pmlt_idvariedad': '0',
          'pmlt_casa': 'Casa genérica',
          'pmlt_cantero': '',
          'pmlt_canteros': '',
          'pmva_responsable': '',
          'pmlt_grower': ''
        };
      }

      // 6. Enriquecer datos de variedad si es necesario
      final idVariedad = loteInfo['pmlt_idvariedad'] ?? loteInfo['pmva_id'];
      final tieneVariedad = (loteInfo['pmlt_variedad'] != null &&
              loteInfo['pmlt_variedad'].toString().isNotEmpty) ||
          (loteInfo['pmva_descripcion'] != null &&
              loteInfo['pmva_descripcion'].toString().isNotEmpty);

      if (idVariedad != null && !tieneVariedad) {
        final variedadesData = await offlineDbService.getVariedades();
        if (variedadesData != null) {
          final variedad = variedadesData.firstWhere((v) {
            final idMatch = (v['id']?.toString() == idVariedad.toString()) ||
                (v['pmva_id']?.toString() == idVariedad.toString());
            if (!idMatch) return false;
            final estatus = v['estatus'] ?? v['pmva_estatus'] ?? 1;
            return estatus == 1;
          }, orElse: () => null);
          if (variedad != null) {
            loteInfo['pmlt_variedad'] =
                variedad['descripcion'] ?? variedad['pmva_descripcion'];
            loteInfo['pmva_responsable'] =
                variedad['responsable'] ?? variedad['pmva_responsable'];
            debugPrint(
                '📦 Variedad enriquecida desde catálogo: ${loteInfo['pmlt_variedad']}');
          }
        }
      }

      // 7. Procesar y aplicar datos al formulario
      String? variedadDescripcion = loteInfo['pmlt_variedad']?.toString() ??
          loteInfo['pmva_descripcion']?.toString();
      String? casaLote = loteInfo['pmlt_casa']?.toString();
      String? canteroLote = loteInfo['pmlt_cantero']?.toString();
      String? canterosLote = loteInfo['pmlt_canteros']?.toString();
      String? responsableLote = loteInfo['pmva_responsable']?.toString() ??
          loteInfo['pmlt_grower']?.toString();
      String? idVariedadStr = loteInfo['pmlt_idvariedad']?.toString();
      String? contenedorLote = loteInfo['pmlt_contenedor']?.toString();

      if (contenedorLote == null || contenedorLote.isEmpty)
        contenedorLote = 'CONT_GENERAL';

      List<String> variedadesActualizadas = List.from(_variedades);
      List<String> casasActualizadas = List.from(_casas);
      Map<String, String> variedadesIdMapActualizado =
          Map.from(_variedadesIdMap);
      Map<String, String> responsablesActualizado =
          Map.from(_responsablesPorVariedad);

      if (variedadDescripcion != null && variedadDescripcion.isNotEmpty) {
        if (!variedadesActualizadas.contains(variedadDescripcion))
          variedadesActualizadas.insert(1, variedadDescripcion);
        if (idVariedadStr != null)
          variedadesIdMapActualizado[variedadDescripcion] = idVariedadStr;
        if (responsableLote != null && responsableLote.isNotEmpty)
          responsablesActualizado[variedadDescripcion] = responsableLote;
      }

      if (casaLote != null &&
          casaLote.isNotEmpty &&
          !casasActualizadas.contains(casaLote))
        casasActualizadas.insert(1, casaLote);

      if (mounted) {
        setState(() {
          _variedades = variedadesActualizadas;
          _casas = casasActualizadas;
          _variedadesIdMap = variedadesIdMapActualizado;
          _responsablesPorVariedad = responsablesActualizado;
          _selectedVariedad = variedadDescripcion;
          _selectedCasa = casaLote;
          _casaController.text = casaLote ?? '';
          _canteroController.text = canteroLote ?? '';
          _responsableController.text = responsableLote ?? '';
          _cantidadController.text = '0';
          _loteCanterosOriginal = canterosLote;
          _loteContenedorOriginal = contenedorLote;
          _isLoading = false;
        });

        if (canterosLote != null && canterosLote.isNotEmpty) {
          _canterosRangeController.text = canterosLote;
          _initWizard(canterosLote);
        }
      }
    } catch (e) {
      debugPrint('❌ Error en _loadLoteData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
        _showMessage('Error cargando lote');
        _casaController.text = '';
        _selectedCasa = null;
        _canteroController.text = '';
        _selectedVariedad = null;
        _responsableController.text = '';
        _cantidadController.text = '0';
        _loteContenedorOriginal = 'CONT_GENERAL';
      }
    }
  }

// PASO 3: AGREGAR este nuevo método justo después de _loadLoteData:

  /// Busca un lote en el catálogo general de lotes (SQLite)
  /// Este método permite encontrar lotes offline que fueron sincronizados
  /// pero nunca consultados individualmente desde la API
  Future<Map<String, dynamic>?> _buscarLoteEnCatalogo(
      String codigoLote, OfflineDatabaseService offlineDbService) async {
    try {
      // Obtener el catálogo de lotes desde SQLite
      // getCatalogo ya retorna los datos decodificados (List o Map)
      final lotesData = await offlineDbService.getCatalogo('lotes');

      if (lotesData == null) {
        debugPrint('⚠️ Catálogo de lotes no disponible en SQLite');
        return null;
      }

      // lotesData ya viene decodificado por getCatalogo
      List<dynamic> lotesList;
      if (lotesData is List) {
        lotesList = lotesData;
      } else if (lotesData is String) {
        // Por si acaso viene como String (no debería)
        try {
          lotesList = json.decode(lotesData) as List<dynamic>;
        } catch (e) {
          debugPrint('⚠️ Error decodificando catálogo de lotes: $e');
          return null;
        }
      } else {
        debugPrint(
            '⚠️ Formato inesperado de catálogo de lotes: ${lotesData.runtimeType}');
        return null;
      }

      debugPrint(
          '🔍 Buscando lote $codigoLote en ${lotesList.length} lotes...');

      // Buscar el lote por código
      for (var lote in lotesList) {
        if (lote is! Map) continue;

        final loteCodigo = lote['pmlt_codigo']?.toString();
        if (loteCodigo == codigoLote) {
          // Verificar que esté activo
          final estatus = lote['pmlt_estatus'] ?? lote['estatus'] ?? 1;
          if (estatus != 1) {
            debugPrint('⚠️ Lote $codigoLote encontrado pero inactivo');
            return null;
          }

          debugPrint('✅ Lote $codigoLote encontrado en catálogo');

          // Retornar el lote con el formato esperado por el resto del código
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

      debugPrint(
          '⚠️ Lote $codigoLote no encontrado en catálogo de ${lotesList.length} lotes');
      return null;
    } catch (e) {
      debugPrint('❌ Error buscando lote en catálogo: $e');
      return null;
    }
  }

  void _toggleEntryMode() {
    if (!mounted) return;
    if (_isWizardRangeLocked || _isInPartialSaveMode) {
      _showMessage('No puede cambiar modo durante iteración');
      return;
    }
    setState(() {
      _isManualEntry = !_isManualEntry;
      _codigoLoteController.clear();
      _casaController.clear();
      _canteroController.clear();
      _selectedVariedad = null;
      _selectedCasa = null;
      _responsableController.clear();
      _loteContenedorOriginal = 'CONT_GENERAL';
      _canterosRangeController.clear();
      _isWizardActive = false;
      _cantidadController.text = '0';
      _updateEditMode(true);
    });
  }

  void _updateResponsable(String? variedad) {
    if (variedad == null) return;
    if (variedad == 'Variedad genérica') {
      _responsableController.clear();
    } else if (_responsablesPorVariedad.containsKey(variedad)) {
      setState(() {
        _responsableController.text = _responsablesPorVariedad[variedad] ?? '';
      });
    } else {
      _responsableController.text = '';
    }
  }

  int _calcularCantidadTotal() {
    int muestra1 = int.tryParse(_muestra1Controller.text) ?? 0;
    int muestra2 = int.tryParse(_muestra2Controller.text) ?? 0;
    int muestra3 = int.tryParse(_muestra3Controller.text) ?? 0;
    return muestra1 + muestra2 + muestra3;
  }

  void _actualizarCantidadObservada() {
    if (mounted)
      setState(() {
        _cantidadController.text = _calcularCantidadTotal().toString();
      });
  }

  void _resetFechasFiltro() {
    if (mounted)
      setState(() {
        _fechaInicio = null;
        _fechaFin = null;
        _fechaInicioController.clear();
        _fechaFinController.clear();
        _selectedCasaFiltro = null;
        _selectedCanteroFiltro = null;
        _selectedVariedadFiltro = null;
      });
  }

  // ===== GUARDADO =====
  Future<void> _saveMonitoreoParcial() async {
    if (_isEditingExistingPartial && _currentMonitoreo != null) {
      setState(() {
        _isPartialSave = true;
      });
      await _saveMonitoreo();
      setState(() {
        _isPartialSave = false;
      });
      await _loadData();
      _prepareNavigationData();
      _showMessage('Parcial actualizado');
      return;
    }
    if (_isManualEntry) {
      if (_isInPartialSaveMode) {
        // ✅ Validar cambio de casa
        if (_casaController.text != _partialSaveCasa) {
          FriendlyErrorDialog.show(context,
              title: 'No puede cambiar de casa',
              message: 'Haga guardado final primero.',
              icon: Icons.lock,
              iconColor: Colors.red,
              actionText: 'Ok');
          return;
        }

        // ✅ FIX: Solo validar cantero si NO está en wizard
        // En wizard, se espera que el cantero cambie entre iteraciones
        if (!_isWizardActive && !_isWizardRangeLocked) {
          if (_canteroController.text != _partialSaveCantero) {
            FriendlyErrorDialog.show(context,
                title: 'No puede cambiar de cantero',
                message: 'Haga guardado final primero.',
                icon: Icons.lock,
                iconColor: Colors.red,
                actionText: 'Ok');
            return;
          }
        }
      }
      final clave =
          '${_canteroController.text}|$_selectedVariedad|$_selectedPlaga';
      if (_selectedPlaga != null &&
          _selectedVariedad != null &&
          _plagasRegistradasParcial.contains(clave)) {
        FriendlyErrorDialog.show(context,
            title: 'Plaga ya registrada',
            message: 'Cambie variedad o plaga.',
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange,
            actionText: 'Ok');
        return;
      }
    } else {
      if (_selectedPlaga != null &&
          _plagasRegistradasParcial.contains(_selectedPlaga!)) {
        FriendlyErrorDialog.show(context,
            title: 'Plaga ya registrada',
            message: 'Seleccione otra plaga.',
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange,
            actionText: 'Ok');
        return;
      }
    }
    setState(() {
      _isPartialSave = true;
      _isInPartialSaveMode = true;
      _partialSaveCasa = _casaController.text;
      if (_codigoLoteController.text.trim().isEmpty)
        _codigoLoteController.text = _getDefaultLoteCode();
      _partialSaveLote = _codigoLoteController.text;
      if (_partialSaveDay == null) _partialSaveDay = DateTime.now();
      if (_isManualEntry)
        _partialSaveCantero = _canteroController.text;
      else
        _partialSaveCantero = null;
    });
    await _saveMonitoreo();
    if (!_isSubmitting && _errorMessage.isEmpty) {
      if (_isManualEntry) {
        final clave =
            '${_canteroController.text}|$_selectedVariedad|$_selectedPlaga';
        setState(() {
          _plagasRegistradasParcial.add(clave);
          if (_selectedVariedad != null)
            _variedadesUsadasParcial.add(_selectedVariedad!);
        });
      } else {
        if (_selectedPlaga != null)
          setState(() {
            _plagasRegistradasParcial.add(_selectedPlaga!);
          });
      }
      _clearMonitoreoData();
      _prepareNavigationData();
      if (_navigationData.isNotEmpty) {
        final currentIndex = _navigationData.indexWhere(
            (m) => m.pmmo_secuencia == _currentMonitoreo?.pmmo_secuencia);
        if (currentIndex >= 0)
          setState(() {
            _currentNavigationIndex = currentIndex;
          });
      }
      if (_isWizardActive && _lastCreatedSequence != null) {
        setState(() {
          if (!_wizardCanterosMonitoreos.containsKey(_wizardCanteroActual)) {
            _wizardCanterosMonitoreos[_wizardCanteroActual] = [];
          }
          if (!_wizardCanterosMonitoreos[_wizardCanteroActual]!
              .contains(_lastCreatedSequence)) {
            _wizardCanterosMonitoreos[_wizardCanteroActual]!
                .add(_lastCreatedSequence!);
          }
          _wizardFormState = 'post_partial';
        });
      }
      _showMessage('Guardado parcial ${_plagasRegistradasParcial.length}');
    }
    setState(() {
      _isPartialSave = false;
    });
  }

  Future<void> _saveMonitoreo() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = '';
    });
    if (_isManualEntry && _codigoLoteController.text.trim().isEmpty)
      _codigoLoteController.text = _getDefaultLoteCode();
    if (_isManualEntry) {
      if (_canteroController.text.trim().isEmpty) {
        FriendlyErrorDialog.show(context,
            title: 'Campo requerido',
            message: 'Ingrese cantero.',
            icon: Icons.edit_note,
            iconColor: Colors.blue);
        return;
      }
      if (_casaController.text.trim().isEmpty || _selectedCasa == null) {
        FriendlyErrorDialog.show(context,
            title: 'Campo requerido',
            message: 'Seleccione casa.',
            icon: Icons.home_outlined,
            iconColor: Colors.blue);
        return;
      }
      if (_selectedVariedad == null || _selectedVariedad!.isEmpty) {
        FriendlyErrorDialog.show(context,
            title: 'Campo requerido',
            message: 'Seleccione variedad.',
            icon: Icons.grass,
            iconColor: Colors.blue);
        return;
      }
    }
    if (_selectedPlaga == null ||
        _selectedPlaga!.isEmpty ||
        _selectedPlaga == 'Plaga genérica') {
      FriendlyErrorDialog.show(context,
          title: 'Seleccione plaga',
          message: 'Debe seleccionar una plaga.',
          icon: Icons.bug_report,
          iconColor: Colors.red);
      return;
    }
    if (_loteContenedorOriginal == null || _loteContenedorOriginal!.isEmpty)
      _loteContenedorOriginal = 'CONT_GENERAL';
    _actualizarCantidadObservada();
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    try {
      final limiteNivel1 = _limiteNivel1 ?? 10;
      final limiteNivel2 = _limiteNivel2 ?? 20;
      final limiteNivel3 = _limiteNivel3 ?? 30;
      final monitoreoService =
          Provider.of<MonitoreoService>(context, listen: false);
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Servicio no disponible';
        });
        return;
      }
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.getCurrentUserId();
      final muestra1 = int.tryParse(_muestra1Controller.text) ?? 0;
      final muestra2 = int.tryParse(_muestra2Controller.text) ?? 0;
      final muestra3 = int.tryParse(_muestra3Controller.text) ?? 0;
      final nivelAuto1 = NivelCalculator.calcularNivelAutomatico(
          muestra1, limiteNivel1, limiteNivel2);
      final nivelAuto2 = NivelCalculator.calcularNivelAutomatico(
          muestra2, limiteNivel1, limiteNivel2);
      final nivelAuto3 = NivelCalculator.calcularNivelAutomatico(
          muestra3, limiteNivel1, limiteNivel2);
      final nivelManual1 = _muestra1Controller.text.trim().isEmpty
          ? null
          : (int.tryParse(_selectedNivelMuestra1 ?? '') ?? 0);
      final nivelManual2 = _muestra2Controller.text.trim().isEmpty
          ? null
          : (int.tryParse(_selectedNivelMuestra2 ?? '') ?? 0);
      final nivelManual3 = _muestra3Controller.text.trim().isEmpty
          ? null
          : (int.tryParse(_selectedNivelMuestra3 ?? '') ?? 0);
      int cantidadObservada = int.tryParse(_cantidadController.text) ?? 0;
      int cantidadBotada = int.tryParse(_cantidadBotadaController.text) ?? 0;
      String idVariedad = _obtenerIdVariedad(_selectedVariedad);
      final bool creatingOffline = !intranetService.isConnected.value;
      final DateTime now = DateTime.now();
      Monitoreo monitoreo;
      String operacion;
      if (_isEditing && !_isCreatingNew && _currentMonitoreo != null) {
        operacion = 'update';
        monitoreo = _currentMonitoreo!.copyWith(
          pmlt_codigo: _codigoLoteController.text.trim(),
          pmmo_casa: _casaController.text.trim(),
          pmmo_cantero: _canteroController.text.trim(),
          pmmo_canteros: _currentMonitoreo!.pmmo_canteros,
          pmmo_contenedor: _loteContenedorOriginal,
          pmmo_variedad: _selectedVariedad,
          pmmo_idvariedad: idVariedad,
          pmmo_grower: _responsableController.text.trim(),
          pmni_nombrecomun: _selectedPlaga,
          pmmo_cantidad: cantidadObservada,
          pmmo_cant_botada: cantidadBotada,
          pmmo_comentarios: _comentariosController.text.trim(),
          pmmo_automatico: !_isManualEntry,
          pmmo_muestra1: muestra1,
          pmmo_muestra2: muestra2,
          pmmo_muestra3: muestra3,
          pmmo_nivmuestraa1: nivelAuto1,
          pmmo_nivmuestraa2: nivelAuto2,
          pmmo_nivmuestraa3: nivelAuto3,
          pmmo_nivmuestram1: nivelManual1,
          pmmo_nivmuestram2: nivelManual2,
          pmmo_nivmuestram3: nivelManual3,
          lmsupniv1: limiteNivel1,
          lmsupniv2: limiteNivel2,
          lmsupniv3: limiteNivel3,
          pmmo_modificadopor: userId,
          pmmo_fechamodificacion: now,
          offlineModifiedAt: creatingOffline ? now : null,
        );
      } else {
        operacion = 'create';
        monitoreo = Monitoreo(
          pmmo_fecha: now,
          pmmo_estatus: 1,
          pmlt_codigo: _codigoLoteController.text.trim(),
          pmmo_casa: _casaController.text.trim(),
          pmmo_cantero: _canteroController.text.trim(),
          pmmo_canteros: _loteCanterosOriginal,
          pmmo_variedad: _selectedVariedad,
          pmmo_idvariedad: idVariedad,
          pmmo_grower: _responsableController.text.trim(),
          pmni_nombrecomun: _selectedPlaga,
          pmmo_cantidad: cantidadObservada,
          pmmo_cant_botada: cantidadBotada,
          pmmo_comentarios: _comentariosController.text.trim(),
          pmmo_automatico: !_isManualEntry,
          pmmo_contenedor: _loteContenedorOriginal ?? 'CONT_GENERAL',
          pmmo_muestra1: muestra1,
          pmmo_muestra2: muestra2,
          pmmo_muestra3: muestra3,
          pmmo_nivmuestraa1: nivelAuto1,
          pmmo_nivmuestraa2: nivelAuto2,
          pmmo_nivmuestraa3: nivelAuto3,
          pmmo_nivmuestram1: nivelManual1,
          pmmo_nivmuestram2: nivelManual2,
          pmmo_nivmuestram3: nivelManual3,
          lmsupniv1: limiteNivel1,
          lmsupniv2: limiteNivel2,
          lmsupniv3: limiteNivel3,
          pmmo_creadopor: userId,
          pmmo_fechacreacion: now,
          isOfflineCreated: creatingOffline,
          offlineModifiedAt: creatingOffline ? now : null,
        );
      }
      if (intranetService.isConnected.value) {
        if (operacion == 'create') {
          final nuevoMonitoreoCreado =
              await monitoreoService.crearMonitoreo(monitoreo);
          _lastCreatedSequence = nuevoMonitoreoCreado.pmmo_secuencia;
          _currentMonitoreo = nuevoMonitoreoCreado;
          if (_isPartialSave && mounted) {
            final fechaServidor = nuevoMonitoreoCreado.pmmo_fecha;
            if (fechaServidor != null)
              setState(() {
                _partialSaveDay = fechaServidor.toLocal();
              });
          }
        } else {
          await monitoreoService.actualizarMonitoreo(monitoreo);
          _lastCreatedSequence = null;
        }
        await _loadData();
        if (mounted)
          _showMessage(operacion == 'create'
              ? 'Creado correctamente'
              : 'Actualizado correctamente');
      } else {
        final offlineDbService =
            Provider.of<OfflineDatabaseService>(context, listen: false);

        List<dynamic> pendingChanges = [];
        final cachedPending = await cacheService.loadData('pending_monitoreos');
        if (cachedPending != null && cachedPending is List)
          pendingChanges = cachedPending;

        if (operacion == 'create') {
          monitoreo.pmmo_secuencia = -(DateTime.now().millisecondsSinceEpoch);
          _lastCreatedSequence = monitoreo.pmmo_secuencia;
          _currentMonitoreo = monitoreo;
        }

        pendingChanges.add({
          'operation': operacion,
          'monitoreo': monitoreo.toJson(),
          'timestamp': now.toIso8601String()
        });
        await cacheService.saveData('pending_monitoreos', pendingChanges);

        await offlineDbService.saveMonitoreoFromMap(monitoreo.toJson(),
            isLocal: true);
        debugPrint(
            '💾 Monitoreo ${monitoreo.pmmo_secuencia} guardado en SQLite (offline)');

        List<Monitoreo> monitoreos = [];
        final cachedData = await cacheService.loadData('monitoreos_data');
        if (cachedData != null && cachedData is List)
          monitoreos = cachedData
              .map<Monitoreo>((json) => Monitoreo.fromJson(json))
              .toList();
        if (operacion == 'update') {
          final index = monitoreos
              .indexWhere((m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
          if (index >= 0)
            monitoreos[index] = monitoreo;
          else
            monitoreos.add(monitoreo);
          _lastCreatedSequence = null;
        } else {
          monitoreos.add(monitoreo);
        }
        await cacheService.saveData(
            'monitoreos_data', monitoreos.map((m) => m.toJson()).toList());

        await _updatePendingChangesCount();
        await _loadData();
        if (mounted) _showMessage('Guardado localmente (SQLite)');
      }
      if (!_isPartialSave) {
        _clearForm();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
        FriendlyErrorDialog.show(context,
            title: 'Error',
            message: 'No se pudo guardar.',
            icon: Icons.error_outline,
            iconColor: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        if (!_isPartialSave) _updateEditMode(false);
      }
    }
  }

  Future<void> _editMonitoreo(Monitoreo monitoreo,
      {bool fromNavigation = false}) async {
    if (!mounted) return;
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);
    if (!monitoreoService.canEditMonitoreo(monitoreo)) {
      _showMessage('Sin permiso para editar');
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _isCreatingNew = false;
      });
      final cacheService = Provider.of<CacheService>(context, listen: false);
      final intranetService = _cachedIntranetService;
      if (intranetService == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      Monitoreo completeMonitoreo;
      if (intranetService.isConnected.value) {
        completeMonitoreo =
            await monitoreoService.getMonitoreoById(monitoreo.pmmo_secuencia!);
        await cacheService.saveData('monitoreo_${monitoreo.pmmo_secuencia}',
            completeMonitoreo.toJson());
      } else {
        final cachedData = await cacheService
            .loadData('monitoreo_${monitoreo.pmmo_secuencia}');
        completeMonitoreo =
            cachedData != null ? Monitoreo.fromJson(cachedData) : monitoreo;
      }
      if (completeMonitoreo.pmmo_contenedor == null ||
          completeMonitoreo.pmmo_contenedor!.isEmpty)
        completeMonitoreo.pmmo_contenedor = 'CONT_GENERAL';
      if (mounted) {
        String? variedadMonitoreo = completeMonitoreo.pmmo_variedad ??
            completeMonitoreo.pmva_descripcion;
        String? casaMonitoreo = completeMonitoreo.pmmo_casa;
        String? plagaMonitoreo = completeMonitoreo.pmni_nombrecomun;
        List<String> variedadesActualizadas = List.from(_variedades);
        List<String> casasActualizadas = List.from(_casas);
        List<String> plagasActualizadas = List.from(_plagas);
        Map<String, String> variedadesIdMapActualizado =
            Map.from(_variedadesIdMap);
        if (variedadMonitoreo != null &&
            variedadMonitoreo.isNotEmpty &&
            !variedadesActualizadas.contains(variedadMonitoreo)) {
          variedadesActualizadas.insert(1, variedadMonitoreo);
          if (completeMonitoreo.pmmo_idvariedad != null)
            variedadesIdMapActualizado[variedadMonitoreo] =
                completeMonitoreo.pmmo_idvariedad!;
        }
        if (casaMonitoreo != null &&
            casaMonitoreo.isNotEmpty &&
            !casasActualizadas.contains(casaMonitoreo))
          casasActualizadas.insert(1, casaMonitoreo);
        if (plagaMonitoreo != null &&
            plagaMonitoreo.isNotEmpty &&
            !plagasActualizadas.contains(plagaMonitoreo))
          plagasActualizadas.insert(1, plagaMonitoreo);
        if (!fromNavigation && !_isInPartialSaveMode) {
          _prepareNavigationData();
          final currentIndex = _navigationData.indexWhere(
              (m) => m.pmmo_secuencia == completeMonitoreo.pmmo_secuencia);
          if (currentIndex >= 0)
            setState(() {
              _currentNavigationIndex = currentIndex;
            });
        }
        setState(() {
          _variedades = variedadesActualizadas;
          _casas = casasActualizadas;
          _plagas = plagasActualizadas;
          _variedadesIdMap = variedadesIdMapActualizado;
          _currentMonitoreo = completeMonitoreo;
          _isEditing = true;
          _codigoLoteController.text = completeMonitoreo.pmlt_codigo ?? '';
          _casaController.text = completeMonitoreo.pmmo_casa ?? '';
          _canteroController.text = completeMonitoreo.pmmo_cantero ?? '';
          _responsableController.text = completeMonitoreo.pmmo_grower ?? '';
          _selectedVariedad = variedadMonitoreo;
          _selectedCasa = completeMonitoreo.pmmo_casa;
          _selectedPlaga = completeMonitoreo.pmni_nombrecomun;
          _loteCanterosOriginal = completeMonitoreo.pmmo_canteros;
          _loteContenedorOriginal = completeMonitoreo.pmmo_contenedor;
          _cantidadController.text =
              completeMonitoreo.pmmo_cantidad?.toString() ?? '0';
          _cantidadBotadaController.text =
              completeMonitoreo.pmmo_cant_botada?.toString() ?? '0';
          _comentariosController.text =
              completeMonitoreo.pmmo_comentarios ?? '';
          _muestra1Controller.text =
              completeMonitoreo.pmmo_muestra1?.toString() ?? '';
          _muestra2Controller.text =
              completeMonitoreo.pmmo_muestra2?.toString() ?? '';
          _muestra3Controller.text =
              completeMonitoreo.pmmo_muestra3?.toString() ?? '';
          _selectedNivelMuestra1 =
              completeMonitoreo.pmmo_nivmuestram1?.toString();
          _selectedNivelMuestra2 =
              completeMonitoreo.pmmo_nivmuestram2?.toString();
          _selectedNivelMuestra3 =
              completeMonitoreo.pmmo_nivmuestram3?.toString();
          _isManualEntry = completeMonitoreo.pmmo_automatico != true;
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
          _errorMessage = 'Error: $e';
        });
        _loteContenedorOriginal = 'CONT_GENERAL';
      }
    }
  }

  void _deleteMonitoreo(Monitoreo monitoreo) {
    final monitoreoService =
        Provider.of<MonitoreoService>(context, listen: false);
    if (!monitoreoService.canDeleteMonitoreo(monitoreo)) {
      _showMessage('Sin permiso');
      return;
    }
    final bool isTemporaryRecord = monitoreo.isTemporary() ||
        (monitoreo.isOfflineCreated ?? false) ||
        (monitoreo.pmmo_secuencia != null && monitoreo.pmmo_secuencia! < 0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(isTemporaryRecord
            ? '¿Eliminar permanentemente #${monitoreo.pmmo_secuencia}?'
            : '¿Eliminar #${monitoreo.pmmo_secuencia}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
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
                  });
                  return;
                }
                bool success = false;
                final offlineDbService =
                    Provider.of<OfflineDatabaseService>(context, listen: false);

                if (isTemporaryRecord) {
                  List<dynamic> pendingChanges = [];
                  final cachedPending =
                      await cacheService.loadData('pending_monitoreos');
                  if (cachedPending != null && cachedPending is List)
                    pendingChanges = cachedPending;
                  pendingChanges.removeWhere((change) =>
                      change['monitoreo']?['pmmo_secuencia'] ==
                      monitoreo.pmmo_secuencia);
                  await cacheService.saveData(
                      'pending_monitoreos', pendingChanges);

                  try {
                    await offlineDbService
                        .deleteMonitoreo(monitoreo.pmmo_secuencia!);
                    debugPrint(
                        '🗑️ Eliminado de SQLite: ${monitoreo.pmmo_secuencia}');
                  } catch (e) {
                    debugPrint('⚠️ Error eliminando de SQLite: $e');
                  }

                  List<Monitoreo> monitoreos = [];
                  final cachedData =
                      await cacheService.loadData('monitoreos_data');
                  if (cachedData != null && cachedData is List) {
                    monitoreos = cachedData
                        .map<Monitoreo>((json) => Monitoreo.fromJson(json))
                        .toList();
                    monitoreos.removeWhere(
                        (m) => m.pmmo_secuencia == monitoreo.pmmo_secuencia);
                    await cacheService.saveData('monitoreos_data',
                        monitoreos.map((m) => m.toJson()).toList());
                  }
                  await _updatePendingChangesCount();
                  success = true;
                } else {
                  if (intranetService.isConnected.value) {
                    try {
                      success = await monitoreoService
                          .eliminarMonitoreo(monitoreo.pmmo_secuencia!);
                      if (success) {
                        try {
                          await offlineDbService
                              .deleteMonitoreo(monitoreo.pmmo_secuencia!);
                        } catch (_) {}
                      }
                    } catch (e) {
                      success = false;
                    }
                  }
                  if (!success) {
                    List<dynamic> pendingChanges = [];
                    final cachedPending =
                        await cacheService.loadData('pending_monitoreos');
                    if (cachedPending != null && cachedPending is List)
                      pendingChanges = cachedPending;
                    pendingChanges.add({
                      'operation': 'delete',
                      'monitoreo': monitoreo.toJson(),
                      'timestamp': DateTime.now().toIso8601String()
                    });
                    await cacheService.saveData(
                        'pending_monitoreos', pendingChanges);
                    await _updatePendingChangesCount();
                    success = true;
                  }
                }
                await _loadData();
                if (success && mounted) {
                  _showMessage(isTemporaryRecord
                      ? 'Eliminado'
                      : 'Eliminado correctamente');
                  if (_isEditing &&
                      _currentMonitoreo?.pmmo_secuencia ==
                          monitoreo.pmmo_secuencia) {
                    _clearForm();
                    _tabController.animateTo(0);
                  }
                }
              } catch (e) {
                if (mounted)
                  FriendlyErrorDialog.show(context,
                      title: 'Error',
                      message: 'No se pudo eliminar.',
                      icon: Icons.delete_outline,
                      iconColor: Colors.red);
              } finally {
                if (mounted)
                  setState(() {
                    _isLoading = false;
                  });
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: isTemporaryRecord
                    ? Colors.red.shade700
                    : Colors.orange.shade700),
            child: Text(isTemporaryRecord ? 'Eliminar' : 'Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    try {
      final DateTime now = DateTime.now();
      DateTime normalizeDate(DateTime date) =>
          DateTime(date.year, date.month, date.day);
      final DateTime safeMinDate = DateTime(2020, 1, 1);
      final DateTime safeMaxDate = DateTime(now.year + 1, 12, 31);
      DateTime dataMinDate = safeMinDate;
      DateTime dataMaxDate = normalizeDate(now);
      if (_monitoreoData.isNotEmpty) {
        DateTime? tempMin;
        DateTime? tempMax;
        for (final monitoreo in _monitoreoData) {
          if (monitoreo.pmmo_fecha != null) {
            final fecha = normalizeDate(monitoreo.pmmo_fecha!);
            if (tempMin == null || fecha.isBefore(tempMin)) tempMin = fecha;
            if (tempMax == null || fecha.isAfter(tempMax)) tempMax = fecha;
          }
        }
        if (tempMin != null) dataMinDate = tempMin;
        if (tempMax != null && !tempMax.isAfter(normalizeDate(now)))
          dataMaxDate = tempMax;
      }
      DateTime selectedStart = dataMaxDate.subtract(const Duration(days: 30));
      if (selectedStart.isBefore(dataMinDate)) selectedStart = dataMinDate;
      DateTime selectedEnd = dataMaxDate;
      if (_fechaInicio != null) {
        final fechaInicio = normalizeDate(_fechaInicio!);
        if (!fechaInicio.isBefore(dataMinDate) &&
            !fechaInicio.isAfter(dataMaxDate)) selectedStart = fechaInicio;
      }
      if (_fechaFin != null) {
        final fechaFin = normalizeDate(_fechaFin!);
        if (!fechaFin.isBefore(dataMinDate) && !fechaFin.isAfter(dataMaxDate))
          selectedEnd = fechaFin;
      }
      if (selectedStart.isAfter(selectedEnd)) {
        selectedStart = selectedEnd.subtract(const Duration(days: 1));
        if (selectedStart.isBefore(dataMinDate)) selectedStart = dataMinDate;
      }
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(start: selectedStart, end: selectedEnd),
        firstDate: dataMinDate,
        lastDate: dataMaxDate,
        saveText: 'Aplicar',
        cancelText: 'Cancelar',
        helpText: 'Seleccionar rango',
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                    primary: MonitoreoStyles.primaryColor,
                    onPrimary: Colors.white)),
            child: child!),
      );
      if (picked != null && mounted) {
        setState(() {
          _fechaInicio = DateTime(picked.start.year, picked.start.month,
              picked.start.day, 0, 0, 0, 0);
          _fechaFin = DateTime(picked.end.year, picked.end.month,
              picked.end.day, 23, 59, 59, 999);
          _fechaInicioController.text =
              DateFormat('dd/MM/yyyy').format(_fechaInicio!);
          _fechaFinController.text =
              DateFormat('dd/MM/yyyy').format(_fechaFin!);
        });
      }
    } catch (e) {
      if (mounted) {
        final now = DateTime.now();
        final oneMonthAgo = now.subtract(const Duration(days: 30));
        setState(() {
          _fechaInicio = DateTime(
              oneMonthAgo.year, oneMonthAgo.month, oneMonthAgo.day, 0, 0, 0);
          _fechaFin = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          _fechaInicioController.text =
              DateFormat('dd/MM/yyyy').format(_fechaInicio!);
          _fechaFinController.text =
              DateFormat('dd/MM/yyyy').format(_fechaFin!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;
    final intranetService = Provider.of<IntranetService>(context);
    final bool isConnected = intranetService.isConnected.value;
    final authService = Provider.of<AuthService>(context);
    final bool hasValidSession = authService.isAuthenticated &&
        authService.getCurrentUserId() != null &&
        authService.getCurrentUserId() != 1;

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          SyncStatusBar(
              isConnected: isConnected,
              pendingChanges: _pendingChangesCount,
              isSyncing: _isSyncing,
              lastSyncStatus: _lastSyncStatus,
              onSyncPressed: _sincronizarCambiosPendientes),
          if (_isEditing && !_isWizardActive && !_isWizardRangeLocked)
            Builder(
              builder: (context) {
                final rangeText = _canterosRangeController.text;
                final parser = rangeText.isNotEmpty
                    ? CanteroRangeParser.parse(rangeText)
                    : null;
                final isValidRange =
                    parser != null && parser.isValid && !parser.isSingleCantero;
                final isValidSingle =
                    parser != null && parser.isValid && parser.isSingleCantero;
                final hasError = parser != null && !parser.isValid;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.indigo.shade200, width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route,
                              color: Colors.indigo.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Wizard de Canteros',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800),
                          ),
                          const Spacer(),
                          if (isValidRange)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${parser!.total} canteros',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _canterosRangeController,
                                decoration: InputDecoration(
                                  hintText: 'Ej: 4-8 (rango) o 4 (único)',
                                  hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: hasError
                                            ? Colors.red.shade300
                                            : Colors.indigo.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: hasError
                                            ? Colors.red
                                            : Colors.indigo.shade600,
                                        width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(
                                    isValidRange
                                        ? Icons.playlist_play
                                        : isValidSingle
                                            ? Icons.looks_one
                                            : Icons.edit,
                                    size: 18,
                                    color: hasError
                                        ? Colors.red
                                        : Colors.indigo.shade600,
                                  ),
                                  suffixIcon: rangeText.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear,
                                              size: 18,
                                              color: Colors.grey.shade600),
                                          onPressed: () {
                                            setState(() {
                                              _canterosRangeController.clear();
                                              _canteroController.clear();
                                            });
                                          },
                                        )
                                      : null,
                                  errorText: hasError ? parser!.error : null,
                                  errorStyle: const TextStyle(fontSize: 10),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (value) {
                                  setState(() {
                                    if (value.isNotEmpty) {
                                      final p = CanteroRangeParser.parse(value);
                                      if (p.isValid && p.isSingleCantero) {
                                        _canteroController.text =
                                            p.inicio.toString();
                                      }
                                    }
                                  });
                                },
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) _initWizard(value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: (isValidRange || isValidSingle)
                                  ? () => _initWizard(rangeText)
                                  : null,
                              icon: Icon(
                                  isValidRange ? Icons.play_arrow : Icons.check,
                                  size: 16),
                              label: Text(
                                isValidRange ? 'Iniciar' : 'Aplicar',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isValidRange)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Iterará canteros ${parser!.inicio} al ${parser.fin}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.indigo.shade600),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          if (_isWizardActive && _isEditing)
            CanteroWizardBar(
              canterosRange: _canterosRangeController.text,
              canteroActual: _wizardCanteroActual,
              totalCanteros: _wizardTotalCanteros,
              canteroInicio: _wizardCanteroInicio,
              canteroFin: _wizardCanteroFin,
              isWizardActive: _isWizardActive,
              isRangeLocked: _isWizardRangeLocked,
              formState: _getWizardFormState(),
              loteInfo: _codigoLoteController.text.isNotEmpty
                  ? _codigoLoteController.text
                  : null,
              casaInfo: _casaController.text.isNotEmpty
                  ? 'Casa ${_casaController.text}'
                  : null,
              onPrevious: _wizardPrevious,
              onNext: _wizardNext,
              onSkip: _wizardSkip,
              onFinish: _wizardFinish,
              onRangeChanged: _onCanterosRangeChanged,
              canGoPrevious: _canWizardGoPrevious(),
              canGoNext: _canWizardGoNext(),
              parcialInfo: _getWizardParcialInfo(),
              canteroTieneDatos:
                  (_wizardCanterosMonitoreos[_wizardCanteroActual]
                          ?.isNotEmpty ??
                      false),
              onParcialPrevious:
                  _canWizardParcialPrevious() ? _wizardParcialPrevious : null,
              onParcialNext: _wizardParcialNext,
              canParcialPrevious: _canWizardParcialPrevious(),
              canParcialNext: _canWizardParcialNext(),
              isEditingParcial: _isEditingExistingPartial,
            ),
          if (_isEditing &&
              !_isWizardActive &&
              (_navigationData.isNotEmpty || _isInPartialSaveMode))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border:
                      Border(bottom: BorderSide(color: Colors.blue.shade200))),
              child: Row(
                children: [
                  IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: _canNavigatePrevious()
                              ? Colors.blue.shade700
                              : Colors.grey),
                      onPressed:
                          _canNavigatePrevious() ? _navigatePrevious : null,
                      tooltip: 'Anterior'),
                  Expanded(
                      child: Text(_getNavigationInfo(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500))),
                  IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: _canNavigateNext()
                              ? Colors.blue.shade700
                              : Colors.grey),
                      onPressed: _canNavigateNext() ? _navigateNext : null,
                      tooltip: 'Siguiente'),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: (_isEditing || _isWizardActive || _isWizardRangeLocked)
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              children: [
                ConsultaTab(
                  monitoreos: _filteredMonitoreoData,
                  columns: _columns,
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  onEdit: _editMonitoreo,
                  onDelete: _deleteMonitoreo,
                  onDetails: (monitoreo) {
                    MonitoreoDetailsDialog.showMonitoreoDetails(
                        context, monitoreo, () => _editMonitoreo(monitoreo));
                  },
                  onSearch: _searchMonitoreos,
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
                  plagas: _plagas,
                  casas: _casas,
                  canteros: _obtenerListaCanteros(),
                  variedades: _variedades,
                  onEstadoChanged: (value) =>
                      setState(() => _selectedEstado = value),
                  onPlagaChanged: (value) =>
                      setState(() => _selectedPlaga = value),
                  onCasaChanged: (value) =>
                      setState(() => _selectedCasaFiltro = value),
                  onCanteroChanged: (value) =>
                      setState(() => _selectedCanteroFiltro = value),
                  onVariedadChanged: (value) =>
                      setState(() => _selectedVariedadFiltro = value),
                  onSelectDateRange: (ctx) => _selectDateRange(ctx),
                  onFechaReset: _resetFechasFiltro,
                  onExportExcel: _exportToExcel,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  itemsPerPage: _itemsPerPage,
                  totalItems: _totalItems,
                  onPageChanged: _handlePageChange,
                  onItemsPerPageChanged: _handleItemsPerPageChange,
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  onSort: _handleSort,
                  onColumnResize: _handleColumnResize,
                  columnWidths: _columnWidths,
                  pendingChangesCount: _pendingChangesCount,
                  isSmallScreen: isSmallScreen,
                ),
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
                  onCancel: () async {
                    if (_isWizardActive || _isWizardRangeLocked) {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Cancelar wizard?'),
                          content: const Text(
                              'Se perderá el progreso del wizard de canteros. ¿Está seguro?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('No, continuar')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Sí, cancelar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmar != true) return;
                    }
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
                    });
                    _updateResponsable(value);
                  },
                  onPlagaChanged: (value) {
                    setState(() {
                      _selectedPlaga = value;
                    });
                    if (value != null) _loadInfoPlagaAction(value);
                  },
                  onNivelMuestra1Changed: (value) =>
                      setState(() => _selectedNivelMuestra1 = value),
                  onNivelMuestra2Changed: (value) =>
                      setState(() => _selectedNivelMuestra2 = value),
                  onNivelMuestra3Changed: (value) =>
                      setState(() => _selectedNivelMuestra3 = value),
                  onMuestra1Changed: (value) => _actualizarCantidadObservada(),
                  onMuestra2Changed: (value) => _actualizarCantidadObservada(),
                  onMuestra3Changed: (value) => _actualizarCantidadObservada(),
                  isOfflineMode: !isConnected,
                  isSmallScreen: isSmallScreen,
                  isInPartialSaveMode:
                      _isInPartialSaveMode || _isWizardRangeLocked,
                  isEditingExistingPartial: _isEditingExistingPartial,
                  plagasRegistradas: _plagasRegistradasParcial,
                  variedadesUsadas: _variedadesUsadasParcial,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          border:
              Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: TabBar(
          controller: _tabController,
          labelPadding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2,
          tabs: [
            Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt,
                      size: 18,
                      color: _tabController.index == 0
                          ? MonitoreoStyles.primaryColor
                          : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('Consulta',
                      style: TextStyle(
                          fontSize: 12,
                          color: _tabController.index == 0
                              ? MonitoreoStyles.primaryColor
                              : Colors.grey.shade500)),
                ],
              ),
            ),
            Tab(
              height: 46,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 18,
                      color: _tabController.index == 1
                          ? MonitoreoStyles.primaryColor
                          : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('Registro',
                      style: TextStyle(
                          fontSize: 12,
                          color: _tabController.index == 1
                              ? MonitoreoStyles.primaryColor
                              : Colors.grey.shade500)),
                ],
              ),
            ),
          ],
          indicatorColor: MonitoreoStyles.primaryColor,
        ),
      ),
    );
  }
}
