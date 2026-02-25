# Épica 6: Scanner OCR-First (v2)

**Fecha inicio:** 2026-02-03  
**Fecha actualización:** 2026-02-04  
**Estado:** Listo para implementación  
**Prioridad:** ALTA - Core de la app

---

## Objetivo

Implementar flujo de escaneo optimizado para OCR, con clasificación automática de tipo de documento, filtros inteligentes y generación de PDF A4 estandarizado.

---

## Decisiones Técnicas

### Scanner
- **Paquete:** flutter_doc_scanner
- **Método:** getScannedDocumentAsImages() → retorna JPG (Android) / PNG (iOS)

### Formato de almacenamiento
- **DB guarda:** PDF (A4 300DPI) + texto OCR + clasificación
- **Imagen original:** Se descarta después de generar PDF

### Especificaciones de imagen
- **Normalización OCR:** ≤650 KB
- **Normalización final:** A4 300DPI (2480x3508 px)
- **Compresión:** JPEG 85-90
- **Visualización:** pdfrx

---

## Clasificación de Documentos

### Tipos y nombres

| Clasificación | Nombre amigable | Descripción |
|---------------|-----------------|-------------|
| Factura | factura | Documento con código de barras |
| Foto | foto | Imagen sin texto significativo |
| Texto impreso | documento | Formularios, cartas, documentos oficiales |
| Manuscrito | nota | Texto escrito a mano |
| Ilustración+texto | folleto | Imágenes con texto (publicidades, catálogos) |

### Método de detección

1. **google_mlkit_barcode_scanning** → Detecta códigos de barras (prioridad máxima)
2. **google_mlkit_image_labeling** → Detecta contenido visual
3. **google_mlkit_text_recognition** → Detecta cantidad y regularidad de texto

### Lógica de clasificación

- **FACTURA:** Código de barras detectado (override sobre todas las demás)
- **FOTO:** Labels de imagen (person, food, landscape, etc.) + poco/nada de texto
- **DOCUMENTO:** Mucho texto + líneas muy regulares (mismo espaciado, tamaño uniforme)
- **NOTA:** Texto presente + líneas irregulares (variación en tamaño, inclinación, espaciado)
- **FOLLETO:** Labels de ilustración/dibujo + algo de texto

### Medición de regularidad

Usando bounding boxes de ML Kit:
- Varianza de altura de líneas
- Varianza de espaciado entre palabras
- Desviación de inclinación

Texto impreso → varianza baja  
Manuscrito → varianza alta

---

## Filtros por Tipo

| Tipo | Filtro | Razón |
|------|--------|-------|
| factura | Grayscale + contraste alto | Máxima legibilidad OCR |
| documento | Grayscale + contraste alto | Máxima legibilidad OCR |
| nota | Grayscale + contraste suave | Preservar trazos finos |
| folleto | Sin filtro | Preservar imágenes |
| foto | Sin filtro | Preservar imagen |

**Beneficio adicional:** Grayscale reduce tamaño del archivo final.

---

## Nombre Amigable Automático

### Formato

`{tipo}{correlativo} {día} {mes}`

### Ejemplos

- factura1 4 febrero
- foto1 4 febrero
- documento3 4 febrero
- nota2 4 febrero
- folleto1 4 febrero

### Correlativo

- Reinicia cada día
- Por tipo de clasificación
- Ej: Si hoy escaneé 2 documentos y 1 nota, el siguiente documento es "documento3" y la siguiente nota es "nota2"

---

## Flujo Completo

```
1. Usuario escanea con flutter_doc_scanner
              ↓
2. Obtiene JPG/PNG directo
              ↓
3. Normalizar peso (≤650 KB para OCR)
              ↓
4. Clasificar tipo (barcode_scanning + image_labeling + text_recognition)
              ↓
5. ¿Es FOTO?
      ├── SÍ → ¿Guardar en galería?
      │         ├── SÍ → Guardar en galería → FIN
      │         └── NO → Continúa como documento
      └── NO → Continúa
              ↓
6. Aplicar filtro según tipo
              ↓
7. Generar nombre amigable
              ↓
7.5. Generar nota con 10 primeras palabras del texto extraido
              ↓
8. Normalizar a A4 300DPI (2480x3508 px)
              ↓
9. Generar PDF
              ↓
10. Guardar en DB: PDF + texto OCR + clasificación + nota
              ↓
11. Descartar imagen temporal
```

---

## Etapas de Implementación (TDD)

**Orden:** Tests red →Domain → Tests green→ Data → UI

### Etapa 1: NormalizeImageForOcr

**Objetivo:** Reducir imagen a ≤650 KB para procesamiento OCR seguro

**Responsabilidades:**
- Recibir path de imagen (JPG o PNG)
- Convertir PNG a JPG si es necesario (iOS)
- Aplicar compresión iterativa (calidades: 90, 85, 80, 75, 70)
- Fallback: redimensionar 80% + calidad 85 si aún excede
- Retornar path de imagen normalizada

**Entradas:**
- Path de imagen original
- Target KB (default: 650)
- Calidad mínima (default: 70)

**Salidas:**
- Path de imagen normalizada
- Tamaño final en bytes
- Calidad usada
- Flag si requirió redimensionado

---

### Etapa 2: ClassifyDocumentType

**Objetivo:** Determinar tipo de documento escaneado

**Responsabilidades:**
- Procesar imagen con barcode_scanning (prioridad)
- Si hay barcode → clasificar como "factura"
- Si no hay barcode → procesar con image_labeling
- Procesar imagen con text_recognition
- Calcular regularidad de texto (varianza de bounding boxes)
- Retornar clasificación: factura | foto | documento | nota | folleto

**Entradas:**
- Path de imagen normalizada para OCR

**Salidas:**
- Tipo de clasificación
- Texto extraído (para guardar en DB)
- Código de barras (si existe)
- Confianza de clasificación (opcional)

---

### Etapa 3: ApplyFilterByType

**Objetivo:** Mejorar imagen según tipo para OCR y visualización

**Responsabilidades:**
- Aplicar grayscale + contraste alto para "documento"
- Aplicar grayscale + contraste suave para "nota"
- No aplicar filtro para "foto" y "folleto"
- Retornar imagen filtrada
**Entradas:**
- Path de imagen
- Tipo de clasificación

**Salidas:**
- Path de imagen filtrada

---

### Etapa 4: GenerateFriendlyName

**Objetivo:** Crear nombre automático legible

**Responsabilidades:**
- Mapear clasificación a nombre (foto/documento/nota/folleto)
- Obtener correlativo del día para ese tipo
- Formatear fecha (día + mes en español)
- Retornar nombre completo

**Entradas:**
- Tipo de clasificación
- Fecha actual

**Salidas:**
- Nombre amigable (ej: "documento3 4 febrero")

---

### Etapa 5: NormalizeToA4Pdf

**Objetivo:** Generar PDF estandarizado A4

**Responsabilidades:**
- Escalar imagen a 2480x3508 px (300 DPI)
- Rellenar con blanco abajo y derecha si no es A4
- Detectar orientación y rotar si es horizontal
- Generar PDF con paquete pdf
- Comprimir JPEG a calidad 85-90

**Entradas:**
- Path de imagen filtrada

**Salidas:**
- Path de PDF generado
- Tamaño final del PDF

---

### Etapa 6: SaveToGallery

**Objetivo:** Guardar foto en galería del dispositivo

**Responsabilidades:**
- Guardar imagen en galería nativa
- Manejar permisos
- Confirmar guardado exitoso

**Entradas:**
- Path de imagen

**Salidas:**
- Éxito/error
- Path en galería (si aplica)

---

### Etapa 7: Integración - ScanAndProcessDocument

**Objetivo:** Orquestar flujo completo

**Responsabilidades:**
- Llamar scanner
- Ejecutar normalización OCR
- Ejecutar clasificación
- Mostrar diálogo si es foto
- Ejecutar filtro
- Generar nombre
- Normalizar a A4
- Generar PDF
- Guardar en DB
- Limpiar temporales

**Entradas:**
- Ninguna (inicia desde UI)

**Salidas:**
- Documento guardado en DB
- O imagen guardada en galería (si eligió esa opción)

---

### Etapa 8: UI

**Objetivo:** Interfaz de usuario para el flujo

**Responsabilidades:**
- Botón de escaneo
- Indicador de progreso durante procesamiento
- Diálogo "¿Guardar en galería?" cuando detecta foto
- Feedback de éxito/error
- Navegación a documento guardado

---

## Dependencias

**Ya instaladas (no agregar nuevas):**
- flutter_doc_scanner - Scanner nativo
- google_mlkit_text_recognition - OCR
- google_mlkit_image_labeling - Clasificación visual
- google_mlkit_barcode_scanning - Detección de códigos de barras
- image - Procesamiento (resize, compress, grayscale)
- pdf - Generación de PDF
- pdfrx - Visualización de PDF

---

## Fuera de Alcance (Esta Épica)

- Combinar múltiples PDFs en exportación
- Detección de fecha de vencimiento
- Detección de monto de vencimiento
- Edición de documento post-guardado

---

## Riesgos y Mitigación

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Clasificación incorrecta | Media | Usuario puede renombrar manualmente después |
| Crash en dispositivos viejos | Baja | Normalización a 650KB previene OOM |
| OCR malo en manuscrito | Media | Filtro suave preserva trazos |
| Foto clasificada como documento | Baja | Diálogo de galería da segunda oportunidad |

---

## Criterio de Éxito

- Usuario escanea documento y se guarda automáticamente con nombre descriptivo
- Clasificación correcta en 80%+ de casos
- Sin crashes en dispositivos con 2GB RAM
- OCR extrae texto legible de documentos y notas
- Fotos pueden guardarse en galería si el usuario lo desea
- PDF visualizable correctamente con pdfrx

---

## Notas Finales

Este flujo prioriza OCR (corazón de la app) y automatiza la mayor cantidad de decisiones posibles para el usuario target (personas mayores). El diálogo de galería para fotos es la única interrupción del flujo automático.

La clasificación en 4 tipos sienta las bases para features futuras (vencimientos, montos, búsqueda por tipo).

---

**Documento listo para implementación TDD.**
