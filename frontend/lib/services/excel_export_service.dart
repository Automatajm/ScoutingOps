import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import '../../models/monitoreo_model.dart';

class ExcelExportService {
  // ===== CONTROL DE ESTADO SIMPLE =====
  static bool _isDownloading = false;

  /// ===== MÉTODO PRINCIPAL DE EXPORTACIÓN =====
  Future<bool> exportarMonitoreosExcel(
    List<Monitoreo> monitoreos,
    String fileName,
    List<Map<String, dynamic>> columns,
    Function(String message) showMessage,
    Function(bool isExporting) setExportingState,
  ) async {
    // 🛡️ PROTECCIÓN ABSOLUTA CONTRA MÚLTIPLES DESCARGAS
    if (_isDownloading) {
      debugPrint("🚫 DESCARGA YA EN PROGRESO - RECHAZANDO LLAMADA");
      showMessage('Descarga ya en progreso. Por favor espere...');
      return false;
    }

    // 🔒 BLOQUEAR INMEDIATAMENTE
    _isDownloading = true;

    try {
      debugPrint("🔍 === INICIANDO EXPORTACIÓN EXCEL DE MONITOREOS ===");
      setExportingState(true);

      // ===== VALIDACIÓN DE DATOS =====
      if (monitoreos.isEmpty) {
        showMessage('No hay datos para exportar');
        return false;
      }

      if (columns.isEmpty) {
        showMessage('No hay columnas configuradas para exportar');
        return false;
      }

      // ===== GENERAR NOMBRE DE ARCHIVO CON TIMESTAMP =====
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreArchivo = fileName.isEmpty
          ? 'Monitoreos_$timestamp.xlsx'
          : fileName.endsWith('.xlsx')
              ? fileName.replaceAll('.xlsx', '_$timestamp.xlsx')
              : '${fileName}_$timestamp.xlsx';

      debugPrint("📝 Generando archivo: $nombreArchivo");

      // ===== CREAR DOCUMENTO EXCEL =====
      final excel = Excel.createExcel();

      // Crear la hoja que necesitamos PRIMERO
      final sheet = excel['Monitoreos'];

      // Luego eliminar Sheet1 y cualquier otra hoja por defecto
      final sheetsToDelete =
          excel.sheets.keys.where((name) => name != 'Monitoreos').toList();
      for (String sheetName in sheetsToDelete) {
        excel.delete(sheetName);
      }

      // ===== AÑADIR ENCABEZADOS SIN FORMATO =====
      debugPrint("📋 Añadiendo encabezados...");
      for (int i = 0; i < columns.length; i++) {
        final cellIndex =
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0);
        final cell = sheet.cell(cellIndex);
        cell.value = TextCellValue(columns[i]['title'] ?? 'Columna ${i + 1}');
        // Sin formato - encabezados simples
      }

      // ===== AÑADIR DATOS =====
      debugPrint("📊 Añadiendo ${monitoreos.length} filas de datos...");
      for (int rowIndex = 0; rowIndex < monitoreos.length; rowIndex++) {
        final monitoreo = monitoreos[rowIndex];

        for (int colIndex = 0; colIndex < columns.length; colIndex++) {
          final column = columns[colIndex];
          final cellIndex = CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: rowIndex + 1,
          );

          String value = '';
          if (column['valueExtractor'] != null) {
            try {
              value = column['valueExtractor'](monitoreo)?.toString() ?? '';
            } catch (e) {
              value = 'Error';
            }
          }

          final cell = sheet.cell(cellIndex);
          cell.value = TextCellValue(value);
        }
      }

      // ===== CONFIGURAR ANCHOS DE COLUMNA =====
      debugPrint("📐 Configurando anchos de columna...");
      for (int i = 0; i < columns.length; i++) {
        final width = columns[i]['width']?.toDouble() ?? 100.0;
        final adjustedWidth =
            math.max<double>(10.0, math.min<double>(width / 8, 50.0));
        sheet.setColumnWidth(i, adjustedWidth);
      }

      // ===== DESCARGA MANUAL SIN USAR EL SISTEMA AUTOMÁTICO =====
      debugPrint("📥 Iniciando descarga manual del archivo...");

      if (kIsWeb) {
        await _downloadExcelManual(excel, nombreArchivo, showMessage);
      } else {
        showMessage('Exportación no soportada en esta plataforma');
        return false;
      }

      debugPrint("✅ EXPORTACIÓN COMPLETADA EXITOSAMENTE");
      showMessage('Archivo Excel exportado exitosamente: $nombreArchivo');
      return true;
    } catch (e, stackTrace) {
      debugPrint("❌ ERROR EN EXPORTACIÓN: $e");
      debugPrint("🔍 Stack trace del error: $stackTrace");

      showMessage('Error al exportar archivo: $e');
      return false;
    } finally {
      // ASEGURAR QUE SIEMPRE SE LIBEREN LOS CONTROLES
      _isDownloading = false;
      setExportingState(false);
      debugPrint("🔓 CONTROLES DE DESCARGA LIBERADOS");
    }
  }

  /// ===== MÉTODO DE DESCARGA MANUAL (SIN USAR excel.save()) =====
  Future<void> _downloadExcelManual(
      Excel excel, String fileName, Function(String) showMessage) async {
    debugPrint("🌐 Iniciando descarga manual...");

    try {
      // ===== GENERAR BYTES SIN ACTIVAR DESCARGA AUTOMÁTICA =====
      debugPrint("💾 Generando bytes del Excel...");

      // CRÍTICO: NO usar excel.save() que activa descarga automática
      // En su lugar, usar encode() que solo genera los bytes
      var excelBytes = excel.encode();

      if (excelBytes == null || excelBytes.isEmpty) {
        throw Exception('No se pudieron generar los bytes del archivo Excel');
      }

      debugPrint("💾 Archivo generado: ${excelBytes.length} bytes");

      // ===== PROCESO IDÉNTICO AL QUE FUNCIONA EN LOTES =====
      final blob = html.Blob([Uint8List.fromList(excelBytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final downloadLink = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.children.add(downloadLink);
      downloadLink.click();
      html.document.body?.children.remove(downloadLink);
      html.Url.revokeObjectUrl(url);

      debugPrint("✅ Descarga manual completada exitosamente");
    } catch (e) {
      debugPrint("❌ Error en descarga manual: $e");
      showMessage('Error al descargar el archivo: $e');
      rethrow;
    }
  }

  /// ===== MÉTODO ALTERNATIVO CON FILTROS =====
  Future<bool> exportarMonitoreosConFiltros(
    List<Monitoreo> monitoreoData,
    List<Monitoreo> filteredMonitoreoData,
    String fileName,
    List<Map<String, dynamic>> columns,
    Function(String message) showMessage,
    Function(bool isExporting) setExportingState,
    bool onlyFiltered,
  ) async {
    // Determinar qué datos exportar
    final List<Monitoreo> dataToExport =
        onlyFiltered ? filteredMonitoreoData : monitoreoData;

    // Usar el método principal
    return await exportarMonitoreosExcel(
      dataToExport,
      fileName,
      columns,
      showMessage,
      setExportingState,
    );
  }

  /// ===== MÉTODO DE DIAGNÓSTICO DEL NAVEGADOR =====
  static void diagnosticarNavegadorExportacion() {
    debugPrint("🔍 === DIAGNÓSTICO DEL NAVEGADOR PARA EXPORTACIÓN ===");
    debugPrint("📱 Plataforma: ${kIsWeb ? 'WEB' : 'MÓVIL'}");

    if (kIsWeb) {
      try {
        debugPrint("🌐 UserAgent: ${html.window.navigator.userAgent}");
        debugPrint("📁 FileReader disponible: ${_checkFileReader()}");
        debugPrint("💾 Blob disponible: ${_checkBlob()}");
        debugPrint("🔗 URL.createObjectURL disponible: ${_checkObjectURL()}");
      } catch (e) {
        debugPrint("❌ Error verificando navegador: $e");
      }
    }
  }

  static bool _checkFileReader() {
    try {
      final reader = html.FileReader();
      return reader != null;
    } catch (e) {
      return false;
    }
  }

  static bool _checkBlob() {
    try {
      final blob = html.Blob(['test']);
      return blob != null;
    } catch (e) {
      return false;
    }
  }

  static bool _checkObjectURL() {
    try {
      final blob = html.Blob(['test']);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ===== MÉTODO PARA RESETEAR CONTROL =====
  static void resetDownloadControl() {
    _isDownloading = false;
    debugPrint("🔄 CONTROL DE DESCARGA RESETEADO");
  }
}
