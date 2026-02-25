# EscanDoc - Implementación Scanner Custom

**Decisión:** flutter_document_scanner ^1.1.2  
**Fecha:** 1 Febrero 2026  
**Estado:** Pre-implementación

---

## 1. CONTEXTO DE LA DECISIÓN

### Problema identificado
- Scanner nativo actual (flutter_doc_scanner) confunde con múltiples opciones
- UI no optimizada para usuarios mayores
- Performance deficiente en luz baja
- Falta de control sobre experiencia de usuario

### Requerimientos clave
- UI minimalista y clara para personas mayores (60-85 años)
- Botones grandes (60dp mínimo)
- Proceso simple sin opciones confusas
- Performance aceptable en dispositivos low-end
- Buen funcionamiento en condiciones de luz baja

---

## 2. DATOS TÉCNICOS FLUTTER_DOCUMENT_SCANNER

### Características principales

**Tecnología:**
- OpenCV en Android (detección de bordes, corrección perspectiva)
- VisionKit en iOS
- UI completamente customizable en Flutter
- Controller con estados reactivos (streams)

**Mantenimiento:**
- Último commit: Abril 2025
- Versión actual: 1.1.2
- Estado: Activo (no abandonado)
- Puntuación pub.dev: 140/140 (salud alta)
- GitHub: 51 estrellas, 48 forks, 86 commits

**Impacto técnico:**
- Tamaño APK: +10-20 MB (vs +2-5 MB cunning, +30-40 MB opencv_dart)
- Complejidad código: 100-200 líneas para básico
- Tiempo implementación: 1-2 días
- Setup nativo: Mínimo (OpenCV incluido)

### Limitaciones conocidas

**Funcionalidades NO soportadas:**
- Detección de contornos en tiempo real
- Captura múltiple simultánea
- Control de errores mejorado

**Restricciones de performance:**
- Overhead en dispositivos low-end (2-5 segundos procesamiento)
- CPU alto en stream intensivo
- Sin configuración nativa para ajuste de exposición/luz

**Luz baja:**
- No tiene parámetros específicos para mejorar captura
- Filtros post-captura: natural, gray, eco
- Gray (escala grises) ayuda en condiciones difíciles
- OpenCV mejor que MLKit en sombras/gradientes (+10-15% precisión)

### Estabilidad en producción

**Issues reportados:**
- ✅ Cero memory leaks conocidos
- ✅ Cero crashes reportados en 2025-2026
- ✅ Sin quejas en Stack Overflow/Reddit
- ✅ Funciona bien en apps reales (clones CamScanner)

**Comparación con alternativas:**
- Más preciso que cunning (MLKit): 80-90% vs 70-80% edge detection
- Más lento que cunning en low-end: 2-5s vs <1s
- Más customizable que cualquier alternativa
- Más pesado que cunning pero menos que opencv_dart custom

---

## 3. ARQUITECTURA DE IMPLEMENTACIÓN

### Estructura del feature

```
lib/features/scanner_custom/
├── data/
│   ├── models/
│   │   └── scanned_document_model.dart
│   └── repositories/
│       └── scanner_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── scanned_document.dart
│   └── usecases/
│       ├── scan_document_custom.dart
│       └── apply_custom_filter.dart
└── presentation/
    ├── providers/
    │   └── scanner_custom_provider.dart
    ├── pages/
    │   └── scanner_custom_page.dart
    └── widgets/
        ├── custom_camera_view.dart
        ├── custom_crop_view.dart
        └── custom_filter_selector.dart
```

### Flujo de datos

```
1. Usuario toca botón ESCANEAR
2. scanner_custom_page abre DocumentScanner widget
3. Usuario captura foto (takePhoto)
4. Auto-crop con ajuste manual opcional (cropPhoto)
5. Aplicar filtro gray por defecto (applyFilter)
6. Guardar documento (savePhotoDocument)
7. Retornar Uint8List a ScanProvider
8. ScanProvider → SaveScannedDocument usecase
9. Guardado en BD + generación PDF/thumbnail
```

### Controller personalizado

**Acciones disponibles:**
- takePhoto (con parámetros opcionales minContourArea)
- cropPhoto
- applyFilter (FilterType: natural, gray, eco)
- savePhotoDocument
- changePage (navegación interna)
- findContoursFromExternalImage (galería)

**Estados observables (streams):**
- statusTakePhotoPage
- statusCropPhoto
- statusEditPhoto
- currentFilterType
- statusSavePhotoDocument
- currentPage

**Datos accesibles:**
- pictureTaken (File)
- pictureCropped (Uint8List)

---

## 4. PLAN DE IMPLEMENTACIÓN

### FASE 1: Setup y Prueba Básica (4 horas)

**Objetivo:** Verificar que el paquete funciona en el proyecto

**Tareas:**
1. Agregar dependencia en pubspec.yaml
2. Configurar permisos cámara (AndroidManifest.xml, Info.plist)
3. Crear página de prueba mínima
4. Inicializar DocumentScannerController
5. Implementar DocumentScanner widget básico
6. Probar captura simple en emulador
7. Probar en dispositivo real (Moto G52)

**Criterios de éxito:**
- App compila sin errores
- Scanner abre correctamente
- Captura foto y retorna bytes
- No crashes en device real

**Plan B si falla:**
- Revisar versiones de dependencias
- Verificar configuración nativa
- Si persisten errores → evaluar cunning_document_scanner

---

### FASE 2: Customización UI Minimalista (1 día)

**Objetivo:** Adaptar UI para usuarios mayores

**Customizaciones necesarias:**

**GeneralStyles:**
- Ocultar diálogos default (hideDefaultDialogs: true)
- Textos en español customizados
- Indicadores de progreso simples

**Camera settings:**
- resolutionCamera: ResolutionPreset.high
- initialCameraLensDirection: back (no selfie)

**Page styles personalizados:**

**TakePhotoPage:**
- Botón captura GIGANTE (80x80 dp mínimo)
- Sin opciones extras visibles
- Texto claro "CAPTURAR DOCUMENTO"
- Flash automático en luz baja (si posible)

**CropPage:**
- 4 puntos de ajuste GRANDES (60dp touch area)
- Contraste alto (puntos blancos sobre overlay oscuro)
- Botones "ACEPTAR" y "REPETIR" grandes
- Sin gestures complejos

**EditPage:**
- Solo filtro "gray" por defecto (sin selector visible)
- Botón "GUARDAR" prominente
- Sin opciones de filtros múltiples (simplificar)

**Criterios de éxito:**
- UI limpia sin elementos confusos
- Botones fáciles de tocar (probado en device)
- Flujo intuitivo sin explicación necesaria

---

### FASE 3: Integración con Arquitectura Existente (6 horas)

**Objetivo:** Conectar scanner con sistema de documentos

**Tareas:**

**1. Crear ScannerCustomRepository**
- Wrapper del DocumentScannerController
- Manejo de estados del controller
- Conversión de datos a domain entities

**2. Actualizar ScanProvider**
- Integrar nuevo scanner en lugar del nativo
- Mantener mismo flujo: scan → OCR → clasificación → guardado
- Reutilizar SaveScannedDocument usecase existente

**3. Actualizar HomePage**
- Cambiar navegación de /scan a /scanner_custom
- Mantener mismo botón ESCANEAR (UI consistente)

**4. Testing de integración**
- Flujo completo: scan → guardar → listar → buscar
- Verificar OCR funciona con nuevas imágenes
- Verificar clasificación automática
- Verificar generación de nombres amigables

**Criterios de éxito:**
- Documentos escaneados se guardan correctamente
- OCR extrae texto
- Búsqueda encuentra documentos nuevos
- No regresiones en features existentes

---
SUGERENCIA:
5. Validar tamaño imagen temporal
  - Si PNG temporal > 50MB → downscale automático
  - Target: 10-20MB para OCR óptimo


### FASE 4: Optimización Luz Baja (4 horas)

**Objetivo:** Mejorar captura en condiciones difíciles

**Estrategias:**

**1. Filtro gray por defecto**
- Aplicar automáticamente después de crop
- Mejora contraste y reduce ruido
- Equivalente a binarización básica

**2. Validación de calidad**
- Detectar blur con algoritmo simple (Laplace variance)
- Mostrar alerta "Imagen borrosa, intenta con más luz"
- Botón "REINTENTAR" prominente

**3. Feedback visual**
- Indicador de luz ambiente (si API lo permite)
- Sugerencia "Activa el flash" si muy oscuro
- Tutorial primera vez sobre iluminación

**4. Testing en condiciones reales**
- Probar con facturas reales en diferentes luces
- Probar en habitación oscura
- Probar con luz natural variada
- Documentar casos problemáticos

**Criterios de éxito:**
- 80%+ documentos escaneables en luz moderada-baja
- Feedback claro cuando calidad es mala
- Usuario puede reintentar fácilmente

---
SUJERENCIA!!!
5. Comprimir imagen temporal para OCR
  - Convertir PDF → JPEG (quality 85) en lugar de PNG
  - Reducir 40-60% tamaño sin afectar OCR
  - ML Kit funciona perfecto con JPEG
2. En configuración (línea 189):
   resolutionCamera: ResolutionPreset.medium // En lugar de high
   // Medium es suficiente para OCR y reduce 50% tamaño


### FASE 5: Testing con Usuario Target (1 día)

**Objetivo:** Validar con persona mayor real

**Preparación:**
- App compilada en APK release
- Instalada en dispositivo del usuario
- 5 documentos reales para escanear

**Tareas del usuario (observar sin ayudar):**
1. Escanear factura de luz
2. Escanear recibo de farmacia
3. Escanear documento médico
4. Buscar documento escaneado
5. Agregar nota a documento

**Métricas a observar:**
- ¿Completa escaneo sin ayuda? (SÍ/NO)
- ¿Se confunde en algún paso? (dónde)
- ¿Documenta escaneado es legible? (SÍ/NO)
- ¿Número de intentos por documento? (ideal: 1-2)
- ¿Expresa frustración? (cuándo)
- ¿Qué dice espontáneamente?

**Ajustes post-testing:**
- Priorizar según pain points observados
- Iterar UI si hay confusión
- Simplificar más si es necesario

**Criterios de éxito:**
- Usuario completa 4/5 tareas sin ayuda
- Máximo 2 intentos por documento
- No expresa frustración crítica
- Dice algo positivo espontáneamente

---

## 5. RIESGOS Y MITIGACIÓN

### Riesgos técnicos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Performance pobre en low-end | Media | Alto | Reducir resolution, aplicar filtro gray, optimizar processing |
| Luz baja insuficiente | Media | Alto | Validación blur, feedback claro, tutorial iluminación |
| Integración compleja | Baja | Medio | Seguir arquitectura existente, reutilizar usecases |
| Bugs no descubiertos del paquete | Baja | Alto | Testing extensivo, plan B con cunning listo |

### Riesgos de UX

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| UI aún confusa para usuario | Media | Alto | Testing iterativo con usuario real, simplificar más si necesario |
| Proceso muy largo | Baja | Medio | Medir tiempo real, optimizar si >15 segundos |
| Ajuste manual difícil | Media | Medio | Puntos touch grandes, tutorial primera vez |

---

## 6. MÉTRICAS DE ÉXITO

### Técnicas
- ✅ App compila y corre sin crashes
- ✅ Documentos se guardan correctamente
- ✅ OCR extrae texto 85%+ casos
- ✅ Tiempo escaneo <15 segundos total
- ✅ Tamaño APK <70 MB (con split-per-abi)

### UX
- ✅ Usuario completa escaneo sin ayuda
- ✅ Máximo 2 intentos por documento
- ✅ 80%+ documentos legibles en luz moderada
- ✅ Sin frustración expresada por usuario
- ✅ Feedback positivo espontáneo

### Comparativa
- ✅ Mejor que scanner nativo actual en simplicidad
- ✅ Similar o mejor precisión que scanner nativo
- ✅ Funciona en 90%+ casos de uso reales

---

## 7. ROLLBACK PLAN

### Si flutter_document_scanner falla

**Señales de alerta:**
- Crashes frecuentes en device real
- Performance inaceptable (<80% documentos en 1-2 intentos)
- Usuario no puede completar tareas básicas
- Bugs críticos sin solución

**Plan B inmediato:**
1. Revertir a flutter_doc_scanner (actual)
2. Implementar cunning_document_scanner (0.5 días)
3. Testing rápido en device
4. Decidir entre cunning o mantener actual

**Plan C (última opción):**
- Evaluar opencv_dart custom solo si:
  - Ambos paquetes fallan críticamente
  - Proyecto tiene recursos para 2-4 semanas dev
  - Aceptación de riesgos de memory leaks

---

## 8. TIMELINE TOTAL

**Estimación conservadora:** 3 días (24 horas)

| Fase | Duración | Acumulado |
|------|----------|-----------|
| Setup y Prueba | 4h | 4h |
| Customización UI | 8h | 12h |
| Integración | 6h | 18h |
| Optimización Luz Baja | 4h | 22h |
| Testing Usuario | 8h | 30h |
| **Buffer (imprevistos)** | 6h | **36h** |

**Distribución realista:** 4-5 días calendario

---

## 9. DEPENDENCIAS

### Packages requeridos
- flutter_document_scanner: ^1.1.2 (principal)
- camera: instalado vía flutter_document_scanner
- Mantener actuales: provider, sqflite_sqlcipher, google_mlkit_text_recognition, etc.

### Permisos necesarios

**Android (AndroidManifest.xml):**
- CAMERA
- WRITE_EXTERNAL_STORAGE (si guarda temporales)
- READ_EXTERNAL_STORAGE (para galería)

**iOS (Info.plist):**
- NSCameraUsageDescription
- NSPhotoLibraryUsageDescription

### Configuración nativa
- Mínimo requerido (OpenCV incluido en paquete)
- Sin CMakeLists custom
- Sin modificaciones Gradle complejas

---

## 10. PRÓXIMOS PASOS INMEDIATOS

**Antes de codear:**
1. Crear branch feature/scanner-custom
2. Documentar estado actual (screenshots scanner nativo)
3. Definir criterios exactos de éxito con ejemplos

**Día 1:**
1. FASE 1 completa (setup + prueba básica)
2. Primera prueba en Moto G52
3. Decisión GO/NO-GO para continuar

**Si GO:**
- FASE 2-3 (customización + integración)

**Si NO-GO:**
- Evaluar cunning_document_scanner mismo día

---

## 11. NOTAS FINALES

**Ventajas decisión:**
- ✅ OpenCV integrado sin mantenerlo
- ✅ UI customizable para target específico
- ✅ Sin memory leaks conocidos
- ✅ Estable en producción

**Desventajas aceptadas:**
- ⚠️ +10-20 MB APK (aceptable)
- ⚠️ Overhead low-end mitigable
- ⚠️ Sin real-time detection (no necesario MVP)

**Filosofía:**
- Pragmatismo > perfección técnica
- Validación rápida > planificación extensa
- Usuario real > supuestos de diseño

**Criterio de éxito principal:**
Si mamá puede escanear 3 facturas seguidas sin ayuda y sin frustración → ÉXITO TOTAL.

---

**Documento generado:** 1 Feb 2026  
**Próxima revisión:** Post-implementación FASE 1  
**Responsable:** Mario (EscanDoc Lead Dev)