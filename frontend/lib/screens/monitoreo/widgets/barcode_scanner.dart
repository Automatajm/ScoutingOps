import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../utils/constants.dart';

// Solo importar dart:js en web
import 'dart:js' as js if (dart.library.js) 'dart:js';

class BarcodeScanner {
  static bool get isWeb => kIsWeb;
  static bool _isInitialized = false;

  // ✅ INICIALIZACIÓN UNA SOLA VEZ
  static void _initializeIfNeeded() {
    if (!_isInitialized && isWeb) {
      try {
        // Verificar que el JavaScript esté disponible
        if (js.context.hasProperty('startWebBarcodeScanner')) {
          _isInitialized = true;
          print('✅ Escáner JavaScript disponible');
        } else {
          print('⚠️ JavaScript del escáner no disponible');
        }
      } catch (e) {
        print('❌ Error verificando JavaScript: $e');
      }
    }
  }

  // ✅ MÉTODO PRINCIPAL - FIXED
  static Future<String?> scanBarcode(BuildContext context) async {
    if (!isWeb) {
      return await _showManualEntryDirect(context);
    }

    _initializeIfNeeded();

    if (!_isInitialized) {
      print('❌ JavaScript no disponible, usando entrada manual');
      return await _showManualEntryDirect(context);
    }

    final completer = Completer<String?>();
    bool completed = false;

    try {
      print('🚀 Iniciando escáner web...');

      // ✅ CALLBACK MEJORADO CON VERIFICACIONES
      final callback = js.allowInterop((String code) {
        print('📨 Código recibido: $code');

        if (!completed) {
          completed = true;
          if (!completer.isCompleted) {
            completer.complete(code);
          }
        }
      });

      // ✅ TIMEOUT PARA EVITAR HANGS
      Timer(Duration(seconds: 60), () {
        if (!completed) {
          completed = true;
          print('⏰ Timeout del escáner');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });

      // ✅ VERIFICAR Y LIMPIAR ANTES DE INICIAR
      try {
        js.context.callMethod('cleanupBarcodeScanner');
      } catch (e) {
        // Ignorar errores de limpieza
      }

      // ✅ REGISTRAR CALLBACK
      js.context.callMethod('setBarcodeCallback', [callback]);

      // ✅ INICIAR ESCÁNER
      js.context.callMethod('startWebBarcodeScanner');

      print('⏳ Esperando resultado del escáner...');

      // Esperar resultado
      final result = await completer.future;

      if (result != null && result.isNotEmpty) {
        print('✅ Código escaneado exitosamente: $result');
        return result;
      } else {
        print('⚠️ Escáner cancelado o sin resultado');
        return null;
      }
    } catch (e) {
      print('❌ Error en escáner web: $e');

      // Fallback a entrada manual
      return await _showManualEntryDirect(context);
    }
  }

  // ✅ ENTRADA MANUAL MEJORADA
  static Future<String?> _showManualEntryDirect(BuildContext context) async {
    final TextEditingController codeController = TextEditingController();
    String? result;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.edit, color: MonitoreoStyles.accentColor),
            SizedBox(width: 8),
            Text('Código de Lote', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingrese el código del lote:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 20),

              // Campo de entrada mejorado
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: codeController,
                  autofocus: true,
                  keyboardType:
                      TextInputType.text, // Permitir cualquier entrada
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Código del lote',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    prefixIcon: Icon(Icons.qr_code_scanner,
                        color: MonitoreoStyles.accentColor),
                    helperText: 'Código exacto del lote',
                    helperStyle: TextStyle(fontSize: 12),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      result = value.trim();
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                ),
              ),

              SizedBox(height: 16),

              // Instrucciones
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escriba el código exactamente como aparece en la etiqueta',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                result = code;
                Navigator.of(dialogContext).pop(true);
              } else {
                // Hacer vibrar el campo si está vacío
                codeController.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MonitoreoStyles.accentColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return (confirmed == true) ? result : null;
  }

  // ✅ LIMPIEZA MEJORADA
  static void cleanupScanner() {
    if (isWeb && _isInitialized) {
      try {
        js.context.callMethod('cleanupBarcodeScanner');
        print('🧹 Escáner limpiado');
      } catch (e) {
        print('⚠️ Error limpiando escáner: $e');
      }
    }
  }

  // ✅ WIDGET BOTÓN PRINCIPAL
  static Widget buildScanButton({
    required BuildContext context,
    required Function(String) onCodeDetected,
    String? label,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
  }) {
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          final code = await scanBarcode(context);
          if (code != null && code.isNotEmpty) {
            onCodeDetected(code);
          }
        } catch (e) {
          print('❌ Error en botón escáner: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al abrir escáner: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      icon: Icon(
        icon ?? Icons.qr_code_scanner,
        color: textColor ?? Colors.white,
      ),
      label: Text(
        label ?? 'Escanear Código',
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? MonitoreoStyles.accentColor,
        padding: padding ?? EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }

  // ✅ WIDGET BOTÓN ICONO
  static Widget buildScanIconButton({
    required BuildContext context,
    required Function(String) onCodeDetected,
    double? size,
    Color? color,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (color ?? MonitoreoStyles.accentColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () async {
          try {
            final code = await scanBarcode(context);
            if (code != null && code.isNotEmpty) {
              onCodeDetected(code);
            }
          } catch (e) {
            print('❌ Error en botón escáner: $e');
          }
        },
        icon: Icon(Icons.qr_code_scanner),
        iconSize: size ?? 28,
        color: color ?? MonitoreoStyles.accentColor,
        tooltip: tooltip ?? 'Escanear código de lote',
        padding: EdgeInsets.all(12),
      ),
    );
  }

  // ✅ VERIFICACIÓN DE DISPONIBILIDAD
  static bool get isAvailable {
    if (!isWeb) return false;

    try {
      return js.context.hasProperty('startWebBarcodeScanner');
    } catch (e) {
      return false;
    }
  }

  // ✅ FUNCIÓN DE TEST
  static void testScanner() {
    if (kDebugMode && isWeb) {
      try {
        final result = js.context.callMethod('testBarcodeScanner');
        print('🧪 Test resultado: $result');
      } catch (e) {
        print('❌ Error en test: $e');
      }
    }
  }

  // ✅ INFORMACIÓN DE DEBUG
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isWeb': isWeb,
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'userAgent': isWeb ? js.context['navigator']['userAgent'] : 'N/A',
      'hasHTTPS':
          isWeb ? js.context['location']['protocol'] == 'https:' : false,
    };
  }
}
