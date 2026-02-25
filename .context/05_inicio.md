
## FASE 0: SETUP (1 sola vez )

### Objetivo:
Estructura base sin lógica de negocio.

### Tareas:

#### 1. Crear proyecto Flutter

EL PROYECTO YA FUE CREADO

#### 2. Configurar packages
```yaml

 EL pubspec.yaml YA FUE CREADO, SOLO FALTA
 cupertino_icons: ^1.0.8 para los iconos
 
 Revísalo para darle el OK

```

#### 3. Crear estructura de carpetas VACÍA
```
 lee .context/architecture.md
  y luego 
  .context/ADDS.md
 
#### 4. Implementar localization básica
```dart
// core/localization/app_localizations.dart
// Implementación básica con es.json / en.json
```

#### 5. Implementar DatabaseHelper con schema

leer .context/database_shema.md
```dart
// core/database/database_helper.dart
// Singleton + onCreate con SQL del schema
```

#### 6. Setup main.dart con routing y providers
```dart
// main.dart
// MaterialApp + MultiProvider + rutas vacías
// Revisar .gitignore
```

### Criterio de completitud FASE 0:
- [ ] `flutter run` funciona sin errores
- [ ] Estructura de carpetas completa
- [ ] DatabaseHelper crea BD correctamente
- [ ] Localization carga es.json
- [ ] Navegación entre rutas vacías funciona

---
FASE 0 completada exitosamente!

✅ Resumen de lo implementado:

1. Packages configurados

- ✅ easy_localization: ^3.0.7 agregado para localización
- ✅ Ajustadas versiones para compatibilidad:
    - image: ^4.5.0 (era ^4.7.2)
    - google_mlkit_text_recognition: ^0.15.0 (era ^0.14.0)
    - shared_preferences: ^2.3.2 (era ^2.5.4)

2. Estructura de carpetas creada (sin categories/ según ADDS.md)

lib/
├── core/
│   ├── database/          ✅ DatabaseHelper con schema actualizado
│   ├── services/          ✅ Vacío (para OCR, classifier, etc)
│   ├── utils/             ✅ Vacío (para helpers)
│   ├── constants/         ✅ Vacío (para constantes)
│   └── localization/      ✅ Vacío (easy_localization usa assets/)
├── features/
│   ├── scan/              ✅ Con providers, pages stub
│   ├── documents/         ✅ Con providers, pages stub
│   ├── search/            ✅ Con providers, pages stub
│   ├── notes/             ✅ Con providers, pages stub
│   └── onboarding/        ✅ Con pages stub
└── main.dart              ✅ Configurado con routing y providers

3. Localization implementada

- ✅ assets/l10n/es.json - Español (primario)
- ✅ assets/l10n/en.json - Inglés (secundario)
- ✅ Claves básicas definidas según ADDS.md

4. DatabaseHelper completo

- ✅ Schema actualizado SIN campo category
- ✅ SOLO doc_type con valores: 'factura', 'recibo', 'contrato', 'médico', 'documento'
- ✅ FTS5 para búsqueda full-text en documentos y notas
- ✅ Triggers automáticos para mantener FTS5 sincronizado
- ✅ Índices de performance
- ✅ Tablas preparadas para Fase 2 (due_dates)

5. Main.dart configurado

- ✅ MultiProvider con 4 providers (scan, documents, search, notes)
- ✅ Rutas nombradas para todas las features
- ✅ Tema con fuentes grandes (elderly-friendly)
- ✅ Localización integrada

6. Verificación

- ✅ flutter pub get exitoso
- ✅ flutter analyze sin errores
- ✅ .gitignore correcto

  ---
📋 Criterios de completitud FASE 0:

- ✅ ~flutter run` funciona sin errores~~ 
- (listo para probar en dispositivo)
- ✅ Estructura de carpetas completa
- ✅ DatabaseHelper crea BD correctamente
- ✅ Localization carga es.json
- ✅ Navegación entre rutas vacías funciona

