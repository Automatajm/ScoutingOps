import 'package:flutter/material.dart';

class MonitoreoStyles {
  // Colores del tema
  static const Color primaryColor = Color(0xFF1E73BB);
  static const Color accentColor = Color(0xFF00A99D);
  static const Color backgroundColor = Colors.white;
  static const Color lightGrey = Color(0xFFF5F5F5);
}

/// Clase para parsear rangos de canteros (ej: "4-8", "5", "1-3,5-7")
class CanteroRangeParser {
  final bool isValid;
  final String? error;
  final int inicio;
  final int fin;
  final int total;
  final bool isSingleCantero;
  final String? normalizedRange;

  CanteroRangeParser._({
    required this.isValid,
    this.error,
    required this.inicio,
    required this.fin,
    required this.total,
    required this.isSingleCantero,
    this.normalizedRange,
  });

  /// Parsea un string de rango de canteros
  /// Formatos válidos:
  /// - "5" → cantero único
  /// - "4-8" → rango de 4 a 8
  /// - "1-3,5-7" → múltiples rangos (se toma solo el primero)
  static CanteroRangeParser parse(String range) {
    if (range.isEmpty) {
      return CanteroRangeParser._(
        isValid: false,
        error: 'Rango vacío',
        inicio: 0,
        fin: 0,
        total: 0,
        isSingleCantero: false,
      );
    }

    final trimmed = range.trim();
    
    // Si contiene comas, tomar solo el primer rango
    String firstRange = trimmed;
    if (trimmed.contains(',')) {
      firstRange = trimmed.split(',').first.trim();
    }

    // Verificar si es un solo número
    if (!firstRange.contains('-')) {
      final numero = int.tryParse(firstRange);
      if (numero == null || numero <= 0) {
        return CanteroRangeParser._(
          isValid: false,
          error: 'Número de cantero inválido: $firstRange',
          inicio: 0,
          fin: 0,
          total: 0,
          isSingleCantero: false,
        );
      }
      
      return CanteroRangeParser._(
        isValid: true,
        inicio: numero,
        fin: numero,
        total: 1,
        isSingleCantero: true,
        normalizedRange: numero.toString(),
      );
    }

    // Es un rango (ej: "4-8")
    final parts = firstRange.split('-');
    if (parts.length != 2) {
      return CanteroRangeParser._(
        isValid: false,
        error: 'Formato de rango inválido: $firstRange',
        inicio: 0,
        fin: 0,
        total: 0,
        isSingleCantero: false,
      );
    }

    final inicio = int.tryParse(parts[0].trim());
    final fin = int.tryParse(parts[1].trim());

    if (inicio == null || fin == null) {
      return CanteroRangeParser._(
        isValid: false,
        error: 'Números de rango inválidos: $firstRange',
        inicio: 0,
        fin: 0,
        total: 0,
        isSingleCantero: false,
      );
    }

    if (inicio <= 0 || fin <= 0) {
      return CanteroRangeParser._(
        isValid: false,
        error: 'Los canteros deben ser mayores a 0',
        inicio: 0,
        fin: 0,
        total: 0,
        isSingleCantero: false,
      );
    }

    if (inicio > fin) {
      return CanteroRangeParser._(
        isValid: false,
        error: 'El cantero inicial debe ser menor o igual al final',
        inicio: 0,
        fin: 0,
        total: 0,
        isSingleCantero: false,
      );
    }

    final total = fin - inicio + 1;

    return CanteroRangeParser._(
      isValid: true,
      inicio: inicio,
      fin: fin,
      total: total,
      isSingleCantero: inicio == fin,
      normalizedRange: '$inicio-$fin',
    );
  }

  /// Obtiene una lista de todos los canteros en el rango
  List<int> getCanteros() {
    if (!isValid) return [];
    return List.generate(total, (i) => inicio + i);
  }

  @override
  String toString() {
    if (!isValid) return 'Invalid: $error';
    if (isSingleCantero) return 'Cantero $inicio';
    return 'Rango $inicio-$fin ($total canteros)';
  }
}