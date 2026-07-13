/// Tope de caracteres del thumbnail pergamino. Por encima, el pergamino
/// cortaría el texto (ver `ParchmentImageGenerator`), así que la nota se
/// comparte como PDF paginado en vez de la imagen.
const int kNoteParchmentMaxChars = 1500;

/// Formato con el que se comparte una nota según su longitud.
enum NoteShareFormat {
  /// Imagen pergamino (JPG). La nota entra completa en una sola imagen.
  parchmentImage,

  /// PDF paginado del texto completo. La imagen cortaría, el PDF se pagina solo.
  paginatedPdf,
}

/// Decide con qué formato compartir una nota según su longitud.
///
/// `<= kNoteParchmentMaxChars` → imagen pergamino (como el thumbnail).
/// `>  kNoteParchmentMaxChars` → PDF paginado del texto completo.
NoteShareFormat noteShareFormatFor(String noteContent) {
  return noteContent.length > kNoteParchmentMaxChars
      ? NoteShareFormat.paginatedPdf
      : NoteShareFormat.parchmentImage;
}
