# EscanDoc - ADDS (Ajustes Pendientes)

**Fecha:** 17 de Enero 2026  
**Versión:** 1.0

---

## CAMBIOS A IMPLEMENTAR

### 1. MULTILENGUAJE (Desde día 0)

**Estructura:**
```
lib/
├── core/
│   └── localization/
│       ├── app_localizations.dart      # Clase helper
│       ├── es.json                     # Español (primario)
│       └── en.json                     # Inglés (secundario)
```

**Packages:**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.18.0
  # O alternativa más simple:
  # easy_localization: ^3.0.0
```

**Regla de oro:**
- ❌ Nunca texto hardcodeado: `"Guardar documento"`
- ✅ Siempre con clave: `AppLocalizations.of(context).saveDocument`

**Ejemplos de claves:**
```json
// es.json
{
  "app_name": "EscanDoc",
  "scan_button": "ESCANEAR",
  "save_button": "GUARDAR",
  "document_saved": "✓ Documento guardado",
  "category_invoice": "Factura",
  "category_receipt": "Recibo",
  "month_jan": "Ene",
  "month_feb": "Feb"
}

// en.json
{
  "app_name": "ScanDoc",
  "scan_button": "SCAN",
  "save_button": "SAVE",
  "document_saved": "✓ Document saved",
  "category_invoice": "Invoice",
  "category_receipt": "Receipt",
  "month_jan": "Jan",
  "month_feb": "Feb"
}
```

**Domain NO conoce idiomas:**
- Domain devuelve: `DocumentSaved` (estado/código)
- UI traduce: "Documento guardado" o "Document saved"

---

### 2. NOMBRES DE DOCUMENTOS AMIGABLES

**Cambio:**

❌ **ANTES:** `"Documento_2026-01-17_14-30"` (timestamp confuso)

✅ **DESPUÉS:**
- ES: `"factura_25_Ene_2026"` (fecha de escaneo)
- EN: `"invoice_25_Jan_2026"`
- Default: `"documento_25_Ene_2026"` si no detecta tipo

**Formato:**
```
{tipo}_{día}_{mes_corto}_{año}
```

**Lógica:**
1. Detecta tipo (factura, recibo, contrato, médico)
2. Si no detecta → "documento"
3. Obtiene fecha actual
4. Traduce mes según idioma activo
5. Genera nombre

**Función helper:**
```dart
String generateDocumentName(String? detectedType, DateTime date, Locale locale) {
  String type = detectedType ?? 'documento';
  String month = getMonthAbbreviation(date.month, locale);
  return '${type}_${date.day}_${month}_${date.year}';
}
```

**Actualizar:**
- `document_model.dart`: campo `title` generado automáticamente
- HU-004: Criterio "Nombre por defecto" → nueva lógica

---

### 3. CATEGORÍAS SIMPLIFICADAS (SIN CARPETAS)

**Cambio:**

❌ **ANTES:** 6 carpetas manuales (Facturas, Recibos, Contratos, Médico, Personal, Otros)

✅ **DESPUÉS:** 5 categorías automáticas (sin carpetas físicas)
- **Factura**
- **Recibo**
- **Contrato**
- **Médico**
- **Documento** (default)

**UI:**
- UNA sola lista con todos los documentos
- Ordenados por fecha (más reciente arriba)
- Nombre muestra categoría: "factura_25_Ene_2026"
- Sin selección manual de carpeta

**Búsqueda reemplaza filtros:**
- Buscar "factura" → trae todas las facturas
- Buscar "enero" → trae todos de enero
- Buscar "edesur" → trae los que tienen ese texto en OCR

**Eliminar:**
- ❌ HU-011: Organizar en carpetas simples (ELIMINADA)
- ❌ `category` campo en BD (solo `doc_type`)
- ❌ Dropdown de filtro por carpeta

**Actualizar:**
- `documents` table: eliminar campo `category`, solo usar `doc_type`
- HU-012: Resultado de auto-detección va directo a nombre (no pregunta)
- Arquitectura: eliminar feature `categories/` (no es necesario)

---

### 4. AUTO-DETECCIÓN SIMPLIFICADA

**Cambio en flujo:**

❌ **ANTES:** 
- Detecta tipo → Pregunta "¿Es correcto?" → Usuario confirma

✅ **DESPUÉS:**
- Detecta tipo → Genera nombre automáticamente
- Usuario VE el nombre: "factura_25_Ene_2026"
- Si está mal, puede editar nombre después

**Lógica simplificada en DocumentClassifier:**
```dart
class DocumentClassifier {
  String detectType(String ocrText) {
    String lowerText = ocrText.toLowerCase();
    
    if (lowerText.contains('factura') || lowerText.contains('invoice')) {
      return 'factura';
    }
    if (lowerText.contains('recibo') || lowerText.contains('receipt')) {
      return 'recibo';
    }
    if (lowerText.contains('contrato') || lowerText.contains('contract')) {
      return 'contrato';
    }
    if (lowerText.contains('médico') || lowerText.contains('medical') || 
        lowerText.contains('consulta') || lowerText.contains('prescription')) {
      return 'médico';
    }
    
    return 'documento'; // default
  }
}
```

**Actualizar:**
- HU-012: Eliminar confirmación del usuario, hacer automático
- BD: `doc_type` valores: "factura", "recibo", "contrato", "médico", "documento"

---

### 5. BASE DE DATOS - AJUSTES

**Cambios en schema:**

```sql
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  
  -- Metadata básica
  title TEXT NOT NULL,                   -- "factura_25_Ene_2026" (generado)
  file_path TEXT NOT NULL,
  thumbnail_path TEXT,
  
  -- OCR y clasificación
  ocr_text TEXT,
  doc_type TEXT DEFAULT 'documento',     -- factura, recibo, contrato, médico, documento
  extracted_date DATE,
  
  -- Timestamps
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT valid_doc_type CHECK (
    doc_type IN ('factura', 'recibo', 'contrato', 'médico', 'documento')
  )
);
```

**Eliminar:**
- ❌ Campo `category` 
- ❌ Constraint `valid_category`
- ❌ Índice `idx_documents_category`

**Mantener:**
- ✅ Índice `idx_documents_doc_type` (para búsqueda)
- ✅ FTS5 para búsqueda full-text

---

### 6. HISTORIAS DE USUARIO - AJUSTES

**Eliminar:**
- ❌ **HU-011:** Organizar en carpetas simples (ELIMINADA completamente)

**Modificar:**

**HU-004: Guardar documento escaneado**
- Cambiar criterio: "Nombre por defecto: Documento_YYYY-MM-DD_HH-MM"
- A: "Nombre generado: {tipo}_{día}_{mes}_{año} según tipo detectado e idioma"

**HU-012: Auto-detectar tipo de documento**
- Eliminar criterios de confirmación del usuario
- Cambiar a: "Tipo detectado se usa automáticamente para generar nombre"
- Usuario ve resultado: "factura_25_Ene_2026"

**Agregar en roadmap:**
- HU-016: Editar nombre de documento (para Fase 1, prioridad BAJA)

---

### 7. ARQUITECTURA - AJUSTES

**Agregar en core:**
```
core/
├── localization/
│   ├── app_localizations.dart
│   ├── es.json
│   └── en.json
```

**Eliminar:**
```
features/
└── categories/    # ELIMINAR COMPLETO
```

**Modificar DocumentClassifier:**
```dart
// core/services/document_classifier.dart
class DocumentClassifier {
  // Solo detectType(), sin preguntar al usuario
  String detectType(String ocrText);
  
  // Extracción fecha sigue igual
  DateTime? extractDueDate(String ocrText);
  
  // NUEVO: generar nombre según tipo e idioma
  String generateDocumentName(String? detectedType, DateTime date, Locale locale);
}
```

---

### 8. PRODUCT VISION DOCUMENT - ACTUALIZACIONES

**Agregar sección:**

**Internacionalización:**
- Idiomas soportados: Español (ES) primario, Inglés (EN) secundario
- Textos centralizados desde día 0
- Nombres de documentos localizados
- UI se adapta al idioma del sistema

**Actualizar Features MVP:**
- Eliminar: "Carpetas manuales"
- Agregar: "Nombres de documentos amigables y localizados"
- Simplificar: "Auto-detección de tipo (5 categorías)"

**Actualizar Tabla Competencia:**
- Agregar fila: "Nombres amigables" → DocScan Pro: ✅ Sí

---

## PRIORIDAD DE IMPLEMENTACIÓN

### Día 0 (Setup):
1. ✅ Estructura localization
2. ✅ Archivos es.json / en.json base
3. ✅ Schema BD actualizado

### Feature por feature:
1. ✅ Usar claves de traducción (no hardcode)
2. ✅ DocumentClassifier con generación de nombre
3. ✅ UI muestra nombres amigables

### Al final:
1. ⏭️ Traducir todos los textos EN
2. ⏭️ Revisar copy elderly-friendly
3. ⏭️ Testing con idioma EN

---

## CHECKLIST DE VALIDACIÓN

- [ ] Ningún texto hardcodeado en código
- [ ] Todos los nombres de documento siguen formato {tipo}_{día}_{mes}_{año}
- [ ] Solo 5 categorías (factura, recibo, contrato, médico, documento)
- [ ] Sin carpetas ni filtros manuales
- [ ] BD sin campo `category`
- [ ] HU-011 eliminada de backlog
- [ ] Búsqueda reemplaza necesidad de carpetas
- [ ] UI funciona en ES y EN

---

**Próximo paso:** Implementar en FASE 1 según plan de desarrollo
