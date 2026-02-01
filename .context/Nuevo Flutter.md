
# EscanDoc - Cambios Flutter 3.38.0 + FTS5 Fix

**Fecha:** 28 Enero 2026  
**Problema resuelto:** Error "no such module: fts5" + Modernización app

---

## 1. INSTALACIÓN FVM (Flutter Version Manager)

```bash
# Una sola vez (global)
dart pub global activate fvm

# Descargar Flutter 3.38.0 para EscanDoc
fvm install 3.38.0

# Activar en proyecto
cd escandoc
fvm use 3.38.0
```

**Resultado:** EscanDoc usa Flutter 3.38.0, otras apps siguen con Flutter 3.8.1 global

---

## 2. FIX FTS5 - SQLite con FTS5 Habilitado

### pubspec.yaml
```yaml
dependencies:
  sqflite_sqlcipher: ^3.4.0  # Reemplaza a sqflite estándar
```

### lib/core/database/database_helper.dart
```dart
// ANTES
import 'package:sqflite/sqflite.dart';

// DESPUÉS
import 'package:sqflite_sqlcipher/sqflite.dart';
```

**Todo el resto del código sin cambios** (drop-in replacement)

---

## 3. ANDROID NDK UPGRADE

### android/app/build.gradle.kts

```kotlin
android {
    ndkVersion = "28.2.13676358"  // antes: 27.0.12077973
}
```

**Motivo:** Compatibilidad con speech_to_text (backward compatible)

---

## 4. LIMPIEZA DEPENDENCIAS

### android/app/build.gradle.kts

**Eliminada dependencia redundante:**

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ❌ ELIMINADA (sqflite_sqlcipher ya trae SQLite)
    // implementation("androidx.sqlite:sqlite:2.4.0")
    
    implementation("com.google.mlkit:text-recognition:16.0.0")
}
```

---

## 5. ACTUALIZACIÓN DEPENDENCIAS

```bash
fvm flutter pub upgrade
```

**Actualizaciones principales:**
- sqflite_android: 2.4.2+2
- sqlite3: 3.1.4 (mejor FTS5)
- shared_preferences: 2.5.4
- path_provider: 2.2.22

---

## 6. COMANDOS DIARIOS

### En EscanDoc (siempre con fvm)
```bash
fvm flutter run
fvm flutter build apk
fvm flutter test
fvm flutter analyze
```

### Otras apps (sin fvm)
```bash
cd ../quehacemos
flutter run  # Sin fvm, usa Flutter 3.8.1 global
```

---

## RESULTADO FINAL

✅ Error "no such module: fts5" resuelto  
✅ Base de datos SQLite con FTS5 funcional  
✅ Flutter 3.38.0 (moderno, Dart 3.9+)  
✅ NDK 28.x (compatible con todos los plugins)  
✅ Dependencias actualizadas  
✅ Otras apps no afectadas (FVM aislado)

---

## TESTING

### Emulador x86_64 (API 30)
✅ BD se crea correctamente  
✅ Sin errores FTS5  
⏳ Pendiente: Probar búsqueda full-text

### Device real (Moto G52)
⏳ Pendiente: Testing completo  
💡 Recomendado: Usar como device principal (mejor performance)

---

## ARCHIVOS MODIFICADOS

```
pubspec.yaml                        → sqflite_sqlcipher
android/app/build.gradle.kts        → NDK 28, limpieza deps
lib/core/database/database_helper.dart → import sqflite_sqlcipher
.fvm/                               → Flutter 3.38.0 (nuevo)
```

---

## PRÓXIMOS PASOS

1. ✅ Testing en Moto G52 (device real)
2. ⏳ Validar búsqueda FTS5 funciona
3. ⏳ Fix bugs P0 (guardar documentos)
4. ⏳ Testing con usuario real (mamá QA)


```


**Fecha:** 29 Enero 2026 

Flutter 3.38.8 • channel stable • https://github.com/flutter/flutter.git
Framework • revision bd7a4a6b55 (3 days ago) • 2026-01-26 15:21:03 -0800
Engine • hash 9c1e4933426257206c317269a99c77122da463cb (revision db373eb85a) (2 days ago) • 2026-01-26 18:17:44.000Z
Tools • Dart 3.10.7 • DevTools 2.51.1

compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    isCoreLibraryDesugaringEnabled = true
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
}