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
6. **Refactorizar sin miedo:** Si el código verde puede ser más limpio, refactorizar antes de avanzar.
7. **Una feature completa antes de la siguiente:** No empezar nueva feature con tests en rojo o lógica incompleta.


## Flujo TDD

**Ciclo obligatorio:** RED → GREEN → REFACTOR

1. Escribir test que falla (RED) — verificar que falla por la razón correcta
2. Escribir el mínimo código para pasarlo (GREEN)
3. Refactorizar si corresponde
   **IMPORTANTE:** Este proyecto usa FVM (Flutter Version Manager).
4. **Yo corro los tests** con `fvm flutter test` y te paso el output — vos no podés ejecutarlos

**Qué se testea con TDD:**
- Domain: UseCases, entidades, lógica de negocio — **siempre, sin excepción**
- Data: repositorios y modelos que no dependan de plugins nativos
- Presentation: providers con lógica de estado

**Qué NO se testea:**
- Cualquier clase que dependa directamente de flutter_doc_scanner o google_mlkit
- Estas capas se verifican manualmente en dispositivo

**Mocks:** usar mocktail para dependencias externas. No mockear clases de dominio.

**Antes de marcar cualquier tarea como completa:** pedirme que corra los tests y confirmar GREEN.

## Flujo de Escaneo

```
Botón ESCANEAR → Scanner nativo → OCR post-scan → Clasificar → Generar nombre → Guardar
```
## Lecciones del proyecto

leer `lessons.md`  en la raiz del proyecto—  al inicio de cada sesión.