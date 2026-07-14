/// Ajustes de texto puros para el render del pergamino (sin Flutter).
///
/// OJO: solo transforman el texto que se DIBUJA en la imagen; el contenido
/// guardado de la nota nunca se toca.
class ParchmentText {
  ParchmentText._();

  // Corridas de letras (unicode → cubre acentos y Ñ). Los números, espacios y
  // signos quedan afuera del match, así se preservan tal cual.
  static final RegExp _letterRun = RegExp(r'\p{L}+', unicode: true);

  /// Convierte a "Capitalizada" cada palabra escrita ENTERAMENTE en mayúscula
  /// (incluidos acrónimos como DNI → Dni), dejando el resto del texto intacto.
  ///
  /// En letra cursiva ligada una palabra toda en mayúscula se ve horrible; esto
  /// la suaviza solo para la imagen. Palabras con minúsculas, números y signos
  /// no se tocan.
  static String softenAllCaps(String text) {
    return text.replaceAllMapped(_letterRun, (m) {
      final run = m.group(0)!;
      final isAllUpper =
          run == run.toUpperCase() && run != run.toLowerCase();
      if (!isAllUpper) return run;
      return run[0].toUpperCase() + run.substring(1).toLowerCase();
    });
  }
}
