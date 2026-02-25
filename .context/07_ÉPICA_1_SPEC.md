


# EscanDoc - Historias de Usuario MVP (v1.1)

**Fecha:** 24 de Enero 2026  
**Versión:** 1.1 - Actualizada según ADDS.md v1.1  
**Total Historias:** 14 (3 eliminadas del v1.0)

---

## USUARIO PRIMARIO
**Persona mayor (60-85 años), no tech-savvy**

---

## ÉPICA 1: DOCUMENTS (Feature 1 - Base de datos)
**Prioridad:** CRÍTICA - Implementar primero

### HU-001: Ver lista de documentos guardados
**Prioridad:** CRÍTICA

**Como** usuario  
**Quiero** ver todos mis documentos en una lista simple  
**Para** acceder a ellos fácilmente  

**Criterios de Aceptación:**
- [ ] Lista vertical con thumbnails grandes (mínimo 80x80 dp)
- [ ] Cada item muestra: thumbnail + nombre + fecha
- [ ] Nombre formato: "factura_25_Ene_2026" (localizado)
- [ ] Ordenado por fecha (más reciente primero)
- [ ] Scroll suave y responsive
- [ ] Texto legible: nombre 18sp, fecha 16sp
- [ ] Contraste alto (negro sobre blanco)
- [ ] Si no hay documentos: "No hay documentos. Tocá ESCANEAR para empezar"

---

### HU-002: Ver documento en detalle
**Prioridad:** ALTA

**Como** usuario  
**Quiero** tocar un documento y verlo en grande  
**Para** leer su contenido  

**Criterios de Aceptación:**
- [ ] Al tocar item en lista, abre pantalla detalle
- [ ] Muestra PDF/imagen en pantalla completa
- [ ] Zoom con pinch (pellizcar) funciona
- [ ] Botón "VOLVER" grande y visible (top-left)
- [ ] Botones de acción visibles: "AGREGAR NOTA" y "COMPARTIR"
- [ ] Transición suave (<300ms)
- [ ] Si tiene nota vinculada, se muestra debajo del documento

---

### HU-003: Eliminar documento con confirmación
**Prioridad:** ALTA

**Como** persona mayor  
**Quiero** confirmar antes de borrar un documento  
**Para** no eliminar cosas por error  

**Criterios de Aceptación:**
- [ ] Long-press en documento muestra menú: "ELIMINAR"
- [ ] Al tocar ELIMINAR, muestra diálogo: "¿Eliminar este documento?"
- [ ] Botones grandes: "SÍ, ELIMINAR" (rojo) y "NO, CANCELAR" (gris)
- [ ] Cada botón mínimo 120x60 dp
- [ ] Sin gestos de swipe-to-delete (solo botón explícito)
- [ ] Después de eliminar: mensaje "Documento eliminado" (3 seg)
- [ ] NO hay papelera (eliminación definitiva por simplicidad MVP)
- [ ] Elimina archivo PDF + thumbnail + registro BD

---















# ÉPICA 1 - DOCUMENTS: Especificación de Desarrollo

**Fecha:** 24 de Enero 2026  
**Versión:** 1.0  
**Historias:** HU-001, HU-002, HU-003

---

## OBJETIVO DE LA ÉPICA

Implementar CRUD básico de documentos (ver lista, ver detalle, eliminar) sin dependencias de otras features. Valida arquitectura completa antes de continuar.

---

## HISTORIAS DE USUARIO

### HU-001: Ver lista de documentos guardados
**Prioridad:** CRÍTICA

**Criterios clave:**
- Lista con thumbnails 80x80dp
- Nombre formato: "factura_25_Ene_2026"
- Ordenado por fecha descendente
- Empty state si no hay documentos

---

### HU-002: Ver documento en detalle
**Prioridad:** ALTA

**Criterios clave:**
- Pantalla completa con PDF/imagen
- Zoom funcional
- Botones grandes (VOLVER, AGREGAR NOTA, COMPARTIR)

---

### HU-003: Eliminar documento con confirmación
**Prioridad:** ALTA

**Criterios clave:**
- Long-press → menú ELIMINAR
- Diálogo confirmación con botones grandes
- Elimina archivo + BD + thumbnail

---

## CONTRATO DE TESTS

### PASO 1: Domain (UseCases)

**Tests unitarios requeridos:**

```
test/features/documents/domain/usecases/

├── get_documents_test.dart
│   ├── ✓ Debe retornar lista ordenada por fecha (más reciente primero)
│   ├── ✓ Debe retornar lista vacía si no hay documentos
│   └── ✓ Debe manejar error de BD y retornar lista vacía
│
├── get_document_by_id_test.dart
│   ├── ✓ Debe retornar documento si existe
│   ├── ✓ Debe retornar null si no existe
│   └── ✓ Debe manejar error de BD
│
└── delete_document_test.dart
    ├── ✓ Debe eliminar documento y archivos asociados
    ├── ✓ Debe retornar false si documento no existe
    ├── ✓ Debe retornar false si falla eliminación de archivo
    └── ✓ Debe eliminar thumbnail además del PDF
```

**Cobertura mínima Domain:** 100%

---

### PASO 2: Data (Repository)

**Tests de integración requeridos:**

```
test/features/documents/data/repositories/

└── document_repository_test.dart
    ├── ✓ Debe insertar documento en BD correctamente
    ├── ✓ Debe recuperar documento por ID
    ├── ✓ Debe recuperar lista de documentos ordenada
    ├── ✓ Debe actualizar documento existente
    ├── ✓ Debe eliminar documento de BD
    └── ✓ Debe retornar null si documento no existe
```

**Nota:** Estos tests usan BD real en memoria (no mocks)

---

### PASO 3: Presentation (Provider)

**Tests de provider (opcional para MVP):**

```
test/features/documents/presentation/providers/

└── documents_provider_test.dart
    ├── ✓ Debe cargar documentos y notificar listeners
    ├── ✓ Debe manejar estado de loading
    ├── ✓ Debe manejar errores y notificar
    └── ✓ Debe actualizar lista después de eliminar
```

**Cobertura mínima Provider:** 80% (opcional)

---

## ORDEN DE IMPLEMENTACIÓN (TDD)

### PASO 1: Domain Layer

**Objetivo:** Lógica de negocio sin Flutter

**Artefactos a crear:**
```
lib/features/documents/domain/usecases/
├── get_documents.dart
├── get_document_by_id.dart
└── delete_document.dart

lib/features/documents/data/models/
└── document_model.dart
```

**Workflow:**
1. Escribir tests primero (get_documents_test.dart)
2. Implementar UseCase hasta que tests pasen
3. Repetir para cada UseCase

**Criterio de avance:** Todos los tests Domain en verde

---

### PASO 2: Data Layer

**Objetivo:** Persistencia real con SQLite

**Artefactos a crear:**
```
lib/features/documents/data/repositories/
└── document_repository.dart
```

**Workflow:**
1. Implementar repository con queries SQL
2. Ejecutar tests de integración
3. Ajustar hasta que pasen

**Criterio de avance:** Tests de repository en verde

---

### PASO 3: Presentation Layer

**Objetivo:** UI mínima funcional (NO diseño final)

**Artefactos a crear:**
```
lib/features/documents/presentation/
├── providers/
│   └── documents_provider.dart
├── pages/
│   ├── documents_list_page.dart
│   └── document_detail_page.dart
└── widgets/
    ├── document_card.dart
    ├── empty_state.dart
    └── delete_confirmation_dialog.dart
```

**Workflow:**
1. Crear provider (conecta UseCases con UI)
2. Crear pages con widgets básicos
3. Testing manual con datos fake en BD

**Criterio de avance:** Flujo completo funciona end-to-end

---

## DATOS DE PRUEBA

**Para testing manual, insertar en BD:**

```sql
-- Documento 1: Factura
INSERT INTO documents (title, file_path, thumbnail_path, doc_type, created_at)
VALUES (
  'factura_17_Ene_2026',
  '/storage/documents/factura_17_Ene_2026.pdf',
  '/storage/thumbnails/factura_17_Ene_2026_thumb.jpg',
  'factura',
  '2026-01-17 14:30:00'
);

-- Documento 2: Recibo
INSERT INTO documents (title, file_path, thumbnail_path, doc_type, created_at)
VALUES (
  'recibo_20_Ene_2026',
  '/storage/documents/recibo_20_Ene_2026.pdf',
  '/storage/thumbnails/recibo_20_Ene_2026_thumb.jpg',
  'recibo',
  '2026-01-20 10:15:00'
);
```

---

## CRITERIOS DE COMPLETITUD ÉPICA 1

**Checklist antes de pasar a Épica 2:**

### Tests
- [ ] Todos los tests Domain pasan (100% cobertura)
- [ ] Tests de repository pasan
- [ ] No hay tests rojos

### Funcionalidad
- [ ] Lista muestra documentos ordenados por fecha
- [ ] Card muestra thumbnail + nombre localizado + fecha
- [ ] Tap en card abre detalle con PDF visible
- [ ] Botón VOLVER funciona
- [ ] Long-press muestra diálogo de confirmación
- [ ] Botones "SÍ, ELIMINAR" y "NO, CANCELAR" son grandes (120x60dp)
- [ ] Delete elimina documento y refresca lista
- [ ] Empty state se muestra si no hay docs

### Arquitectura
- [ ] Domain NO importa Flutter
- [ ] Domain NO conoce SQLite directamente
- [ ] Provider usa UseCases (no repository directo)
- [ ] UI solo muestra datos del provider

### Localización
- [ ] Todos los textos usan claves (AppLocalizations)
- [ ] Funciona en ES y EN sin cambios de código

---

## ENTREGABLES ESPERADOS

```
lib/features/documents/
├── data/
│   ├── models/
│   │   └── document_model.dart       ✓ Completo
│   └── repositories/
│       └── document_repository.dart   ✓ Completo + tests
├── domain/
│   └── usecases/
│       ├── get_documents.dart         ✓ Completo + tests
│       ├── get_document_by_id.dart    ✓ Completo + tests
│       └── delete_document.dart       ✓ Completo + tests
└── presentation/
    ├── providers/
    │   └── documents_provider.dart    ✓ Completo
    ├── pages/
    │   ├── documents_list_page.dart   ✓ UI mínima funcional
    │   └── document_detail_page.dart  ✓ UI mínima funcional
    └── widgets/
        ├── document_card.dart         ✓ Completo
        ├── empty_state.dart           ✓ Completo
        └── delete_confirmation_dialog.dart ✓ Completo

test/features/documents/
├── domain/
│   └── usecases/                      ✓ 3 archivos, ~12 tests
└── data/
    └── repositories/                  ✓ 1 archivo, ~6 tests
```

---

## NOTAS PARA CLAUDE CODE

1. **NO generar código de UI complejo** - UI mínima suficiente
2. **Priorizar tests Domain** - Son los más valiosos
3. **Mock solo en Domain tests** - Repository usa BD real
4. **Sin navegación fancy** - Routes nombradas simples
5. **Sin animaciones por ahora** - Funcionalidad primero

---

## REFERENCIAS

- **Arquitectura:** `/mnt/project/architecture.md`
- **Schema BD:** `/mnt/project/database_schema.md`
- **Decisiones técnicas:** `/mnt/project/ADDS_v1_1.md`


¡Perfecto! ÉPICA 1 COMPLETADA EXITOSAMENTE 🎉

Resumen de lo implementado:                                                                                                                                                                                                                                                                                                                                                                                                                                         
✅ Tests (16/16 pasando)                                                                                                                                                                                                         ─
- Domain Layer: 10 tests (100% cobertura)
    - GetDocuments: 3 tests
    - GetDocumentById: 3 tests
    - DeleteDocument: 4 tests
- Data Layer: 6 tests (integración con SQLite)

✅ Arquitectura Clean (Domain → Data → Presentation)

Domain Layer:
- DocumentModel - Modelo de datos
- GetDocuments - UseCase para listar
- GetDocumentById - UseCase para ver detalle
- DeleteDocument - UseCase para eliminar

Data Layer:
- DocumentRepository - CRUD completo con SQLite

Presentation Layer:
- DocumentsProvider - Estado con Provider
- DocumentsListPage - Lista con scroll y refresh
- DocumentDetailPage - Visualizador PDF/imagen con zoom
- DocumentCard - Card con thumbnail 80x80dp
- EmptyState - Estado vacío accesible
- DeleteConfirmationDialog - Confirmación con botones grandes

✅ Criterios de Aceptación (HU-001, HU-002, HU-003)

- Lista ordenada por fecha descendente
- Thumbnails 80x80dp, textos 18sp/16sp
- Tap abre detalle con zoom funcional
- Long-press → diálogo confirmación → botones grandes (60dp altura, full width)
- Localización completa ES/EN
- Empty state si no hay documentos

✅ Análisis estático

flutter analyze: No issues found!

Archivos creados/modificados:

lib/features/documents/
├── data/
│   ├── models/document_model.dart ✓
│   └── repositories/document_repository.dart ✓
├── domain/usecases/
│   ├── get_documents.dart ✓
│   ├── get_document_by_id.dart ✓
│   └── delete_document.dart ✓
└── presentation/
├── providers/documents_provider.dart ✓
├── pages/
│   ├── documents_list_page.dart ✓
│   └── document_detail_page.dart ✓
└── widgets/
├── document_card.dart ✓
├── empty_state.dart ✓
└── delete_confirmation_dialog.dart ✓

test/features/documents/
├── domain/usecases/ (10 tests) ✓
└── data/repositories/ (6 tests) ✓

assets/l10n/
├── es.json ✓ (claves agregadas)
└── en.json ✓ (claves agregadas)

La ÉPICA 1 está lista para pruebas manuales o pasar a la siguiente épica. 🚀
