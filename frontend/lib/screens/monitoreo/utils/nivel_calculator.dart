class NivelCalculator {
  // Método para calcular el nivel automático basado en el valor de muestra y los límites
  static int calcularNivelAutomatico(
      int? valorMuestra, int? limiteNivel1, int? limiteNivel2) {
    if (valorMuestra == null) return 0;

    if (valorMuestra >= 0 && valorMuestra <= (limiteNivel1 ?? 10)) {
      return 1;
    } else if (valorMuestra > (limiteNivel1 ?? 10) &&
        valorMuestra <= (limiteNivel2 ?? 20)) {
      return 2;
    } else if (valorMuestra > (limiteNivel2 ?? 20)) {
      return 3;
    } else {
      return 0;
    }
  }
}
