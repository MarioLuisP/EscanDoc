# 📄 EscanDoc

> **Escanea. Organiza. Recuerda.**  
> App de escaneo de documentos diseñada para personas mayores.

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Características

| Feature | Descripción |
|---------|-------------|
| 📷 **Escaneo Profesional** | Detección de bordes con ML Kit / VisionKit |
| 🔍 **OCR Offline** | Extrae texto sin conexión a internet |
| 🏷️ **Auto-clasificación** | Detecta facturas, recibos, contratos automáticamente |
| 📝 **Notas Integradas** | Agrega notas a cada documento |
| ⏰ **Vencimientos** | Recordatorios de fechas de pago |
| 🎤 **Búsqueda por Voz** | Encuentra documentos hablando |
| 👴 **UI Elderly-Friendly** | Botones grandes, texto legible, sin gestos complicados |

---

## 🎯 ¿Por qué EscanDoc?

| Problema | Solución |
|----------|----------|
| Adobe Scan cuesta $10/mes | **$3/mes o pago único** |
| CamScanner tiene ads invasivos | **Sin publicidad** |
| Apps separadas para docs, notas, recordatorios | **Todo en una app** |
| UI confusa para personas mayores | **Diseñada para 60-85 años** |

---

## 🛠️ Stack Técnico

```
Flutter 3.27+ / Dart 3.6+
├── Scanner:    flutter_doc_scanner (ML Kit / VisionKit)
├── OCR:        google_mlkit_text_recognition
├── Database:   SQLite + FTS5 (búsqueda full-text)
├── State:      Provider
└── Testing:    flutter_test + mocktail
```

---

## 📁 Estructura

```
lib/
├── core/                    # Compartido
│   ├── database/            # SQLite helper
│   ├── services/            # OCR, clasificador, PDF
│   └── localization/        # ES / EN
│
└── features/                # Por funcionalidad
    ├── documents/           # CRUD documentos
    ├── scan/                # Escaneo + procesamiento
    ├── search/              # Búsqueda + voz
    ├── notes/               # Notas vinculadas
    └── onboarding/          # Tutorial inicial
```

---

## 🚀 Instalación

```bash
# Clonar
git clone https://github.com/tu-usuario/escandoc.git
cd escandoc

# Dependencias
flutter pub get

# Ejecutar
flutter run
```

**Requisitos:**
- Flutter 3.27+
- Android SDK 21+ / iOS 13+
- Android Studio con emulador Pixel 3a API 30

---

## 📋 Roadmap

- [x] Definición de arquitectura
- [x] Historias de usuario
- [x] Database schema
- [ ] **Fase 1:** MVP funcional
- [ ] **Fase 2:** Vencimientos + notificaciones
- [ ] **Fase 3:** Cloud backup (opcional)

---

## 🧪 Testing

```bash
# Unit tests
flutter test

# Con coverage
flutter test --coverage
```

---

## 📄 Documentación

| Documento | Contenido |
|-----------|-----------|
| `.context/ADDS.md` | Decisiones técnicas |
| `.context/FASE_1_PLAN.md` | Plan de desarrollo |
| `.context/user_stories_mvp.md` | Historias de usuario |
| `.context/database_schema.md` | Schema SQL |

---

## 👨‍💻 Desarrollo

**Metodología:** TDD + Domain-First

```
Domain → Tests → Data → UI
```

**Regla de oro:** Si una persona de 85 años no puede usarlo sin ayuda, está mal diseñado.

---

# Para compilar:
flutter build apk --release --split-per-abi


## 📝 Licencia

MIT © 2026

---

<p align="center">
  <i>Hecho con ❤️ pensando en nuestros mayores</i>
</p>