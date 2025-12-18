import 'package:flutter/material.dart';
import '../../../models/monitoreo_model.dart';

/// Mixin que maneja la navegación entre registros parciales del mismo lote/casa
mixin MonitoreoNavigationMixin<T extends StatefulWidget> on State<T> {
  // ===== VARIABLES DE NAVEGACIÓN =====
  List<Monitoreo> _navigationData = [];
  int _currentNavigationIndex = -1;
  String? _partialSaveCantero;
  String? _partialSaveCasa;
  String? _partialSaveLote;
  String? _partialSaveVariedad;
  DateTime? _partialSaveDay;

  // ===== GETTERS =====
  List<Monitoreo> get navigationData => _navigationData;
  int get currentNavigationIndex => _currentNavigationIndex;
  String? get partialSaveCantero => _partialSaveCantero;
  String? get partialSaveCasa => _partialSaveCasa;
  String? get partialSaveLote => _partialSaveLote;
  DateTime? get partialSaveDay => _partialSaveDay;

  // ===== SETTERS =====
  set partialSaveCantero(String? value) => _partialSaveCantero = value;
  set partialSaveCasa(String? value) => _partialSaveCasa = value;
  set partialSaveLote(String? value) => _partialSaveLote = value;
  set partialSaveVariedad(String? value) => _partialSaveVariedad = value;
  set partialSaveDay(DateTime? value) => _partialSaveDay = value;

  // ===== MÉTODOS ABSTRACTOS =====
  
  /// Datos de monitoreos completos
  List<Monitoreo> get monitoreoData;
  
  /// Si está en modo guardado parcial
  bool get isInPartialSaveMode;
  
  /// Si está en modo entrada manual
  bool get isManualEntry;
  
  /// Método para editar un monitoreo
  void editMonitoreo(Monitoreo monitoreo, {bool fromNavigation = false});
  
  /// Método para preparar formulario para nuevo parcial
  void prepareFormForNewPartial();
  
  /// Método para mostrar mensajes
  void showMessage(String message);

  // ===== PREPARACIÓN DE DATOS DE NAVEGACIÓN =====
  
  void prepareNavigationData() {
    if (isInPartialSaveMode && _partialSaveCasa != null && _partialSaveLote != null) {
      final DateTime referenciaDay = _partialSaveDay ?? DateTime.now();
      final DateTime inicioDelDia = DateTime(
        referenciaDay.year,
        referenciaDay.month,
        referenciaDay.day,
        0, 0, 0
      );
      final DateTime finDelDia = DateTime(
        referenciaDay.year,
        referenciaDay.month,
        referenciaDay.day,
        23, 59, 59, 999
      );

      // Filtrar según modo manual o automático
      if (isManualEntry && _partialSaveCantero != null) {
        _navigationData = monitoreoData.where((m) {
          return m.pmmo_casa == _partialSaveCasa &&
              m.pmlt_codigo == _partialSaveLote &&
              m.pmmo_cantero == _partialSaveCantero &&
              m.pmmo_fecha != null &&
              !m.pmmo_fecha!.toLocal().isBefore(inicioDelDia) &&
              !m.pmmo_fecha!.toLocal().isAfter(finDelDia);
        }).toList();
      } else {
        _navigationData = monitoreoData.where((m) {
          return m.pmmo_casa == _partialSaveCasa &&
              m.pmlt_codigo == _partialSaveLote &&
              m.pmmo_fecha != null &&
              !m.pmmo_fecha!.toLocal().isBefore(inicioDelDia) &&
              !m.pmmo_fecha!.toLocal().isAfter(finDelDia);
        }).toList();
      }

      _navigationData.sort((a, b) => 
        (a.pmmo_secuencia ?? 0).compareTo(b.pmmo_secuencia ?? 0));
      
      // Insertar registro virtual al inicio para "Nuevo"
      _navigationData.insert(0, _createVirtualPartialZero());
    } else {
      // Modo normal: todos los monitoreos
      _navigationData = List.from(monitoreoData);
      _navigationData.sort((a, b) => 
        (a.pmmo_secuencia ?? 0).compareTo(b.pmmo_secuencia ?? 0));
    }
  }

  // ===== CREACIÓN DE REGISTRO VIRTUAL =====
  
  Monitoreo _createVirtualPartialZero() {
    return Monitoreo(
      pmmo_secuencia: 0,
      pmmo_fecha: DateTime.now(),
      pmmo_estatus: 1,
      pmlt_codigo: _partialSaveLote ?? '',
      pmmo_casa: _partialSaveCasa ?? '',
      pmmo_cantero: _partialSaveCantero ?? '',
      pmmo_variedad: null,
      pmni_nombrecomun: null,
      pmmo_cantidad: 0,
      pmmo_automatico: !isManualEntry,
    );
  }

  // ===== NAVEGACIÓN =====
  
  void navigateNext() {
    if (_navigationData.isEmpty) return;
    
    int nextIndex = _currentNavigationIndex + 1;
    if (nextIndex >= _navigationData.length) {
      showMessage('Último registro');
      return;
    }
    
    _navigateToIndex(nextIndex);
  }

  void navigatePrevious() {
    if (_navigationData.isEmpty) return;
    
    int prevIndex = _currentNavigationIndex - 1;
    if (prevIndex < 0) {
      showMessage('Primer registro');
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

    // Si es el registro virtual (nuevo), preparar formulario
    if (index == 0 && isInPartialSaveMode && monitoreo.pmmo_secuencia == 0) {
      prepareFormForNewPartial();
    } else {
      editMonitoreo(monitoreo, fromNavigation: true);
    }
  }

  // ===== INFORMACIÓN DE NAVEGACIÓN =====
  
  String getNavigationInfo() {
    if (_navigationData.isEmpty) return '';
    
    if (_currentNavigationIndex == 0 && isInPartialSaveMode) {
      return isManualEntry && _partialSaveCantero != null
          ? 'Casa $_partialSaveCasa, Cantero $_partialSaveCantero | Nuevo'
          : 'Casa $_partialSaveCasa, Lote $_partialSaveLote | Nuevo';
    }

    final current = _currentNavigationIndex + 1;
    final total = _navigationData.length;

    return isInPartialSaveMode
        ? (isManualEntry
            ? 'Casa $_partialSaveCasa, Cantero $_partialSaveCantero | $current de $total'
            : 'Casa $_partialSaveCasa | $current de $total')
        : 'Registro $current de $total';
  }

  // ===== VALIDADORES =====
  
  bool canNavigateNext() =>
      _navigationData.isNotEmpty && 
      _currentNavigationIndex < _navigationData.length - 1;

  bool canNavigatePrevious() =>
      _navigationData.isNotEmpty && 
      _currentNavigationIndex > 0;

  // ===== LIMPIEZA =====
  
  void clearNavigationData() {
    setState(() {
      _navigationData.clear();
      _currentNavigationIndex = -1;
      _partialSaveCantero = null;
      _partialSaveCasa = null;
      _partialSaveLote = null;
      _partialSaveDay = null;
    });
  }
}