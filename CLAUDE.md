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
3. **Enfoque:** TDD clásico: Test RED → Code → Test GREEN
4. **Sin texto hardcodeado:** Usar claves de localización
5. **Domain no conoce Flutter:** Solo lógica pura
6. Refactorizar, sin duda. respetaremos clea**Una feature completa antes de la siguiente**

## Flujo de Escaneo

```
Botón ESCANEAR → Scanner nativo → OCR post-scan → Clasificar → Generar nombre → Guardar
```

## Documentación
IMPORTANTE: SOLO LEER CUANDO SE PIDE EXPRESAMENTE
Todo en `.context/`: 

## Testing

**IMPORTANTE:** Este proyecto usa FVM (Flutter Version Manager).

Para ejecutar tests, usar el script wrapper:
```bash
# Windows
.\test.bat

# Linux/Mac  
./test.sh
```

**NO usar** `flutter test` directamente.

El script ejecuta `fvm flutter test` con todos los argumentos pasados.