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

## ÉPICA 3: SEARCH (Feature 3 - Búsqueda)
**Prioridad:** ALTA

### HU-005: Buscar documentos por texto
**Prioridad:** ALTA

**Como** persona mayor  
**Quiero** buscar "Edesur" y ver todas las facturas de luz  
**Para** encontrar documentos rápidamente  

**Criterios de Aceptación:**
- [ ] Barra de búsqueda visible en pantalla principal
- [ ] Placeholder claro: "Buscar en documentos..."
- [ ] Fuente 18sp en campo de búsqueda
- [ ] Busca en: nombre del documento + texto OCR + notas vinculadas
- [ ] Resultados aparecen mientras escribo (búsqueda incremental)
- [ ] Muestra snippet del texto encontrado (contexto)
- [ ] Máximo 3 segundos para mostrar resultados
- [ ] Si no hay resultados: "No se encontraron documentos"
- [ ] Usa FTS5 de SQLite para performance

---

### HU-006: Buscar por voz
**Prioridad:** MEDIA (diferenciador)

**Como** persona mayor que no escribe rápido  
**Quiero** buscar diciendo "factura Edesur"  
**Para** encontrar documentos sin escribir  

**Criterios de Aceptación:**
- [ ] Botón micrófono visible junto a barra de búsqueda
- [ ] Ícono grande (32x32 dp mínimo)
- [ ] Al tocar, inicia reconocimiento de voz
- [ ] Indicador visual: "Escuchando..." con animación
- [ ] Transcribe a texto y ejecuta búsqueda automáticamente
- [ ] Funciona offline (speech_to_text con modelo local)
- [ ] Si no entiende: "No entendí, intentá de nuevo"
- [ ] Timeout de 5 segundos máximo

---

## ÉPICA 4: SCAN (Feature 4 - Escaneo con OCR)
**Prioridad:** CRÍTICA (core del producto)

### HU-007: Escanear documento por primera vez
**Prioridad:** CRÍTICA (fundacional)

**Como** persona mayor que no usa mucho el celular  
**Quiero** escanear una factura con un solo botón grande  
**Para** guardarla digitalmente sin perder el papel  

**Criterios de Aceptación:**
- [ ] Botón "ESCANEAR" visible en pantalla principal (mínimo 60x60 dp)
- [ ] Texto del botón en español, tamaño 24sp mínimo
- [ ] Al tocar, abre scanner nativo (flutter_doc_scanner)
- [ ] Scanner nativo maneja detección automática de bordes
- [ ] Scanner nativo maneja ajuste de bordes si es necesario
- [ ] No requiere configuración previa (funciona de inmediato)
- [ ] Tiempo de apertura: <1 segundo

---

### HU-008: Guardar documento escaneado automáticamente
**Prioridad:** CRÍTICA

**Como** persona mayor  
**Quiero** que el documento se guarde con 1 toque  
**Para** no perderme en opciones complicadas  

**Criterios de Aceptación:**
- [ ] Después de escanear con flutter_doc_scanner, retorna a la app
- [ ] Guarda automáticamente como PDF en storage local
- [ ] Genera thumbnail (miniatura) automáticamente
- [ ] Nombre generado automáticamente: {tipo}_{día}_{mes}_{año}
- [ ] Formato localizado según idioma activo:
  - ES: "factura_25_Ene_2026"
  - EN: "invoice_25_Jan_2026"
- [ ] Si no detecta tipo: "documento_25_Ene_2026"
- [ ] Confirmación visual clara: "✓ Documento guardado" (3 segundos)
- [ ] NO pide nombre/carpeta al usuario
- [ ] Tiempo total desde scan a guardado: <5 segundos
- [ ] Vuelve a lista mostrando nuevo documento arriba

---

### HU-009: Extraer texto del documento automáticamente
**Prioridad:** ALTA

**Como** usuario  
**Quiero** que la app extraiga el texto automáticamente  
**Para** poder buscar documentos por contenido después  

**Criterios de Aceptación:**
- [ ] OCR se ejecuta en background después de guardar
- [ ] Usa google_mlkit_text_recognition v0.15.0
- [ ] Funciona offline (no requiere internet)
- [ ] Texto extraído se guarda en campo `ocr_text` de BD
- [ ] No bloquea UI (proceso asíncrono)
- [ ] Indicador visual discreto: "Procesando texto..." (opcional)
- [ ] Si OCR falla, documento igual se guarda (OCR no es bloqueante)
- [ ] Precisión esperada: >85% en documentos bien iluminados

---

### HU-010: Auto-detectar tipo de documento
**Prioridad:** ALTA (diferenciador clave)

**Como** usuario  
**Quiero** que la app detecte automáticamente si es factura o recibo  
**Para** tener nombres claros sin categorizar manualmente  

**Criterios de Aceptación:**
- [ ] Después de OCR, analiza texto y detecta tipo automáticamente
- [ ] Tipos detectables:
  - "factura" (si encuentra: factura, invoice)
  - "recibo" (si encuentra: recibo, receipt)
  - "contrato" (si encuentra: contrato, contract)
  - "médico" (si encuentra: médico, medical, consulta, prescription)
  - "documento" (default si no detecta nada)
- [ ] Tipo detectado se usa para generar nombre
- [ ] Usuario ve resultado directamente: "factura_25_Ene_2026"
- [ ] NO hay confirmación manual (simplificado vs v1.0)
- [ ] Guarda tipo detectado en BD campo `doc_type`

---

### HU-011: Extraer fecha de vencimiento automáticamente
**Prioridad:** MEDIA (WOW factor)

**Como** usuario  
**Quiero** que detecte "Vence: 15/02/2026" en la factura  
**Para** crear recordatorios sin buscar la fecha manualmente  

**Criterios de Aceptación:**
- [ ] Después de OCR, busca patrones de fecha:
  - "vencimiento:", "vence:", "pagar antes de:", "due date:"
  - Formatos: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
- [ ] Si encuentra fecha futura (>hoy), la extrae
- [ ] Muestra mensaje: "Detecté vencimiento: 15/02/2026. ¿Crear recordatorio?"
- [ ] Botones "SÍ" (crea recordatorio en Fase 2) y "NO" (ignora)
- [ ] Guarda fecha en BD (`extracted_date`)
- [ ] Si no encuentra fecha o no está seguro, no muestra nada
- [ ] NO bloquea guardado de documento

---

### HU-012: Ver texto OCR extraído (NUEVA)
**Prioridad:** BAJA

**Como** usuario  
**Quiero** ver el texto que la app extrajo del documento  
**Para** verificar que el OCR funcionó correctamente  

**Criterios de Aceptación:**
- [ ] En pantalla detalle, botón "VER TEXTO EXTRAÍDO"
- [ ] Abre diálogo o pantalla con texto OCR completo
- [ ] Texto copiable (long-press para copiar)
- [ ] Si no hay texto OCR: "No se pudo extraer texto"
- [ ] Fuente legible 16sp
- [ ] Scroll si el texto es largo

---

## ÉPICA 5: ONBOARDING (Feature 5 - Primera experiencia)
**Prioridad:** ALTA

### HU-013: Tutorial inicial obligatorio
**Prioridad:** ALTA

**Como** persona mayor usando la app por primera vez  
**Quiero** un tutorial simple de 3 pasos  
**Para** entender cómo usarla  

**Criterios de Aceptación:**
- [ ] Primera vez que abre app, muestra onboarding
- [ ] 3 pantallas máximo:
  1. "Escaneá documentos fácilmente" (imagen botón ESCANEAR)
  2. "Encontralos con búsqueda" (imagen lupa)
  3. "Agregá notas y recordatorios" (imagen nota)
- [ ] Botón "SIGUIENTE" grande en cada pantalla (200x60 dp)
- [ ] Última pantalla: "EMPEZAR" (cierra tutorial, va a home)
- [ ] Opción "Ver tutorial de nuevo" en menú configuración
- [ ] Texto grande (20sp), imágenes claras
- [ ] Guarda en SharedPreferences que completó onboarding
- [ ] No vuelve a aparecer automáticamente

---

## ÉPICA 6: CONFIGURATION (Feature 6 - Ajustes básicos)
**Prioridad:** BAJA (post-MVP)

### HU-014: Cambiar idioma de la app (NUEVA)
**Prioridad:** BAJA

**Como** usuario  
**Quiero** cambiar entre español e inglés  
**Para** usar la app en mi idioma preferido  

**Criterios de Aceptación:**
- [ ] Menú "Configuración" accesible desde home
- [ ] Opción "Idioma" con selector simple
- [ ] Opciones: "Español" e "Inglés"
- [ ] Al cambiar, actualiza toda la UI inmediatamente
- [ ] Nombres de documentos futuros usan nuevo idioma
- [ ] Documentos existentes mantienen su nombre original
- [ ] Guarda preferencia en SharedPreferences

---

## HISTORIAS ELIMINADAS (según ADDS.md v1.1)

### ~~HU-XXX: Capturar con detección automática~~ ❌ ELIMINADA
**Razón:** flutter_doc_scanner maneja esto nativamente

### ~~HU-XXX: Ajustar bordes manualmente~~ ❌ ELIMINADA
**Razón:** flutter_doc_scanner tiene su propio ajuste

### ~~HU-XXX: Organizar en carpetas simples~~ ❌ ELIMINADA
**Razón:** Simplificado a auto-detección de tipo sin carpetas manuales

---

## RESUMEN EJECUTIVO

### Por Prioridad

**CRÍTICAS (5 historias - hacer primero):**
- HU-001: Ver lista de documentos
- HU-002: Ver documento en detalle
- HU-007: Escanear documento
- HU-008: Guardar documento automáticamente
- HU-009: Extraer texto (OCR)

**ALTAS (5 historias):**
- HU-003: Eliminar con confirmación
- HU-004: Agregar nota
- HU-005: Buscar por texto
- HU-010: Auto-detectar tipo
- HU-013: Tutorial inicial

**MEDIAS (2 historias - pueden esperar):**
- HU-006: Búsqueda por voz
- HU-011: Extraer fecha vencimiento

**BAJAS (2 historias - post-MVP):**
- HU-012: Ver texto OCR
- HU-014: Cambiar idioma

### Por Épica

- **Épica 1 - Documents:** 3 historias (2 críticas, 1 alta)
- **Épica 2 - Notes:** 1 historia (alta)
- **Épica 3 - Search:** 2 historias (1 alta, 1 media)
- **Épica 4 - Scan:** 6 historias (3 críticas, 2 altas, 1 media, 1 baja)
- **Épica 5 - Onboarding:** 1 historia (alta)
- **Épica 6 - Configuration:** 1 historia (baja)

---

## ROADMAP SUGERIDO (según features)

### Sprint 1 (2 semanas): DOCUMENTS
- HU-001: Ver lista documentos
- HU-002: Ver detalle
- HU-003: Eliminar con confirmación

### Sprint 2 (1 semana): NOTES
- HU-004: Agregar nota

### Sprint 3 (1.5 semanas): SEARCH
- HU-005: Búsqueda por texto
- HU-006: Búsqueda por voz (opcional)

### Sprint 4 (2 semanas): SCAN (simplificado)
- HU-007: Botón ESCANEAR + scanner nativo
- HU-008: Guardar automático con nombre localizado
- HU-009: OCR background
- HU-010: Auto-detectar tipo

### Sprint 5 (0.5 semana): ONBOARDING
- HU-013: Tutorial 3 pasos

### Post-MVP:
- HU-011: Extraer fecha vencimiento
- HU-012: Ver texto OCR
- HU-014: Cambiar idioma

---

**Total estimado MVP:** ~7 semanas 