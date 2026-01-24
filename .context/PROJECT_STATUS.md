# EscanDoc - Estado Actual del Proyecto

**Última actualización:** 24 Enero 2026
**Versión:** Fase 0 + ÉPICA 1 + ÉPICA 2 + ÉPICA 3 COMPLETADAS

---

## FASES COMPLETADAS

### ✅ FASE 0 (Infraestructura base)
- Database Helper con schema completo → `lib/core/database/database_helper.dart`
- SQLite + FTS5 funcional (tablas: documents, notes, document_notes, due_dates, triggers)
- Estructura de carpetas feature-first creada
- Localización configurada (ES/EN) → `assets/l10n/`

### ✅ ÉPICA 1 (Documents - CRUD básico)
**Tests:** 16/16 pasando (10 Domain + 6 Data)

**Implementado:**
- Domain: 3 UseCases (`GetDocuments`, `GetDocumentById`, `DeleteDocument`)
- Data: `DocumentModel` + `DocumentRepository` (CRUD completo)
- Presentation: Provider + 2 páginas + 3 widgets
- HU-001: Lista de documentos ✓
- HU-002: Vista detalle con zoom ✓
- HU-003: Eliminación con confirmación ✓

**Ubicación:** `lib/features/documents/` + `test/features/documents/`

### ✅ ÉPICA 2 (Notes - Vinculación)
**Tests:** 19/19 pasando (13 Domain + 6 Data)

**Implementado:**
- Domain: 4 UseCases (`CreateNote`, `UpdateNote`, `GetNoteByDocument`, `DeleteNote`)
- Data: `NoteModel` + `NoteRepository` (transacciones atómicas)
- Presentation: Provider + editor + widget display
- HU-004: Agregar/editar nota a documento ✓
- Relación 1:1 documento-nota
- Integración completa en `DocumentDetailPage`

**Ubicación:** `lib/features/notes/` + `test/features/notes/`

### ✅ ÉPICA 3 (Search - Búsqueda FTS5 + Voz)
**Tests:** 31/31 pasando (15 Domain + 11 Data + 5 SpeechService)

**Implementado:**
- Domain: 2 UseCases (`SearchDocuments`, `VoiceSearch`)
- Data: `SearchResult` model + `SearchRepositoryImpl` (queries FTS5)
- Core: `SpeechServiceImpl` (wrapper speech_to_text)
- Presentation: `SearchProvider` (con debounce 500ms) + SearchPage + 5 widgets
- HU-005: Búsqueda incremental por texto en documentos/notas ✓
- HU-006: Búsqueda por voz con indicador visual ✓
- FTS5 con snippets destacados (<b>query</b>)
- Integración en home con botón búsqueda

**Ubicación:** `lib/features/search/` + `test/features/search/` + `lib/core/services/speech_service*`

---

## DEPENDENCIAS INSTALADAS

### Producción
- `provider: ^6.1.2` - State management
- `sqflite: ^2.4.2` - SQLite local
- `easy_localization: ^3.0.7` - i18n (configurado)
- `speech_to_text: ^7.3.0` - Búsqueda por voz (ÉPICA 3)
- `printing: ^5.14.2` - Vista PDF
- `google_mlkit_text_recognition: ^0.15.0` - OCR (futuro ÉPICA 4)
- `flutter_doc_scanner: ^0.0.17` - Scanner nativo (futuro ÉPICA 4)

### Testing
- `mocktail: ^1.0.4` - Mocks para tests unitarios
- `sqflite_common_ffi: ^2.3.4` - SQLite para tests desktop

**Estado:** `flutter pub get` ejecutado, todo instalado.

---

## LOCALIZACIÓN

**Sistema:** easy_localization (ya inicializado en `main.dart`)

**Archivos:**
- `assets/l10n/es.json` (idioma por defecto)
- `assets/l10n/en.json`

**Claves disponibles:**
- Botones: `scan_button`, `save_button`, `delete_button`, `back_button`, `share_button`, `search_button`
- Mensajes: `document_saved`, `document_deleted`, `error_loading`
- Empty states: `documents_empty`, `documents_empty_subtitle`
- Diálogos: `delete_confirm_title`, `delete_yes_button`, `delete_no_button`
- Búsqueda: `search_placeholder`, `search_no_results`, `search_listening`, `search_voice_error`, `search_voice_button`
- Meses: `month_jan` hasta `month_dec`
- Tipos docs: `doc_type_factura`, `doc_type_recibo`, etc.

**Uso:** `'clave'.tr()` (importar `easy_localization`)

---

## BASE DE DATOS

**Helper:** `DatabaseHelper.instance` (Singleton)
**Path:** `lib/core/database/database_helper.dart`

**Tablas activas:**
- `documents` (con FTS5: `documents_fts`)
- `notes` (con FTS5: `notes_fts`)
- `document_notes` (many-to-many)
- `due_dates` + `document_due_dates` (preparadas, no usadas aún)

**Triggers:** Auto-actualización de FTS5 + `updated_at` automático

**Testing:** Tests de integración usan BD real (limpieza automática en setUp/tearDown)

---

## ARQUITECTURA

**Patrón:** Clean Architecture + Feature-First

**Estructura por feature:**
```
lib/features/[feature]/
├── data/
│   ├── models/          # Modelos de dominio
│   └── repositories/    # Acceso a BD/APIs
├── domain/
│   └── usecases/        # Lógica de negocio pura (NO Flutter)
└── presentation/
    ├── providers/       # State con Provider
    ├── pages/          # Páginas completas
    └── widgets/        # Componentes reutilizables
```

**Regla:** Domain NUNCA importa Flutter ni SQLite directamente.

---

## TESTING

**Comando:** `flutter test` (66 tests pasando)
**Análisis:** `flutter analyze` (3 warnings/infos no críticos)

**Ubicación tests:** `test/features/[feature]/` (espeja estructura de `lib/`)

**Cobertura:**
- Domain: 100% (tests unitarios con mocks)
- Data: Tests de integración con BD real
- Presentation: Sin tests (MVP acepta testing manual)

---

## NAVEGACIÓN

**Rutas definidas en `main.dart`:**
- `/home` → `DocumentsListPage` (ruta inicial)
- `/document/detail` → `DocumentDetailPage` (recibe `int documentId` como argumento)
- `/search` → `SearchPage` ✓ (funcional con FTS5 + voz)
- `/note/edit` → `NoteEditorPage` ✓ (funcional)
- `/onboarding` → Scaffold vacío (futuro)
- `/scan`, `/scan/crop` → Scaffolds vacíos (futuro ÉPICA 4)

**Providers registrados:**
- `DocumentsProvider` ✓ (funcional)
- `NoteProvider` ✓ (funcional)
- `SearchProvider` ✓ (funcional con debounce + voz)
- `ScanProvider` (vacío - futuro)

---

## PENDIENTES (No implementadas)

- ÉPICA 4: Scan (captura con flutter_doc_scanner + OCR + auto-clasificación) - HU-007 a HU-012
- ÉPICA 5: Vencimientos (notificaciones locales)
- Onboarding (HU-013)

---

## COMANDOS ÚTILES

```bash
flutter test                          # Ejecutar tests
flutter test --coverage              # Con cobertura
flutter analyze                      # Linting
flutter run -d windows               # Ejecutar en desktop
flutter pub get                      # Instalar dependencias
```

---

## NOTAS IMPORTANTES

1. **Domain Layer:** SIEMPRE escribir tests primero (TDD estricto)
2. **Localización:** NUNCA hardcodear textos, usar claves `.tr()`
3. **UI accesible:** Botones mínimo 60dp altura, textos 16sp+, contraste alto
4. **Sin emojis:** A menos que el usuario lo pida explícitamente
5. **Flutter analyze debe dar 0 issues** antes de commit
