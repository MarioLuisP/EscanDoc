# Plan: Feature Nueva Nota

**Fecha:** Feb 2026
**Estado:** Pendiente (depende de 48_plan-simplificacion-db.md)

---

## Concepto

Una nota sin documento escaneado. El usuario crea texto libre (con voz o teclado)
y la app genera un JPG estilo pergamino con el contenido en letra cursiva.
Ese JPG es el `file_path` del registro — aparece en la lista como cualquier documento.

**Filosofía:** EscanDoc reemplaza el block de notas. Sin apps extra.

---

## Dependencias previas

- DB simplification (48_plan-simplificacion-db.md) debe estar hecha:
  - Campo `document_type TEXT` en tabla `documents`
  - Campo `note_content TEXT` en tabla `documents`
  - `document_type = 'nota'` identifica estas entradas

---

## Flujo de usuario

```
Botón (···) en home → sheet → "Nueva nota"
  ↓
NoteEditorPage (ya existe, con voz)
  ↓ guardar
Generar JPG pergamino con el texto
  ↓
Guardar documento: title=auto, file_path=jpg, document_type='nota', note_content=texto
  ↓
Aparece en lista con chip "Nota" y thumbnail pergamino
```

---

## Entrada al flujo

`home_page.dart` — `_showActionsMenu()` → `onNewNote`:
- Navegar a `NoteEditorPage` con argumento `isNewNote: true` (sin documentId)
- Al guardar: llamar al nuevo servicio de generación + `DocumentRepository.create()`

---

## Generador de imagen pergamino

### Técnica: Widget off-screen → imagen

```dart
// ParchmentImageGenerator.generate(String text) → Future<File>
// 1. Construir widget pergamino
// 2. Capturar con RepaintBoundary + renderObject.toImage(pixelRatio)
// 3. Comprimir con flutter_image_compress → JPG ~150-200KB
// 4. Guardar en directorio de documentos de la app
```

### Dimensiones
- 600 × 848 px (A4 proporcional, ~72dpi)
- Compresión quality: 85

### Diseño visual del pergamino

**Fondo:**
- Gradiente `Color(0xFFFDF8ED)` → `Color(0xFFEEDFBE)` (crema cálido)
- Sombra interna sutil para textura de papel viejo
- Borde: radio 8px, color sepia `Color(0xFFBFA882)` 1.5px
- Sombra exterior: `Color(0xFF8B6914).withOpacity(0.3)`, offset (0,6), blur 12

**Texto:**
- Fuente: **Caveat** (Google Fonts, ~150KB, muy legible en cursiva)
  - Alternativa: Dancing Script (más ornamental)
- Color: `Color(0xFF3D2B1F)` (sepia oscuro)
- Tamaño base: 28px
- Si texto > 800 chars: reducir a 22px
- Si texto > 1500 chars: reducir a 18px y truncar con "…"
- Padding interno: 40px todos los lados
- Interlineado: 1.8

**Líneas de renglón (opcional):**
- Líneas horizontales cada ~45px
- Color `Color(0xFFD4B896).withOpacity(0.4)` (muy sutil)

**Título automático:**
- Primeras 4-5 palabras del texto como título del documento
- Si texto vacío: "Nota {fecha}" ej. "Nota 24 feb"

### Archivo de salida
- Path: `{appDocumentsDir}/nota_{timestamp}.jpg`
- Mismo directorio que los documentos escaneados

---

## Cambios en NoteEditorPage

- Detectar si viene con `isNewNote: true` (sin documentId)
- En `_saveNote()`: si `isNewNote` → llamar `ParchmentImageGenerator.generate()` + crear documento
- Si viene de documento existente: comportamiento actual sin cambios

---

## Cambios en DocumentRepository

- Método `createNoteDocument({title, filePath, noteContent})`:
  - Inserta con `document_type = 'nota'`
  - `note_content = texto`
  - `file_path = path del jpg generado`

---

## Cambios en DocumentDetailPage

- Si `document.documentType == 'nota'`:
  - El JPG pergamino es el preview (ya funciona con `Image.file`)
  - La sección "Nota" muestra `note_content` editable normalmente
  - Sección OCR oculta (no aplica para notas)

---

## Fuente Caveat — setup

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Caveat
      fonts:
        - asset: assets/fonts/Caveat-Regular.ttf
        - asset: assets/fonts/Caveat-Bold.ttf
          weight: 700
```

Descargar de: fonts.google.com/specimen/Caveat
Tamaño aprox: Regular 148KB + Bold 148KB = ~300KB total

---

## Archivos a crear

- `lib/features/notes/domain/services/parchment_image_generator.dart`

## Archivos a modificar

- `lib/features/notes/presentation/pages/note_editor_page.dart`
- `lib/features/documents/data/repositories/document_repository.dart`
- `lib/features/documents/presentation/pages/document_detail_page.dart`
- `pubspec.yaml`
- `assets/fonts/` — agregar Caveat-Regular.ttf y Caveat-Bold.ttf

---

## Orden de trabajo

1. DB simplification completada (ver 48_)
2. Descargar y declarar fuente Caveat en pubspec.yaml
3. Crear `ParchmentImageGenerator`
4. Agregar `createNoteDocument()` en repository
5. Modificar `NoteEditorPage` → rama `isNewNote`
6. Modificar `DocumentDetailPage` → ocultar OCR si nota
7. Conectar botón "Nueva nota" en `home_page.dart`
8. Probar: crear nota → thumbnail pergamino en lista → abrir detail → editar nota

---

## Decisiones pendientes

- ¿Fuente Caveat o Dancing Script? Caveat: más legible. Dancing Script: más ornamental.
- ¿Líneas de renglón sí o no? (detalle estético, decidir al implementar)
- ¿Truncar texto largo o multi-página? Recomendación: truncar con "…" en la imagen,
  el texto completo siempre está en `note_content` — la imagen es solo el thumbnail.
