# EscanDoc

App Flutter de escaneo de documentos con OCR, notas y vencimientos integrados. Target: personas mayores (60-85 años).

## Stack

- **Flutter** 3.27+ / Dart 3.6+
- **State:** Provider
- **DB:** SQLite + FTS5
- **Scanner:** flutter_doc_scanner (UI nativa)
- **OCR:** google_mlkit_text_recognition + barcode_scanning
- **Testing:** flutter_test + mocktail

## Arquitectura

Clean Architecture + Feature-First:

```
lib/
├── core/           # Compartido (DB, services, localization)
└── features/       # Por funcionalidad (documents, scan, search, notes)
    └── [feature]/
        ├── data/         # Models, repositories
        ├── domain/       # UseCases (lógica de negocio)
        └── presentation/ # Pages, widgets, providers
```

## Reglas Inquebrantables

1. **Domain → Tests → Data → UI** (siempre este orden)
2. **TDD:** Test primero, código después
3. **Sin texto hardcodeado:** Usar claves de localización
4. **Domain no conoce Flutter:** Solo lógica pura
5. **Una feature completa antes de la siguiente**

## Flujo de Escaneo

```
Botón ESCANEAR → Scanner nativo → OCR post-scan → Clasificar → Generar nombre → Guardar
```

## Documentación
IMPORTANTE: SOLO LEER CUANDO SE PIDE EXPRESAMENTE
Todo en `.context/`: 

- `ADDS.md` - Decisiones técnicas y ajustes
- `FASE_1_PLAN.md` - Plan de desarrollo detallado
- `user_stories_mvp.md` - Historias de usuario
- `database_schema.md` - Schema SQL
- `architecture.md` - Arquitectura detallada

## Comando Inicial

Antes de codificar cualquier feature, leer:
1. `.context/ADDS.md` (decisiones actualizadas)