# DocScan Pro - Product Vision Document

**Fecha:** 17 de Enero 2026  
**Versión:** 1.0  
**Autor:** Proyecto personal post-QuehaCeMos

---

## 1. VISIÓN DEL PRODUCTO

### Problema que resuelve
Las personas mayores (60-85 años) necesitan digitalizar, organizar y recordar vencimientos de documentos importantes (facturas, recibos, contratos, documentos médicos), pero las apps actuales son:
- Caras ($10/mes Adobe Scan)
- Invasivas (CamScanner lleno de ads)
- Complejas (UI confusa, muchas features innecesarias)
- Sin integración real (scan separado de notas, separado de recordatorios)

### Solución
**DocScan Pro: la app de escaneo sin ads, sin marca de agua, con notas y vencimientos integrados. Simple, privada, y diseñada para que tu abuela pueda usarla.**

Integra 3 funcionalidades que normalmente requieren 3 apps diferentes:
1. **Scanner de documentos** con OCR offline
2. **Block de notas** vinculable a documentos
3. **Sistema de vencimientos** con notificaciones programables

---

## 2. USUARIOS OBJETIVO

### Usuario Primario
**Persona mayor (60-85 años), no tech-savvy**
- Necesita escanear facturas de servicios, recibos, documentos médicos
- Olvida vencimientos de pagos
- Pierde documentos físicos importantes
- No entiende interfaces complejas
- Prefiere pagar una vez vs suscripciones

### Usuario Secundario
**Adultos 40-60 años organizados**
- Necesitan sistema simple para documentos del hogar
- Quieren todo en un lugar (docs + notas + vencimientos)
- Valoran privacidad sobre apps gratuitas chinas

---

## 3. DIFERENCIADORES CLAVE

### vs Competencia
| Feature | Adobe Scan | CamScanner | Microsoft Lens | **DocScan Pro** |
|---------|-----------|------------|----------------|-----------------|
| Precio | $10/mes | $40/año | Gratis | **$3/mes, $25/año, $50/5 años** |
| Notas integradas | ❌ Básicas | ❌ Básicas | ❌ No | **✅ Completas** |
| Vencimientos | ❌ No | ❌ No | ❌ No | **✅ Sí** |
| **Notas + Vencimientos integrados** | **❌ No** | **❌ No** | **❌ No** | **✅ ÚNICO** |
| Smart tagging | ❌ No | ❌ No | ❌ No | **✅ Auto-categoriza** |
| Búsqueda por voz | ❌ No | ❌ No | ❌ No | **✅ Sí** |
| UI para mayores | ❌ No | ❌ No | ❌ No | **✅ Diseñada para ello** |
| Ads en free | ❌ No | ❌ Invasivos | ✅ No | **✅ Sin ads** |
| Watermark free | ✅ No | ❌ Sí | ✅ No | **✅ Sin marca** |
| Privacidad | ⚠️ Adobe AI | ❌ Malware 2019 | ⚠️ Microsoft | **✅ Local-first** |

### Propuesta de Valor Única
**"3 apps en 1, diseñada para que personas mayores la usen sin ayuda"**

---

## 4. FEATURES - SCOPE DEFINIDO

### 🟢 MVP - FASE 1 (3 meses)
**Módulo DOCUMENTOS con notas básicas**

#### Core Features
- ✅ **Escaneo con cámara**
  - Detección automática de bordes
  - Pre-procesamiento (crop, deskew, contraste, binarización)
  - Ajuste manual fácil (botón grande visible)
  - Guardar como PDF o imagen
  
- ✅ **OCR offline**
  - Google ML Kit (gratis, offline)
  - Extrae texto del documento
  - Searchable (búsqueda dentro del texto)
  - Precisión esperada: 85-95% en documentos bien iluminados

- ✅ **Smart Tagging Automático** (DIFERENCIADOR)
  - Auto-detecta tipo documento (factura, recibo, contrato)
  - Auto-extrae fecha de vencimiento del OCR
  - Auto-sugiere categoría basada en contenido
  - Pregunta si crear recordatorio (sin forzar)

- ✅ **Notas simples integradas**
  - Una nota por documento (título + cuerpo texto plano)
  - Vinculación bidireccional doc ↔ nota
  
- ✅ **Organización básica**
  - Carpetas manuales (Facturas, Recibos, Contratos, Personal, Médico, Otros)
  - Lista con thumbnails grandes
  - Grid view opcional

- ✅ **Búsqueda**
  - Búsqueda por texto en notas
  - Búsqueda por texto OCR en documentos
  - **Búsqueda por voz** (speech_to_text)
  - Búsqueda global (docs + notas)

- ✅ **UI para personas mayores**
  - Botones GIGANTES (mínimo 60x60 dp)
  - Texto GRANDE (18sp mínimo, 24sp títulos)
  - Contraste ALTO (negro sobre blanco)
  - 1 acción principal por pantalla
  - Confirmaciones claras con botones SÍ/NO grandes
  - Sin gestos raros (swipe, long-press)
  - Feedback visual inmediato

#### Límites Free vs Pro
**Free:**
- 15 documentos máximo
- Todas las features básicas
- Sin ads, sin marca de agua
- OCR completo

**Pro ($2.99/mes o $49.99 lifetime):**
- Documentos ilimitados
- Cloud backup (Firebase Storage opcional)
- Categorización automática mejorada con AI
- Búsqueda avanzada (filtros fecha, categoría)
- Export batch (ZIP múltiples docs)

---

### 🟡 FASE 2 (si MVP funciona - 2 meses)
**Módulo VENCIMIENTOS integrado**

- ✅ Crear vencimiento (título + fecha)
- ✅ Notificaciones programables (1 día, 3 días, 1 semana antes)
- ✅ Adjuntar documento a vencimiento
- ✅ Marcar como "Pagado/Resuelto"
- ✅ Integración: desde documento → crear vencimiento automático
- ⚠️ NO: vencimientos recurrentes complejos (solo simples)

**Pro adicional en Fase 2:**
- Vencimientos ilimitados (free: 10 activos)
- Recordatorios múltiples por vencimiento
- Templates de vencimientos comunes

---

### 🔵 FASE 3 (si Fase 2 funciona - 1 mes)
**Módulo NOTAS independiente + integraciones avanzadas**

- ✅ Notas independientes (sin documento vinculado)
- ✅ Markdown support en notas
- ✅ Checklist dentro de notas
- ✅ Adjuntar múltiples documentos a nota
- ✅ Templates de documentos pre-cargados:
  - "Nueva factura de servicio" (Edesur, Ecogas, etc.)
  - "Nuevo recibo médico"
  - "Documento de auto" (seguro, VTV, patente)

---

### 🚫 FEATURES EXPLÍCITAMENTE FUERA DE SCOPE (evitar scope creep)
- ❌ Edición avanzada de PDF
- ❌ Firmas digitales
- ❌ Colaboración multi-usuario
- ❌ Anotaciones/markup en PDFs
- ❌ Fax integration
- ❌ QR/barcode scanning avanzado
- ❌ Integración con servicios de pago
- ❌ Calendarios múltiples
- ❌ Sync con Google Calendar
- ❌ OCR de texto manuscrito (no funciona bien)

---

## 5. STACK TÉCNICO

### Frontend
**Flutter 3.x** (Android + iOS)

**Packages clave:**
```yaml
dependencies:
  # Camera & Image
  camera: ^0.10.x
  image_picker: ^1.0.x
  image: ^4.0.x  # Pre-procesamiento
  edge_detection: ^1.0.x
  
  # OCR
  google_ml_kit: ^0.16.x  # Offline, gratis
  
  # PDF
  pdf: ^3.10.x
  printing: ^5.11.x
  
  # Database
  sqflite: ^2.3.x
  path_provider: ^2.1.x
  
  # Search
  # SQLite FTS (Full-Text Search) nativo
  
  # Voice
  speech_to_text: ^6.x
  
  # Notifications (Fase 2)
  flutter_local_notifications: ^16.x
  
  # State Management
  provider: ^6.1.x  # Simple, bien conocido
  
  # Storage
  shared_preferences: ^2.2.x
  
  # Cloud (Pro)
  firebase_core: ^2.24.x
  firebase_storage: ^11.6.x
  cloud_firestore: ^4.14.x
  
  # Monetization
  in_app_purchase: ^3.1.x
  # Considerar RevenueCat para simplificar
```

### Backend
**Firebase** (mínimo, solo para Pro)
- Firebase Storage: backup documentos
- Firestore: metadata sync opcional
- Firebase Auth: cuentas simples (email/password)

### Base de Datos Local
**SQLite con FTS5** (Full-Text Search)

Esquema principal:
```sql
-- Documentos
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  file_path TEXT NOT NULL,
  ocr_text TEXT,
  thumbnail_path TEXT,
  category TEXT DEFAULT 'Otros',
  auto_detected_type TEXT,  -- factura, recibo, contrato
  extracted_date DATE,       -- fecha extraída por OCR
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME
);

-- Notas
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  content TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME
);

-- Vencimientos (Fase 2)
CREATE TABLE due_dates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  due_date DATE NOT NULL,
  notification_days_before INTEGER DEFAULT 1,
  is_resolved BOOLEAN DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Relaciones
CREATE TABLE document_notes (
  document_id INTEGER,
  note_id INTEGER,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,
  PRIMARY KEY(document_id, note_id)
);

CREATE TABLE document_due_dates (
  document_id INTEGER,
  due_date_id INTEGER,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY(due_date_id) REFERENCES due_dates(id) ON DELETE CASCADE,
  PRIMARY KEY(document_id, due_date_id)
);

-- Full-text search indexes
CREATE VIRTUAL TABLE documents_fts USING fts5(
  title, ocr_text, content=documents, content_rowid=id
);

CREATE VIRTUAL TABLE notes_fts USING fts5(
  title, content, content=notes, content_rowid=id
);
```

### Arquitectura
**Clean Architecture simplificada**

```
lib/
├── core/
│   ├── database/
│   │   └── database_helper.dart
│   ├── constants/
│   │   └── app_constants.dart
│   └── utils/
│       ├── date_formatter.dart
│       └── ocr_date_extractor.dart
├── features/
│   ├── documents/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── widgets/
│   │       └── providers/
│   ├── notes/
│   │   └── [misma estructura]
│   └── due_dates/  (Fase 2)
│       └── [misma estructura]
└── main.dart
```

---

## 6. ESTRATEGIA DE DESARROLLO

### Metodología
- **Historias de usuario** con criterios de aceptación
- **TDD**: Test unitario por criterio, test integración por historia
- **Validación real**: testing iterativo con mamá de 85 años
- **Sin prisa**: arquitectura limpia > velocidad

### Testing Strategy
```
test/
├── unit/
│   ├── repositories/
│   ├── usecases/
│   └── utils/
├── widget/
│   └── ui_components/
├── integration/
│   └── user_flows/
└── accessibility/
    └── elderly_ux/
```

**Métricas clave a testear:**
- ¿Persona mayor completa tarea sin ayuda? (sí/no)
- Número de toques para tarea básica (<5 ideal)
- ¿Se frustra o dice "no entiendo"? (indicador crítico)
- Retention 7 días (>40% = product-market fit)

### Environment
- **IDE:** Android Studio
- **Emulador:** Pixel 3a - API 30
- **Testing físico:** Dispositivos reales de personas mayores

### Roadmap
| Fase | Duración | Entregable |
|------|----------|------------|
| Setup + Arquitectura | 2 semanas | Estructura proyecto, DB schema, models |
| Módulo Scan | 3 semanas | Cámara, crop, mejora imagen, guardar PDF |
| OCR + Search | 2 semanas | ML Kit integration, FTS, búsqueda voz |
| Notas básicas | 2 semanas | CRUD notas, vinculación docs |
| Smart Tagging | 2 semanas | Auto-detección tipo, extracción fecha |
| UI Polish | 2 semanas | Diseño elderly-friendly, onboarding |
| Testing con mamá | 2 semanas | Validación, iteraciones, fixes |
| **TOTAL FASE 1** | **~3 meses** | **MVP listo para publicar** |

---

## 7. MONETIZACIÓN

### Modelo de Pricing
**4 opciones de pago** (optimizado para personas mayores):

1. **Gratis**
   - 15 documentos
   - 30 notas
   - Todas las features básicas
   - Sin ads, sin marca de agua
   - OCR completo

2. **Pro Mensual: $2.99 USD/mes**
   - Todo ilimitado
   - Cloud backup
   - Categorización automática mejorada
   - Export batch

3. **Pro Anual: $24.99 USD/año**
   - Mismo que Pro mensual
   - Ahorro ~30% vs mensual
   - Opción intermedia

4. **Licencia Extendida: $49.99 USD** (one-time)
   - Válida por 5 años desde la compra
   - Acceso completo sin mensualidades
   - Opción de renovar con descuento al finalizar
   - **Preferido por personas mayores** (5 años = prácticamente lifetime para el uso típico)

### Proyección Realista (pesimista)
**Año 1:**
- Mes 1-3: Desarrollo
- Mes 4-6: Launch + ASO + primeros usuarios
- Mes 7-12: Crecimiento orgánico por reviews

**Métricas esperadas:**
- 500-1000 descargas/mes (con ASO decente)
- 3-5% conversión a Pro = 15-50 usuarios pagos
- Mix esperado: 50% licencia extendida ($50) + 30% anual ($25) + 20% mensual ($3)
- **Ingreso mensual: $50-150 USD** (conservador)

**Año 2:**
- 1000-2000 descargas/mes (reviews orgánicas)
- 5-7% conversión = 50-140 usuarios pagos
- **Ingreso mensual: $150-400 USD**

### Implementación IAP
- **RevenueCat** preferible (maneja complejidad cross-platform)
- Botón "Restaurar compras" MUY visible
- Cancelación en 1 toque desde app
- Email confirmación inmediato
- Sin contratos anuales forzados (lección de Adobe Scan)

---

## 8. ESTRATEGIA DE LANZAMIENTO

### Pre-Launch
- [ ] Validación completa con mamá de 85 años (min 2 semanas uso real)
- [ ] 5+ iteraciones de UX basadas en feedback
- [ ] 20+ screenshots de alta calidad
- [ ] Video demo (30 seg) mostrando simplicidad

### ASO (App Store Optimization)
**Keywords principales:**
- "document scanner"
- "PDF scanner"
- "receipt scanner"
- "scanner sin marca de agua"
- "escanear documentos gratis"
- "OCR español"

**Descripción enfocada en:**
- Simple para personas mayores
- Sin ads, sin marca de agua
- 3 apps en 1 (docs + notas + vencimientos)
- Privacidad (datos locales)

### Launch Strategy
1. **Soft launch:** Argentina primero (mercado conocido)
2. **Early reviews:** pedir a familia/amigos mayores (5-10 reviews)
3. **Iteración rápida:** fix bugs críticos primera semana
4. **Expansión:** LATAM, luego global

---

## 9. RIESGOS Y MITIGACIÓN

### Riesgos Técnicos
| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| OCR pobre calidad | Media | Alto | Pre-procesamiento agresivo + tests con docs reales |
| Crop automático falla | Media | Alto | Botón ajuste manual MUY visible, tutorial claro |
| Performance en devices viejos | Media | Medio | Optimizar procesamiento, tests en Pixel 3a |
| Storage se llena rápido | Baja | Medio | Compresión inteligente, límite docs en free |

### Riesgos de Producto
| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Scope creep | Alta | Alto | PVD como norte, decir NO a features extra |
| UI muy compleja | Media | Alto | Testing iterativo con mamá, simplicidad > features |
| No hay product-market fit | Media | Alto | Validación temprana, pivotar si <40% retention 7 días |
| Competencia lanza similar | Baja | Medio | Velocidad + nicho (elderly UX) difícil copiar |

### Riesgos de Monetización
| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Conversión <3% | Media | Medio | Licencia extendida + anual + mensual, valor claro, onboarding strong |
| Pocas descargas | Media | Alto | ASO correcto, reviews tempranas, nicho claro |
| Refunds por bugs | Baja | Medio | Testing exhaustivo pre-launch, fix rápido post |

---

## 10. MÉTRICAS DE ÉXITO

### Fase 1 (MVP)
**Validación con mamá:**
- ✅ Completa escaneo sin ayuda
- ✅ Encuentra documento escaneado días después
- ✅ Crea nota vinculada sin frustrarse
- ✅ Usa app 3+ veces por semana

**Métricas público:**
- 40%+ retention a 7 días
- Rating >4.5 estrellas (min 20 reviews)
- <5% uninstall rate primera semana
- 100+ usuarios activos mes 1 post-launch

### Fase 2 (Crecimiento)
- 500+ descargas mensuales sostenidas
- 3-5% conversión a Pro
- $100+ USD/mes ingreso recurrente
- Reviews mencionan "simple" y "para mayores" orgánicamente

---

## 11. PRINCIPIOS DE DISEÑO (North Star)

### Reglas Inquebrantables
1. **Simplicidad > Features**: Si confunde a una persona de 85 años, NO va
2. **1 acción principal por pantalla**: No competencia visual
3. **Feedback inmediato**: Cada toque muestra resultado claro
4. **Texto explícito > Iconos**: "ESCANEAR" > 📷
5. **Confirmaciones obvias**: Botones SÍ/NO grandes, sin "swipe para confirmar"
6. **Sin gestos ocultos**: Todo debe ser tappeable con botones visibles
7. **Contraste alto**: Negro sobre blanco, no grises sutiles
8. **Tamaños generosos**: Botones 60dp+, texto 18sp+

### Filosofía UX
> "Si mi mamá de 85 años no puede hacerlo sin ayuda después de 1 tutorial de 3 pasos, está mal diseñado."

---

## 12. COMPETENCIA - GAPS IDENTIFICADOS

### Lo que NADIE hace bien:
1. ✅ **Notas integradas** - todos tienen notas básicas o nada
2. ✅ **Vencimientos integrados** - nadie lo tiene
3. ✅ **Notas + Vencimientos integrados (KILLER FEATURE)** - literalmente NINGUNA app lo tiene. Adobe tiene scan, CamScanner tiene scan + notas básicas, pero NADIE combina scan + notas completas + vencimientos en UNA app
4. ✅ **Smart tagging automático** - solo Genius Scan básico
5. ✅ **Búsqueda por voz** - ninguno
6. ✅ **UI para mayores** - ninguno diseñado para ello
7. ✅ **Licencia extendida / Pago único** - casi nadie ofrece opción de pago único (5 años sin suscripción)
8. ✅ **Sin ads en free** - CamScanner lleno, otros con watermark
9. ✅ **Privacidad local-first** - apps chinas banned por seguridad

### Nuestra ventaja competitiva
**"No competimos en features, competimos en SIMPLICIDAD + INTEGRACIÓN para un nicho específico (personas mayores)"**

---

## 13. FILOSOFÍA DEL PROYECTO

### Aprendizajes de QuehaCeMos aplicados aquí:
- ✅ Arquitectura limpia desde día 1
- ✅ Testing antes de código
- ✅ Validación real con usuarios
- ✅ Evitar scope creep religiosamente
- ✅ Planificación > velocidad

### Por qué este proyecto SÍ puede monetizar (vs app compresión):
1. **Problema claro** validado por reviews negativas competencia
2. **Target definido** (mayores) dispuesto a pagar
3. **Diferenciación concreta** (3 en 1, UI simple)
4. **Competencia cara** ($10/mes Adobe) o mala (ads invasivos)
5. **Licencia extendida 5 años** match perfecto con target (pago único sin suscripciones)

---

## 14. PREGUNTAS CRÍTICAS A RESPONDER DURANTE DESARROLLO

### Antes de cada fase:
- [ ] ¿Esta feature está en el PVD? Si no, ¿por qué la estamos considerando?
- [ ] ¿Mi mamá la entendería sin explicación? Si no, ¿cómo simplificar?
- [ ] ¿Esto ayuda a diferenciar de competencia? Si no, ¿es realmente necesario?
- [ ] ¿Podemos testear esto fácilmente? Si no, ¿cómo validar que funciona?

### Antes de publicar:
- [ ] ¿Mi mamá la usa regularmente sin ayuda? 
- [ ] ¿Tenemos 20+ reviews de beta testers reales?
- [ ] ¿El OCR funciona >85% en documentos comunes argentinos?
- [ ] ¿La app corre bien en Pixel 3a (device de referencia)?

---

## 15. CONTACTO Y RECURSOS

**Desarrollador:** Post-QuehaCeMos developer  
**Validation Tester:** Mamá de 85 años (QA principal)  
**Timeline:** Sin prisa, arquitectura > velocidad  
**Filosofía:** "Aprender a trabajar bien"  

**Documentos relacionados:**
- `scandoc.md` - Brainstorming inicial
- `scandoc2.md` - Research competencia
- `user_stories.md` - Historias de usuario (próximo)
- `technical_spec.md` - Specs técnicas detalladas (próximo)

---

**Última actualización:** 17 Enero 2026  
**Próximo paso:** Definir historias de usuario para Fase 1 (MVP)
