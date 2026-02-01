# Cambios Propuestos - EscanDoc

## ✅ CAMBIOS CONFIRMADOS

### 1. Sistema de Nombres Dual

**Nombre Técnico (invisible para usuario):**
- Formato: tipo_dia_mes_año
- Ejemplo: factura_25_Ene_2026
- Uso: Orden interno, sistema, archivos
- Nunca se muestra en UI

**Nombre Amigable (visible para usuario):**
- Formato: [Tipo] [Empresa/Entidad] [Mes/Periodo]
- Ejemplos: "Factura EDESUR Enero", "Recibo OSDE Diciembre"
- Generado por OCR automáticamente
- Usuario puede editar
- Objetivo: 95% de casos el usuario no necesita editarlo
- Búsqueda funciona sobre este nombre

**Desafío técnico:**
- OCR debe detectar empresa/entidad confiablemente
- Requiere testing con facturas argentinas reales

---

### 2. Visualización de OCR

**Estado actual:**
- Texto extraído se guarda pero nunca se muestra
- Solo se usa para búsqueda interna

**Cambio:**
- OCR debe ser visible para el usuario
- Casos de uso: copiar texto, verificar extracción, entender naming

---

### 3. Rediseño DocumentDetailPage

**Nueva estructura (3 secciones verticales):**

**Sección 1 - Foto (50% altura):**
- Preview del documento escaneado
- Tap → abre fullscreen con zoom

**Sección 2 - Nota (20% altura):**
- Preview de la nota del usuario
- Tap → abre editor de nota

**Sección 3 - Texto OCR (30% altura):**
- Preview del texto extraído
- Tap → abre vista completa para lectura/copia
- Si OCR vacío → mostrar "No se pudo extraer texto"

**Características:**
- Las 3 secciones siempre visibles
- Sin tabs, sin opciones, sin configuración
- Navegación por tap directo
- Sin settings de visibilidad de secciones

---

### 4. Posicionamiento de Producto

**Ajuste estratégico:**
- NO posicionar como "app para ancianos"
- Posicionar como "simple y efectiva para todos"
- Diseño elderly-friendly ≠ elderly-only marketing
- Features atractivas para todas las edades: scan + OCR + notas integradas

---

## ⏸️ PENDIENTES DE DECISIÓN

### A. Scanner

**Problema identificado:**
- Scanner nativo (flutter_doc_scanner) tiene muchas opciones que confunden
- Funciona mal con poca luz
- UI con filtros, mejoras, recortar en chips scrolleables = complejo

**Opciones ELEGIDA:**

flutter_document_scanner: ^1.1.2

---

### B. Simplificación de Modelo de Datos

**Problema identificado:**
- 8 campos por documento (excesivo)
- Redundancia: doc_type duplicado en nombre
- Nota con título + contenido confunde

**Posible simplificación:**
- Reducir a 5 campos esenciales
- Eliminar redundancias
- Simplificar estructura de notas

**Estado:** Funcional como está. Refactor solo si usuarios se confunden.

---

### C. Tests

**Situación:**
- 74 tests unitarios funcionando
- 37 tests de integración skippeados (cambio sqflite → sqflite_sqlcipher)

**Opciones:**
1. Borrar tests obsoletos
2. Rediseñar con mocks (5-10 tests clave)
3. Crear E2E tests en integration_test/
4. Dejar como está

**Estado:** Testing manual suficiente por ahora. Rediseño si se necesita CI/CD.

---

## 📋 PRÓXIMOS PASOS

1. Validar detección de empresa por OCR con facturas reales
2. Definir algoritmo de generación de nombre amigable
3. Diseñar UI de las 3 secciones en detalle
4. Decidir sobre scanner (probar alternativas)
5. Crear backlog priorizado de ajustes UI secundarios

---

## 🎯 PRINCIPIOS DE ITERACIÓN

- No refactorizar "por diseño bonito"
- No agregar configuración "por si acaso"
- Cambios basados en necesidad real, no supuesta
- Testing manual válido en fase actual
- Simplicidad > Features