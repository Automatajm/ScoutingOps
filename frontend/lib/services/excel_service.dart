import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../models/lote_model.dart';
import '../../../services/lote_service.dart';

// Excepción personalizada para manejar errores de formato
class FormatPersonalizadoException implements Exception {
  final String message;
  FormatPersonalizadoException(this.message);

  @override
  String toString() => message;
}

class ExcelService {
  final LoteService _loteService = LoteService();

  // Mapeo de estatus a nombres de estado
  final Map<int, String> _estatusMap = {
    1: 'Activo',
    0: 'Inactivo',
  };

  /// ===== MODAL BONITO PARA SOLUCIÓN DE FORMATO =====
  Future<void> _mostrarModalSolucionFormato(BuildContext context) async {
    const Color primaryColor = Color(0xFF1E73BB);
    const Color accentColor = Color(0xFF00A99D);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Archivo con Formatos Personalizados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción del problema
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'El archivo contiene formatos de número personalizados que no son compatibles con la importación web.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D3748),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Solución recomendada
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: accentColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Solución Recomendada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pasos numerados
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildPasoSolucion(
                          1, 'Abrir el archivo en Microsoft Excel'),
                      _buildPasoSolucion(
                          2, 'Seleccionar todos los datos (Ctrl+A)'),
                      _buildPasoSolucion(
                          3, 'Ir a Inicio → Formato → Formato de celdas'),
                      _buildPasoSolucion(4,
                          'En la pestaña "Número", seleccionar "General" o "Texto"'),
                      _buildPasoSolucion(5, 'Aplicar el formato'),
                      _buildPasoSolucion(
                          6, 'Guardar como "Libro de Excel (.xlsx)" nuevo'),
                      _buildPasoSolucion(
                          7, 'Intentar importar el nuevo archivo',
                          isLast: true),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Alternativa rápida
                Row(
                  children: [
                    Icon(Icons.flash_on,
                        color: Colors.amber.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Alternativa Rápida',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.content_copy,
                          color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Copiar y pegar los datos en un nuevo archivo Excel en blanco.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D3748),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Entendido',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper para construir pasos numerados
  Widget _buildPasoSolucion(int numero, String texto, {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1E73BB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$numero',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ===== DIAGNÓSTICO INTEGRADO =====

  // Diagnóstico del navegador (llamar en initState)
  static void diagnosticarNavegador() {
    debugPrint("🔍 === DIAGNÓSTICO DEL NAVEGADOR ===");

    debugPrint("📱 Plataforma: ${kIsWeb ? 'WEB' : 'NATIVO'}");

    if (kIsWeb) {
      try {
        debugPrint("🌐 UserAgent: ${html.window.navigator.userAgent}");
        debugPrint("🔧 HTML5 File API disponible: ${_checkFileAPI()}");
        debugPrint("📁 FileReader disponible: ${_checkFileReader()}");
        debugPrint("💾 Blob disponible: ${_checkBlob()}");
        debugPrint("🔗 URL.createObjectURL disponible: ${_checkObjectURL()}");

        _checkMemoryLimits();
      } catch (e) {
        debugPrint("❌ Error verificando navegador: $e");
      }
    }
  }

  static bool _checkFileAPI() {
    try {
      return html.window.navigator.userAgent.isNotEmpty;
    } catch (e) {
      return false;
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

  static void _checkMemoryLimits() {
    try {
      final testSize = 10 * 1024 * 1024; // 10MB
      final testArray = Uint8List(testSize);
      debugPrint(
          "✅ Memoria disponible: Al menos ${testSize ~/ (1024 * 1024)}MB");
    } catch (e) {
      debugPrint("⚠️ Limitación de memoria detectada: $e");
    }
  }

  // Diagnóstico de archivo
  void _diagnosticarArchivo(FilePickerResult result) {
    debugPrint("🔍 === DIAGNÓSTICO DEL ARCHIVO ===");

    final file = result.files.first;

    debugPrint("📄 Nombre archivo: ${file.name}");
    debugPrint(
        "📏 Tamaño archivo: ${file.size} bytes (${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB)");
    debugPrint("🏷️ Extensión: ${file.extension}");

    // Verificar si el tamaño es problemático
    if (file.size > 50 * 1024 * 1024) {
      // 50MB
      debugPrint(
          "⚠️ ADVERTENCIA: Archivo muy grande (>50MB) - puede causar problemas en web");
    }

    // Verificar extensión
    if (file.extension?.toLowerCase() != 'xlsx' &&
        file.extension?.toLowerCase() != 'xls') {
      debugPrint("❌ ERROR: Extensión no válida");
      return;
    }

    // Intentar leer los primeros bytes
    try {
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = file.bytes;
        debugPrint("💾 Bytes disponibles en web: ${bytes != null}");
        if (bytes != null) {
          debugPrint("📊 Primeros 10 bytes: ${bytes.take(10).toList()}");

          // Verificar firmas de archivo Excel
          if (bytes.length >= 4) {
            final signature = bytes.take(4).toList();
            debugPrint("🔐 Firma del archivo: $signature");

            // ZIP signature (Excel moderno .xlsx)
            if (signature[0] == 0x50 && signature[1] == 0x4B) {
              debugPrint("✅ Archivo Excel moderno (.xlsx) detectado");
            }
            // OLE signature (Excel antiguo .xls)
            else if (signature[0] == 0xD0 && signature[1] == 0xCF) {
              debugPrint("✅ Archivo Excel antiguo (.xls) detectado");
            } else {
              debugPrint(
                  "⚠️ Firma de archivo no reconocida - podría no ser un Excel válido");
            }
          }
        } else {
          debugPrint("❌ ERROR: No se pudieron obtener los bytes del archivo");
        }
      } else {
        debugPrint("📱 Modo nativo - usando ruta del archivo");
      }
    } catch (e) {
      debugPrint("❌ Error leyendo archivo: $e");
    }
  }

  // Diagnóstico de decodificación
  void _diagnosticarDecodificacion(Uint8List bytes) {
    debugPrint("🔍 === DIAGNÓSTICO DE DECODIFICACIÓN ===");

    try {
      debugPrint("📊 Iniciando decodificación de ${bytes.length} bytes...");

      final stopwatch = Stopwatch()..start();

      // Intentar decodificar paso a paso
      var excelDoc = excel.Excel.decodeBytes(bytes);

      stopwatch.stop();
      debugPrint(
          "⏱️ Tiempo de decodificación: ${stopwatch.elapsedMilliseconds}ms");

      debugPrint("📋 Hojas encontradas: ${excelDoc.sheets.length}");

      for (var sheetName in excelDoc.sheets.keys) {
        var sheet = excelDoc.sheets[sheetName];
        if (sheet != null) {
          debugPrint(
              "📄 Hoja '$sheetName': ${sheet.maxRows} filas x ${sheet.maxColumns} columnas");

          // Verificar si la hoja está vacía
          if (sheet.maxRows == 0) {
            debugPrint("⚠️ Hoja '$sheetName' está vacía");
          }

          // Intentar leer la primera celda
          try {
            var firstCell = sheet.cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
            debugPrint("🔤 Primera celda: '${firstCell.value}'");
          } catch (e) {
            debugPrint("❌ Error leyendo primera celda: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ ERROR EN DECODIFICACIÓN: $e");
      debugPrint("📋 Stack trace: ${StackTrace.current}");

      // Intentar diagnóstico más detallado del error
      if (e.toString().contains('custom numFmtId')) {
        debugPrint("🔧 ERROR CONOCIDO: Formato personalizado no soportado");
        debugPrint("💡 SOLUCIÓN: Usar procesamiento alternativo seguro");
      } else if (e.toString().contains('Exception: custom')) {
        debugPrint("🔧 ERROR: Formato Excel no estándar");
        debugPrint(
            "💡 SOLUCIÓN: Probar con Excel más simple o guardar como .xlsx estándar");
      }

      // Re-lanzar el error para que el flujo normal lo maneje
      rethrow;
    }
  }

  // Diagnóstico de procesamiento
  void _diagnosticarProcesamiento(List<Lote> lotes) {
    debugPrint("🔍 === DIAGNÓSTICO DE PROCESAMIENTO ===");

    debugPrint("📊 Lotes procesados: ${lotes.length}");

    if (lotes.isEmpty) {
      debugPrint("❌ NO SE PROCESARON LOTES");
      return;
    }

    // Verificar primer lote
    var primerLote = lotes.first;
    debugPrint("📋 Primer lote procesado:");
    debugPrint("   - Código: ${primerLote.pmlt_codigo}");
    debugPrint("   - Cantidad: ${primerLote.pmlt_cantidad}");
    debugPrint("   - Variedad: ${primerLote.pmlt_variedad}");
    debugPrint("   - ID Variedad: ${primerLote.pmlt_idvariedad}");

    // Verificar problemas comunes
    int lotesConProblemas = 0;
    for (var lote in lotes) {
      if (lote.pmlt_codigo == null || lote.pmlt_codigo!.isEmpty) {
        lotesConProblemas++;
      }
    }

    if (lotesConProblemas > 0) {
      debugPrint("⚠️ $lotesConProblemas lotes tienen códigos vacíos");
    } else {
      debugPrint("✅ Todos los lotes tienen códigos válidos");
    }
  }

  /// ===== MÉTODO 1: Exportar Excel - CON DIAGNÓSTICOS =====
  Future<void> exportarExcel(
    BuildContext context,
    List<Lote> sortedLoteData,
    Map<int, String> estatusMap,
    Function(String message) showMessage,
    Function(bool isExporting) setExportingState,
  ) async {
    debugPrint("🔍 === INICIANDO EXPORTACIÓN EXCEL ===");
    setExportingState(true);

    try {
      var excelDoc = excel.Excel.createExcel();
      String defaultSheet = excelDoc.sheets.keys.first;
      String sheetName = 'Lotes';

      if (defaultSheet != sheetName) {
        excelDoc.rename(defaultSheet, sheetName);
      }

      var sheet = excelDoc.sheets[sheetName]!;

      List<String> encabezados = [
        'ID',
        'Código',
        'Canteros',
        'Cantidad',
        'IDVariedad',
        'Variedad',
        'Contenedor',
        'Grower',
        'Casa',
        'Estado',
        'Fecha Creación'
      ];

      for (int i = 0; i < encabezados.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = excel.TextCellValue(encabezados[i]);
        cell.cellStyle = excel.CellStyle(
          bold: true,
          horizontalAlign: excel.HorizontalAlign.Center,
        );
      }

      List<Lote> lotesAExportar = sortedLoteData;
      debugPrint("📊 Exportando ${lotesAExportar.length} lotes...");

      for (int i = 0; i < lotesAExportar.length; i++) {
        var lote = lotesAExportar[i];
        int row = i + 1;

        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 0, rowIndex: row))
                .value =
            excel.TextCellValue(lote.pmlt_secuencia?.toString() ?? "0");
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_codigo ?? '');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_canteros ?? '');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_cantidad?.toString() ?? "0");
        sheet
                .cell(excel.CellIndex.indexByColumnRow(
                    columnIndex: 4, rowIndex: row))
                .value =
            excel.TextCellValue(lote.pmlt_idvariedad?.toString() ?? "0");
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_variedad ?? '');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_contenedor ?? '');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_grower ?? '');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = excel.TextCellValue(lote.pmlt_casa ?? '');
        sheet
            .cell(
                excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = excel.TextCellValue(estatusMap[lote.pmlt_estatus] ?? '');

        if (lote.pmlt_fechacreacion != null) {
          sheet
                  .cell(excel.CellIndex.indexByColumnRow(
                      columnIndex: 10, rowIndex: row))
                  .value =
              excel.TextCellValue(DateFormat('dd/MM/yyyy HH:mm')
                  .format(lote.pmlt_fechacreacion!));
        } else {
          sheet
              .cell(excel.CellIndex.indexByColumnRow(
                  columnIndex: 10, rowIndex: row))
              .value = excel.TextCellValue('');
        }
      }

      for (int i = 0; i < encabezados.length; i++) {
        sheet.setColumnWidth(i, 15.0);
      }

      String fileName =
          'lotes_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      debugPrint("📝 Generando archivo: $fileName");
      var excelBytes = excelDoc.encode();

      if (excelBytes != null) {
        debugPrint("💾 Archivo generado: ${excelBytes.length} bytes");

        if (kIsWeb) {
          final blob = html.Blob([Uint8List.fromList(excelBytes)]);
          final url = html.Url.createObjectUrlFromBlob(blob);

          final downloadLink = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..style.display = 'none';

          html.document.body?.children.add(downloadLink);
          downloadLink.click();
          html.document.body?.children.remove(downloadLink);
          html.Url.revokeObjectUrl(url);

          debugPrint("✅ Exportación web completada exitosamente");
          showMessage('Archivo exportado correctamente');
        } else {
          Directory dir = await getApplicationDocumentsDirectory();
          File file = File('${dir.path}/$fileName');
          await file.writeAsBytes(excelBytes);

          debugPrint("✅ Exportación nativa completada: ${file.path}");
          showMessage('Archivo exportado a: ${file.path}');
        }
      } else {
        debugPrint("❌ Error: No se pudieron generar los bytes del archivo");
        showMessage('Error: No se pudo generar el archivo');
      }
    } catch (e) {
      debugPrint("❌ ERROR EN EXPORTACIÓN: $e");
      showMessage('Error al exportar Excel: $e');
    } finally {
      setExportingState(false);
      debugPrint("🔍 === FIN EXPORTACIÓN EXCEL ===");
    }
  }

  /// ===== MÉTODO 2: Importar Excel - CON DIAGNÓSTICOS =====
  Future<void> importarExcel(
    BuildContext context,
    Map<int, String> variedadesMap,
    Map<String, int> codigoVariedadesMap,
    Function() loadData,
    Function(String message) showMessage,
    Function(bool isImporting) setImportingState,
  ) async {
    debugPrint("🔍 === INICIANDO IMPORTACIÓN EXCEL ===");
    setImportingState(true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        debugPrint("📁 Archivo seleccionado exitosamente");

        // DIAGNÓSTICO DEL ARCHIVO
        _diagnosticarArchivo(result);

        Uint8List? bytes;

        if (kIsWeb) {
          bytes = result.files.first.bytes;
          debugPrint("🌐 Modo web: Bytes obtenidos = ${bytes != null}");
        } else {
          File file = File(result.files.first.path!);
          bytes = await file.readAsBytes();
          debugPrint("📱 Modo nativo: Archivo leído = ${bytes != null}");
        }

        if (bytes != null) {
          debugPrint("💾 Procesando ${bytes.length} bytes...");

          List<Lote> lotesImportados =
              await _procesarExcel(bytes, variedadesMap, codigoVariedadesMap);

          if (lotesImportados.isNotEmpty) {
            debugPrint(
                "✅ ${lotesImportados.length} lotes procesados exitosamente");
            await _mostrarDialogoConfirmacion(context, lotesImportados,
                variedadesMap, codigoVariedadesMap, loadData, showMessage);
          } else {
            debugPrint("⚠️ No se encontraron lotes válidos en el archivo");
            showMessage('No se encontraron lotes para importar en el archivo');
          }
        } else {
          debugPrint("❌ Error: No se pudieron obtener los bytes del archivo");
          showMessage('Error: No se pudo leer el archivo');
        }
      } else {
        debugPrint("❌ Usuario canceló la selección de archivo");
      }
    } catch (e) {
      debugPrint("❌ ERROR EN IMPORTACIÓN: $e");
      debugPrint("📋 Stack trace: ${StackTrace.current}");

      // Verificar si es el error específico de formato personalizado
      if (e is FormatPersonalizadoException) {
        await _mostrarModalSolucionFormato(context);
      } else {
        showMessage('Error al importar Excel: $e');
      }
    } finally {
      setImportingState(false);
      debugPrint("🔍 === FIN IMPORTACIÓN EXCEL ===");
    }
  }

  /// ===== MÉTODO 3: Procesar Excel - CON DIAGNÓSTICOS ROBUSTOS =====
  Future<List<Lote>> _procesarExcel(
    Uint8List bytes,
    Map<int, String> variedadesMap,
    Map<String, int> codigoVariedadesMap,
  ) async {
    List<Lote> lotes = [];

    try {
      debugPrint("📊 Iniciando procesamiento Excel...");

      // ESTRATEGIA MÚLTIPLE DE PROCESAMIENTO
      excel.Excel? excelDoc;
      bool procesamientoExitoso = false;

      // ESTRATEGIA 1: Procesamiento normal
      try {
        debugPrint("🔄 ESTRATEGIA 1: Procesamiento normal...");
        _diagnosticarDecodificacion(bytes);
        excelDoc = excel.Excel.decodeBytes(bytes);
        procesamientoExitoso = true;
        debugPrint("✅ ESTRATEGIA 1: Exitosa");
      } catch (normalError) {
        debugPrint("❌ ESTRATEGIA 1: Falló - $normalError");

        // ESTRATEGIA 2: Procesamiento con manejo de errores de formato
        if (normalError.toString().contains('custom numFmtId')) {
          debugPrint(
              "🔄 ESTRATEGIA 2: Detectado error de formato personalizado");
          debugPrint(
              "💡 Sugerencia: Convertir archivo a formato Excel estándar");

          // Mostrar modal específico al usuario sobre el problema
          throw FormatPersonalizadoException(
              'El archivo Excel contiene formatos de número personalizados que no son compatibles con la importación web.');
        } else {
          // Otros tipos de error
          throw Exception('Error al procesar el archivo Excel: $normalError');
        }
      }

      if (!procesamientoExitoso || excelDoc == null) {
        throw Exception(
            'No se pudo procesar el archivo Excel con ninguna estrategia');
      }

      // PROCESAMIENTO DE DATOS
      if (excelDoc.sheets.isEmpty) {
        debugPrint("❌ El archivo no contiene hojas");
        throw Exception('El archivo no contiene hojas de datos válidas');
      }

      String sheetName = excelDoc.sheets.keys.first;
      var sheet = excelDoc.sheets[sheetName];
      debugPrint("📄 Procesando hoja: $sheetName");

      if (sheet == null) {
        debugPrint("❌ La hoja está vacía o corrupta");
        throw Exception('La hoja de datos está vacía o corrupta');
      }

      int maxRows = sheet.maxRows;
      int maxCols = sheet.maxColumns;
      debugPrint("📏 Dimensiones: $maxRows filas x $maxCols columnas");

      if (maxRows <= 1) {
        debugPrint(
            "❌ El archivo no contiene datos (solo encabezados o está vacío)");
        throw Exception(
            'El archivo no contiene datos. Debe tener al menos una fila de datos además de los encabezados.');
      }

      // LECTURA ROBUSTA DE ENCABEZADOS
      List<String> headers = [];
      for (int col = 0; col < maxCols && col < 50; col++) {
        String cellValue = "";
        try {
          var cell = sheet.cell(
              excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
          if (cell.value != null) {
            cellValue = cell.value.toString().trim();
          }
        } catch (e) {
          debugPrint("⚠️ Error leyendo encabezado columna $col: $e");
          cellValue = ""; // Continuar con valor vacío
        }
        headers.add(cellValue);
      }

      debugPrint("📋 Encabezados encontrados: $headers");

      // MAPEO FLEXIBLE DE COLUMNAS
      Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].isNotEmpty) {
          String headerLower = headers[i]
              .toLowerCase()
              .replaceAll('ó', 'o')
              .replaceAll('á', 'a')
              .replaceAll('é', 'e')
              .replaceAll('í', 'i')
              .replaceAll('ú', 'u')
              .trim();
          columnMap[headerLower] = i;
        }
      }

      debugPrint("🗺️ Mapeo de columnas: $columnMap");

      // VERIFICACIÓN DE COLUMNAS ESENCIALES
      bool tieneCodigoColumn = columnMap.containsKey('codigo') ||
          columnMap.containsKey('código') ||
          columnMap.keys.any((key) => key.contains('codigo'));

      if (!tieneCodigoColumn) {
        debugPrint("❌ ERROR: No se encontró la columna 'Código'");
        debugPrint("📋 Columnas disponibles: ${columnMap.keys.toList()}");
        throw Exception(
            'El archivo no contiene la columna obligatoria "Código".\n\nColumnas encontradas: ${headers.where((h) => h.isNotEmpty).join(", ")}');
      }

      // ENCONTRAR LA COLUMNA DE CÓDIGO ESPECÍFICA
      String codigoKey = columnMap.keys.firstWhere(
        (key) => key == 'codigo' || key == 'código' || key.contains('codigo'),
        orElse: () => '',
      );

      if (codigoKey.isEmpty) {
        throw Exception('No se pudo mapear la columna de código');
      }

      // PROCESAMIENTO ROBUSTO DE FILAS
      debugPrint("🔄 Procesando ${maxRows - 1} filas de datos...");
      int filasExitosas = 0;
      int filasConError = 0;
      int maxFilasProcesar = maxRows > 5000 ? 5000 : maxRows;

      for (int rowIndex = 1; rowIndex < maxFilasProcesar; rowIndex++) {
        try {
          Map<String, String> rowData = {};

          // LECTURA SEGURA DE DATOS
          for (var colName in columnMap.keys) {
            int colIndex = columnMap[colName]!;
            String cellValue = "";

            try {
              var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
                  columnIndex: colIndex, rowIndex: rowIndex));

              if (cell.value != null) {
                // MANEJO SEGURO DE DIFERENTES TIPOS DE VALORES
                var value = cell.value;
                if (value is excel.TextCellValue) {
                  cellValue = value.value.toString().trim();
                } else if (value is excel.IntCellValue) {
                  cellValue = value.value.toString().trim();
                } else if (value is excel.DoubleCellValue) {
                  cellValue = value.value.toString().trim();
                } else if (value is excel.DateCellValue) {
                  // DateCellValue no tiene getter 'value', usar toString()
                  cellValue = value.toString().trim();
                } else {
                  cellValue = value.toString().trim();
                }
              }
            } catch (cellError) {
              debugPrint(
                  "⚠️ Error leyendo celda [$rowIndex,$colIndex]: $cellError");
              cellValue = ""; // Continuar con valor vacío
            }

            rowData[colName] = cellValue;
          }

          // PROCESAMIENTO DE CÓDIGO
          String codigo = rowData[codigoKey] ?? "";
          if (codigo.isEmpty) {
            debugPrint("⚠️ Fila $rowIndex: Código vacío, saltando...");
            continue;
          }

          // PROCESAMIENTO SEGURO DE OTROS CAMPOS
          String canteros = rowData['canteros'] ?? "";

          String cantidadStr = rowData['cantidad'] ?? "0";
          cantidadStr = cantidadStr.replaceAll(RegExp(r'[^\d]'), '');
          int cantidad = int.tryParse(cantidadStr) ?? 0;

          String idVariedadStr = rowData['idvariedad'] ??
              rowData['id variedad'] ??
              rowData['id_variedad'] ??
              rowData['variedad_id'] ??
              "0";
          idVariedadStr = idVariedadStr.replaceAll(RegExp(r'[^\d]'), '');
          int? idVariedad = int.tryParse(idVariedadStr);

          String variedadStr = rowData['variedad'] ?? "";

          // MAPEO DE VARIEDAD
          if (idVariedad != null && variedadStr.isEmpty) {
            if (variedadesMap.containsKey(idVariedad)) {
              variedadStr = variedadesMap[idVariedad]!;
            }
          } else if (idVariedad == null && variedadStr.isNotEmpty) {
            var entrada = variedadesMap.entries.firstWhere(
              (entry) => entry.value.toLowerCase() == variedadStr.toLowerCase(),
              orElse: () => const MapEntry(-1, ''),
            );

            if (entrada.key != -1) {
              idVariedad = entrada.key;
            }
          }

          String contenedor = rowData['contenedor'] ?? "";
          String grower = rowData['grower'] ?? "";
          String casa = rowData['casa'] ?? "";

          String estadoStr =
              rowData['estado'] ?? rowData['estatus'] ?? "Activo";
          int estatus = estadoStr.toLowerCase().contains('activ') ? 1 : 0;

          // CREAR LOTE
          Lote lote = Lote(
            pmlt_codigo: codigo,
            pmlt_canteros: canteros.isNotEmpty ? canteros : null,
            pmlt_cantidad: cantidad,
            pmlt_estatus: estatus,
            pmlt_idvariedad: idVariedad,
            pmlt_variedad: variedadStr.isNotEmpty ? variedadStr : null,
            pmlt_contenedor: contenedor.isNotEmpty ? contenedor : null,
            pmlt_grower: grower.isNotEmpty ? grower : null,
            pmlt_casa: casa.isNotEmpty ? casa : null,
            pmlt_creadopor: 1,
            pmlt_fechacreacion: DateTime.now(),
          );

          lotes.add(lote);
          filasExitosas++;

          if (rowIndex <= 5) {
            // Log de las primeras 5 filas para diagnóstico
            debugPrint(
                "✅ Fila $rowIndex procesada: Código=$codigo, Cantidad=$cantidad, Variedad=$variedadStr");
          }
        } catch (e) {
          filasConError++;
          debugPrint("❌ Error procesando fila $rowIndex: $e");
          // Continuar con la siguiente fila
        }
      }

      debugPrint("📊 Resumen procesamiento:");
      debugPrint("   - Filas exitosas: $filasExitosas");
      debugPrint("   - Filas con error: $filasConError");
      debugPrint("   - Total lotes creados: ${lotes.length}");

      if (lotes.isEmpty) {
        throw Exception(
            'No se pudieron procesar datos válidos del archivo. Verifique que el archivo contenga datos en el formato correcto.');
      }
    } catch (e) {
      debugPrint("❌ ERROR CRÍTICO procesando Excel: $e");
      debugPrint("📋 Stack trace: ${StackTrace.current}");
      throw Exception('$e');
    }

    // DIAGNÓSTICO DE PROCESAMIENTO
    _diagnosticarProcesamiento(lotes);

    return lotes;
  }

  /// ===== MÉTODO 4: Mostrar Diálogo de Confirmación - CON DIAGNÓSTICOS =====
  Future<void> _mostrarDialogoConfirmacion(
    BuildContext context,
    List<Lote> lotes,
    Map<int, String> variedadesMap,
    Map<String, int> codigoVariedadesMap,
    Function() loadData,
    Function(String message) showMessage,
  ) async {
    debugPrint("🔍 === MOSTRANDO DIÁLOGO DE CONFIRMACIÓN ===");
    debugPrint("📋 Lotes para confirmar: ${lotes.length}");

    const Color primaryColor = Color(0xFF1E73BB);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Importación'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se encontraron ${lotes.length} lotes para importar.'),
              const SizedBox(height: 16),
              const Text(
                'Vista previa (primeros 5 registros):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Cantidad')),
                        DataColumn(label: Text('IDVariedad')),
                        DataColumn(label: Text('Variedad')),
                        DataColumn(label: Text('Grower')),
                      ],
                      rows: lotes.take(5).map((lote) {
                        return DataRow(cells: [
                          DataCell(Text(lote.pmlt_codigo ?? '-')),
                          DataCell(Text(lote.pmlt_cantidad?.toString() ?? '0')),
                          DataCell(
                              Text(lote.pmlt_idvariedad?.toString() ?? '-')),
                          DataCell(Text(lote.pmlt_variedad ?? '-')),
                          DataCell(Text(lote.pmlt_grower ?? '-')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nota: Solo se importarán los lotes que no existan previamente con el mismo código.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint("❌ Usuario canceló la importación");
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              debugPrint("✅ Usuario confirmó la importación");
              Navigator.pop(context);
              await _confirmarImportacion(lotes, variedadesMap,
                  codigoVariedadesMap, loadData, showMessage);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: const Color.fromARGB(255, 250, 250, 250),
            ),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  /// ===== MÉTODO 5: Confirmar Importación - CON DIAGNÓSTICOS =====
  Future<void> _confirmarImportacion(
    List<Lote> lotes,
    Map<int, String> variedadesMap,
    Map<String, int> codigoVariedadesMap,
    Function() loadData,
    Function(String message) showMessage,
  ) async {
    debugPrint("🔍 === CONFIRMANDO IMPORTACIÓN ===");
    debugPrint("📊 Procesando ${lotes.length} lotes para importación...");

    try {
      // Procesar variedades antes de enviar
      int lotesConVariedadCorregida = 0;

      for (var lote in lotes) {
        if (lote.pmlt_idvariedad != null &&
            (lote.pmlt_variedad == null || lote.pmlt_variedad!.isEmpty)) {
          String codigoStr = lote.pmlt_idvariedad.toString();
          if (codigoVariedadesMap.containsKey(codigoStr)) {
            int variedadId = codigoVariedadesMap[codigoStr]!;
            lote.pmlt_variedad = variedadesMap[variedadId];
            lotesConVariedadCorregida++;
            debugPrint(
                "🔧 Variedad corregida para lote ${lote.pmlt_codigo}: ID=${lote.pmlt_idvariedad} -> ${lote.pmlt_variedad}");
          } else if (variedadesMap.containsKey(lote.pmlt_idvariedad)) {
            lote.pmlt_variedad = variedadesMap[lote.pmlt_idvariedad];
            lotesConVariedadCorregida++;
          }
        } else if ((lote.pmlt_idvariedad == null ||
                lote.pmlt_idvariedad == 0) &&
            lote.pmlt_variedad != null &&
            lote.pmlt_variedad!.isNotEmpty) {
          var entry = variedadesMap.entries.firstWhere(
            (entry) =>
                entry.value.toLowerCase() == lote.pmlt_variedad!.toLowerCase(),
            orElse: () => const MapEntry(-1, ''),
          );

          if (entry.key != -1) {
            lote.pmlt_idvariedad = entry.key;
            lotesConVariedadCorregida++;
            debugPrint(
                "🔧 ID Variedad corregido para lote ${lote.pmlt_codigo}: ${lote.pmlt_variedad} -> ID=${lote.pmlt_idvariedad}");
          }
        }
      }

      debugPrint("📊 Lotes con variedad corregida: $lotesConVariedadCorregida");
      debugPrint("🚀 Enviando lotes al servicio...");

      final stopwatch = Stopwatch()..start();
      final resultado = await _loteService.importarLotes(lotes);
      stopwatch.stop();

      debugPrint(
          "⏱️ Tiempo de importación al servidor: ${stopwatch.elapsedMilliseconds}ms");
      debugPrint(
          "✅ Resultado de importación: ${resultado.creados} lotes creados");

      await loadData();
      debugPrint("🔄 Datos recargados exitosamente");

      showMessage('Se importaron ${resultado.creados} lotes correctamente.');
      debugPrint("🎉 IMPORTACIÓN COMPLETADA EXITOSAMENTE");
    } catch (e) {
      debugPrint("❌ ERROR EN CONFIRMACIÓN DE IMPORTACIÓN: $e");
      debugPrint("📋 Stack trace: ${StackTrace.current}");
      showMessage('Error al importar lotes: $e');
    }
  }
}
