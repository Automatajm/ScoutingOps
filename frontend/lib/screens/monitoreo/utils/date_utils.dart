import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonitoreoDateUtils {
  // Formatea una fecha para visualización
  static String formatDate(DateTime? date, {String format = 'dd/MM/yyyy'}) {
    if (date == null) return '-';
    return DateFormat(format).format(date);
  }

  // Función para obtener rango de fechas seguro
  static DateTimeRange getSafeDateRange() {
    final DateTime now = DateTime.now();
    final DateTime oneMonthAgo = now.subtract(const Duration(days: 30));

    return DateTimeRange(
      start: oneMonthAgo,
      end: now,
    );
  }
}
