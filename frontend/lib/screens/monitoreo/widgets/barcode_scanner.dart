import 'dart:async';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

/// Widget para escanear códigos de barras usando JavaScript/OCR
/// 
/// Este widget llama a las funciones JavaScript definidas en barcode_scanner_v2.js:
/// - window.startWebBarcodeScanner() - Abre el escáner OCR
/// - window.setBarcodeCallback(callback) - Registra callback para recibir código
/// - window.cleanupBarcodeScanner() - Limpia recursos del escáner
class BarcodeScanner {
  BarcodeScanner._();

  /// Escanear código de barras con OCR JavaScript
  /// 
  /// Retorna el código escaneado o null si se cancela
  static Future<String?> scanBarcode(BuildContext context) async {
    debugPrint('📷 BarcodeScanner.scanBarcode iniciado');
    
    // Completer para esperar el resultado del JavaScript
    final Completer<String?> completer = Completer<String?>();
    
    try {
      // Verificar que las funciones JavaScript existen
      if (!_checkJavaScriptAvailable()) {
        debugPrint('❌ JavaScript del escáner no disponible');
        _showManualEntryFallback(context, completer);
        return completer.future;
      }
      
      debugPrint('✅ JavaScript del escáner disponible');
      
      // Registrar callback para recibir el código desde JavaScript
      js.context.callMethod('setBarcodeCallback', [
        js.allowInterop((String? code) {
          debugPrint('✅ Código recibido desde JavaScript: $code');
          if (!completer.isCompleted) {
            completer.complete(code);
          }
        })
      ]);
      
      // Iniciar escáner OCR de JavaScript
      debugPrint('🚀 Llamando a startWebBarcodeScanner()');
      js.context.callMethod('startWebBarcodeScanner');
      
      // Esperar resultado con timeout de 5 minutos
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('⏰ Timeout del escáner');
          _cleanupScanner();
          return null;
        },
      );
      
      debugPrint('📤 Retornando resultado: $result');
      return result;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error en scanBarcode: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (!completer.isCompleted) {
        _showManualEntryFallback(context, completer);
      }
      
      return completer.future;
    }
  }
  
  /// Verificar si las funciones JavaScript están disponibles
  static bool _checkJavaScriptAvailable() {
    try {
      // Verificar que window.startWebBarcodeScanner existe
      final hasStartScanner = js.context.hasProperty('startWebBarcodeScanner');
      final hasSetCallback = js.context.hasProperty('setBarcodeCallback');
      final hasCleanup = js.context.hasProperty('cleanupBarcodeScanner');
      
      debugPrint('📋 Funciones JavaScript:');
      debugPrint('  - startWebBarcodeScanner: $hasStartScanner');
      debugPrint('  - setBarcodeCallback: $hasSetCallback');
      debugPrint('  - cleanupBarcodeScanner: $hasCleanup');
      
      return hasStartScanner && hasSetCallback && hasCleanup;
    } catch (e) {
      debugPrint('❌ Error verificando JavaScript: $e');
      return false;
    }
  }
  
  /// Limpiar recursos del escáner JavaScript
  static void _cleanupScanner() {
    try {
      if (js.context.hasProperty('cleanupBarcodeScanner')) {
        js.context.callMethod('cleanupBarcodeScanner');
        debugPrint('🧹 Escáner JavaScript limpiado');
      }
    } catch (e) {
      debugPrint('⚠️ Error limpiando escáner: $e');
    }
  }
  
  /// Mostrar entrada manual como fallback
  static void _showManualEntryFallback(
    BuildContext context,
    Completer<String?> completer,
  ) {
    debugPrint('⚠️ Mostrando entrada manual como fallback');
    
    if (!context.mounted) {
      completer.complete(null);
      return;
    }
    
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _ManualEntryDialog(),
    ).then((code) {
      if (!completer.isCompleted) {
        completer.complete(code);
      }
    });
  }
}

/// Dialog para entrada manual de código
class _ManualEntryDialog extends StatefulWidget {
  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) {
      Navigator.of(context).pop(code);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard, color: Colors.blue),
          SizedBox(width: 12),
          Text('Entrada Manual'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ JavaScript no disponible, usando entrada manual',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Código del lote',
              hintText: 'Ejemplo: 16318',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Escriba el código exacto de la etiqueta',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('Enviar'),
        ),
      ],
    );
  }
}