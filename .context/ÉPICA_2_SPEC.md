
# EscanDoc - Historias de Usuario MVP (v1.1)

**Fecha:** 24 de Enero 2026  
**Versión:** 1.1 - Actualizada según ADDS.md v1.1  
**Total Historias:** 14 (3 eliminadas del v1.0)

---

## USUARIO PRIMARIO
**Persona mayor (60-85 años), no tech-savvy**
---

## ÉPICA 2: NOTES (Feature 2 - Vinculación)
**Prioridad:** ALTA

### HU-004: Agregar nota a documento
**Prioridad:** ALTA

**Como** persona mayor  
**Quiero** agregar una nota "Pagar antes del 15"  
**Para** recordar qué hacer con ese documento  

**Criterios de Aceptación:**
- [ ] Botón "AGREGAR NOTA" visible en pantalla detalle
- [ ] Abre editor simple: campo título + campo contenido
- [ ] Teclado aparece automáticamente en campo título
- [ ] Campos con fuente 18sp (legible)
- [ ] Botones "GUARDAR" y "CANCELAR" grandes (mínimo 120x60 dp)
- [ ] Al guardar, vuelve a pantalla detalle mostrando nota
- [ ] Nota vinculada a documento (relación 1:1 por ahora)
- [ ] Texto de nota visible en pantalla detalle
- [ ] Si ya tiene nota, botón cambia a "EDITAR NOTA"

---




# ÉPICA 2 - NOTES: Especificación de Desarrollo

**Fecha:** 24 de Enero 2026  
**Versión:** 1.0  
**Historias:** HU-004

---

## OBJETIVO DE LA ÉPICA

Implementar sistema de notas vinculadas a documentos (relación 1:1). Permite a usuarios agregar contexto textual a documentos escaneados sin complejidad.

**Dependencia:** Requiere Épica 1 (Documents) completada.

---

## HISTORIAS DE USUARIO

### HU-004: Agregar nota a documento
**Prioridad:** ALTA

**Criterios clave:**
- Botón "AGREGAR NOTA" visible en detalle de documento
- Editor simple: título + contenido (texto plano)
- Teclado automático en campo título
- Botones grandes (GUARDAR/CANCELAR 120x60dp)
- Nota se muestra en pantalla detalle después de guardar
- Si ya tiene nota: botón cambia a "EDITAR NOTA"

---

## CONTRATO DE TESTS

### PASO 1: Domain (UseCases)

**Tests unitarios requeridos:**

```
test/features/notes/domain/usecases/

├── create_note_test.dart
│   ├── ✓ Debe crear nota y vincularla a documento
│   ├── ✓ Debe retornar nota creada con ID
│   ├── ✓ Debe fallar si título está vacío
│   └── ✓ Debe fallar si documento no existe
│
├── update_note_test.dart
│   ├── ✓ Debe actualizar nota existente
│   ├── ✓ Debe retornar nota actualizada
│   └── ✓ Debe fallar si nota no existe
│
├── get_note_by_document_test.dart
│   ├── ✓ Debe retornar nota vinculada a documento
│   ├── ✓ Debe retornar null si no tiene nota
│   └── ✓ Debe manejar error de BD
│
└── delete_note_test.dart
    ├── ✓ Debe eliminar nota correctamente
    ├── ✓ Debe eliminar vinculación en document_notes
    └── ✓ Debe retornar false si nota no existe
```

**Cobertura mínima Domain:** 100%

---

### PASO 2: Data (Repository)

**Tests de integración requeridos:**

```
test/features/notes/data/repositories/

└── note_repository_test.dart
    ├── ✓ Debe insertar nota en BD
    ├── ✓ Debe insertar vinculación en document_notes
    ├── ✓ Debe recuperar nota por documento_id
    ├── ✓ Debe actualizar contenido de nota
    ├── ✓ Debe eliminar nota y vinculación (CASCADE)
    └── ✓ Debe retornar null si documento no tiene nota
```

**Nota:** Validar que CASCADE funciona en document_notes

---

### PASO 3: Presentation (Provider)

**Tests de provider (opcional para MVP):**

```
test/features/notes/presentation/providers/

└── note_provider_test.dart
    ├── ✓ Debe crear nota y notificar listeners
    ├── ✓ Debe cargar nota existente
    ├── ✓ Debe actualizar nota existente
    └── ✓ Debe manejar estados de loading
```

**Cobertura mínima Provider:** 80% (opcional)

---

## ORDEN DE IMPLEMENTACIÓN (TDD)

### PASO 1: Domain Layer

**Objetivo:** Lógica de notas sin Flutter

**Artefactos a crear:**
```
lib/features/notes/domain/usecases/
├── create_note.dart
├── update_note.dart
├── get_note_by_document.dart
└── delete_note.dart

lib/features/notes/data/models/
└── note_model.dart
```

**Modelo Note:**
```dart
class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Workflow:**
1. Escribir tests primero (create_note_test.dart)
2. Implementar UseCases hasta que tests pasen
3. Repetir para cada UseCase

**Criterio de avance:** Todos los tests Domain en verde

---

### PASO 2: Data Layer

**Objetivo:** Persistencia con vinculación documents

**Artefactos a crear:**
```
lib/features/notes/data/repositories/
└── note_repository.dart
```

**SQL crítico a implementar:**
```sql
-- Crear nota
INSERT INTO notes (title, content, created_at, updated_at)
VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- Vincular a documento
INSERT INTO document_notes (document_id, note_id)
VALUES (?, ?);

-- Obtener nota por documento (JOIN)
SELECT n.*
FROM notes n
JOIN document_notes dn ON n.id = dn.note_id
WHERE dn.document_id = ?;
```

**Workflow:**
1. Implementar repository con transacciones
2. Validar CASCADE en eliminación
3. Tests de integración en verde

**Criterio de avance:** Tests repository en verde

---

### PASO 3: Presentation Layer

**Objetivo:** Editor simple + integración con Documents

**Artefactos a crear:**
```
lib/features/notes/presentation/
├── providers/
│   └── note_provider.dart
├── pages/
│   └── note_editor_page.dart
└── widgets/
    └── note_display.dart
```

**Modificar (integración con Épica 1):**
```
lib/features/documents/presentation/pages/
└── document_detail_page.dart
    └── Agregar: botón AGREGAR NOTA / EDITAR NOTA
    └── Agregar: widget NoteDisplay si tiene nota
```

**Workflow:**
1. Crear NoteProvider
2. Crear NoteEditorPage (campos + botones)
3. Integrar en DocumentDetailPage
4. Testing manual

**Criterio de avance:** Flujo completo funciona

---

## INTEGRACIÓN CON ÉPICA 1 (Documents)

**Cambios requeridos en DocumentDetailPage:**

```dart
// Pseudo-código de integración

Widget build(BuildContext context) {
  return Scaffold(
    body: Column([
      // PDF viewer existente
      PDFViewer(...),
      
      // NUEVO: Mostrar nota si existe
      Consumer<NoteProvider>(
        builder: (context, noteProvider, _) {
          if (noteProvider.currentNote != null) {
            return NoteDisplay(note: noteProvider.currentNote);
          }
          return SizedBox.shrink();
        },
      ),
      
      // NUEVO: Botón agregar/editar nota
      ActionButtons(
        onAddNote: () => _navigateToNoteEditor(),
        // ... otros botones
      ),
    ]),
  );
}
```

---

## DATOS DE PRUEBA

**Para testing manual:**

```sql
-- Insertar nota para documento existente (id=1)
INSERT INTO notes (title, content, created_at, updated_at)
VALUES (
  'Pagar antes del 15',
  'Recordar pagar antes del vencimiento. Usar Mercado Pago para evitar recargo.',
  '2026-01-24 10:00:00',
  '2026-01-24 10:00:00'
);

-- Vincular nota al documento
INSERT INTO document_notes (document_id, note_id)
VALUES (1, 1);
```

---

## CRITERIOS DE COMPLETITUD ÉPICA 2

**Checklist antes de pasar a Épica 3:**

### Tests
- [ ] Todos los tests Domain pasan (100% cobertura)
- [ ] Tests de repository pasan
- [ ] Validado CASCADE en eliminación
- [ ] No hay tests rojos

### Funcionalidad
- [ ] Botón "AGREGAR NOTA" visible en detalle documento
- [ ] Teclado aparece automáticamente en campo título
- [ ] Campos título y contenido con fuente 18sp
- [ ] Botones GUARDAR y CANCELAR mínimo 120x60dp
- [ ] Al guardar, vuelve a detalle mostrando nota
- [ ] Nota se muestra en detalle documento
- [ ] Si ya tiene nota, botón muestra "EDITAR NOTA"
- [ ] Al editar, campos pre-populados con texto existente
- [ ] Eliminar documento elimina nota asociada (CASCADE)

### Arquitectura
- [ ] Domain NO importa Flutter
- [ ] UseCases no conocen Provider
- [ ] Repository maneja transacciones correctamente
- [ ] Integración con Documents limpia (sin acoplamiento fuerte)

### Localización
- [ ] Todos los textos usan claves (AppLocalizations)
- [ ] Funciona en ES y EN

---

## ENTREGABLES ESPERADOS

```
lib/features/notes/
├── data/
│   ├── models/
│   │   └── note_model.dart            ✓ Completo
│   └── repositories/
│       └── note_repository.dart       ✓ Completo + tests
├── domain/
│   └── usecases/
│       ├── create_note.dart           ✓ Completo + tests
│       ├── update_note.dart           ✓ Completo + tests
│       ├── get_note_by_document.dart  ✓ Completo + tests
│       └── delete_note.dart           ✓ Completo + tests
└── presentation/
    ├── providers/
    │   └── note_provider.dart         ✓ Completo
    ├── pages/
    │   └── note_editor_page.dart      ✓ UI mínima funcional
    └── widgets/
        └── note_display.dart          ✓ Completo

test/features/notes/
├── domain/
│   └── usecases/                      ✓ 4 archivos, ~13 tests
└── data/
    └── repositories/                  ✓ 1 archivo, ~6 tests

Modificaciones:
lib/features/documents/presentation/pages/
└── document_detail_page.dart          ✓ Integración con notas
```

---

## NOTAS PARA CLAUDE CODE

1. **Transacciones son críticas** - Crear nota + vincular debe ser atómico
2. **Validar CASCADE** - Eliminar documento debe eliminar nota
3. **UI simple suficiente** - TextField básico, sin rich text
4. **Integración ligera** - Documents no debe depender de Notes fuertemente
5. **Relación 1:1 por ahora** - Un documento solo tiene una nota

---

## REFERENCIAS

- **Arquitectura:** `/mnt/project/architecture.md`
- **Schema BD:** `/mnt/project/database_schema.md`
- **Decisiones técnicas:** `/mnt/project/ADDS_v1_1.md`
- **Épica previa:** `ÉPICA_1_SPEC.md` (Documents completado)

● ¡Excelente! ÉPICA 2 COMPLETADA EXITOSAMENTE 🎉

Resumen final:                                                                                                                                                                                                                                                                                                                                                                                                                                                      
✅ Tests (35/35 pasando)                                                                                                                                                                                                         ─                                                                                                                                                                                                                                   
Épica 1 - Documents:
- Domain: 10 tests ✓
- Data: 6 tests ✓

Épica 2 - Notes:
- Domain: 13 tests ✓
- Data: 6 tests ✓

✅ Arquitectura Clean completa

Domain Layer:
- NoteModel
- 4 UseCases (CreateNote, UpdateNote, GetNoteByDocument, DeleteNote)

Data Layer:
- NoteRepository con transacciones atómicas
- Vinculación via document_notes table
- CASCADE funcional

Presentation Layer:
- NoteProvider
- NoteEditorPage (campos 18sp, botones grandes, autofocus)
- NoteDisplay widget
- Integración completa en DocumentDetailPage

✅ Criterios de Aceptación HU-004

- Botón "AGREGAR NOTA" visible en detalle
- Editor simple con teclado automático
- Campos 18sp, botones grandes
- Al guardar vuelve a detalle mostrando nota
- Botón cambia a "EDITAR NOTA" cuando ya existe
- Nota vinculada 1:1 con documento
- CASCADE elimina nota si se elimina documento

✅ Análisis estático

flutter analyze: No issues found!
