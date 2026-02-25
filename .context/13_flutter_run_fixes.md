# Flutter Build Fixes - EscanDoc

**Última actualización:** 25 Enero 2026
**Proyecto:** EscanDoc MVP
**Estado:** ✅ Verificado en debug y release builds
**Flutter Version:** 3.27+
**Gradle Version:** 8.x (Kotlin DSL)
**NDK Version:** 27.0.12077973

---

## Tabla de Contenidos

1. [Comandos de Verificación](#comandos-de-verificación)
2. [Fixes de Dependencias (pubspec.yaml)](#1-fixes-de-dependencias-pubspecyaml)
3. [Fixes de Build Debug](#2-fixes-de-build-debug-androidappbuildgradlekts)
4. [Fixes de Build Release](#3-fixes-de-build-release)
5. [Limitaciones Conocidas](#limitaciones-conocidas)
6. [Estado Final](#estado-final)

---

## Comandos de Verificación

```bash
# Limpiar proyecto
flutter clean
flutter pub get

# Verificar build debug
flutter run -d windows  # o emulador Android

# Verificar build release
flutter build apk --split-per-abi --release
flutter build appbundle --release

# Analizar código
flutter analyze
flutter test
```

---

## 1. Fixes de Dependencias (pubspec.yaml)

### 1.1 Dependencias agregadas

```yaml
easy_localization: ^3.0.7             # Localization simplificada
sqflite_common_ffi: ^2.3.4            # SQLite para tests en desktop (dev)
```

**Motivo:**
- `easy_localization`: Sistema i18n del proyecto (ES/EN)
- `sqflite_common_ffi`: Ejecutar tests con SQLite en Windows/Desktop

---

### 1.2 Versiones ajustadas por compatibilidad

```yaml
shared_preferences: ^2.3.2            # antes: ^2.5.4 (downgrade)
google_mlkit_text_recognition: ^0.15.0 # antes: ^0.14.0 (upgrade)
image: ^4.5.0                         # antes: ^4.7.2 (downgrade)
```

**Motivos:**
- `shared_preferences: ^2.3.2` - Downgrade por conflicto con otras dependencias
- `google_mlkit_text_recognition: ^0.15.0` - Upgrade para OCR mejorado
- `image: ^4.5.0` - Downgrade por compatibilidad con Flutter 3.27

---

## 2. Fixes de Build Debug (android/app/build.gradle.kts)

### 2.1 Android NDK Version

**Error:** Conflicto de versiones NDK entre proyecto (26.x) y plugins (27.x)

**Archivo:** `android/app/build.gradle.kts`

```kotlin
android {
    ndkVersion = "27.0.12077973"  // antes: flutter.ndkVersion
}
```

**Motivo:**
- Plugins como `flutter_doc_scanner` requieren NDK 27.x
- Evita conflictos de arquitectura en builds nativos

---

### 2.2 MinSDK Version

**Error:** `flutter_doc_scanner` requiere minSDK 23 (Android 6.0+)

**Archivo:** `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        minSdk = 23  // antes: flutter.minSdkVersion (21)
    }
}
```

**Motivo:**
- El scanner nativo requiere APIs de Android 6.0+
- Elimina warning de compatibilidad

---

### 2.3 Core Library Desugaring

**Error:** `flutter_local_notifications` requiere desugaring para APIs modernas de Java

**Archivo:** `android/app/build.gradle.kts`

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // añadido
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")  // añadido
}
```

**Motivo:**
- Permite usar APIs de Java 8+ en dispositivos Android antiguos
- Requerido por notificaciones locales (futuro feature)

---

### 2.4 Resultado Build Debug

✅ App compila y ejecuta correctamente en emulador
✅ Todas las dependencias resueltas
✅ No hay warnings de compatibilidad

---

## 3. Fixes de Build Release

### 3.1 Eliminación de `ndk { abiFilters }`

**Error:** Conflicto con `flutter build apk --split-per-abi`

**Archivo:** `android/app/build.gradle.kts`

**Qué se eliminó:**
```kotlin
// Se comentó/eliminó esta sección:
// defaultConfig {
//     ndk {
//         abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
//     }
// }
```

**Motivos:**
- Conflicto con el comando `flutter build apk --split-per-abi`
- Flutter maneja las arquitecturas automáticamente al usar `--split-per-abi`
- No es necesario para habilitar FTS5 en SQLite
- Evita duplicación de configuración de ABIs

---

### 3.2 Dependencia explícita de ML Kit

**Error:** Clases de ML Kit faltantes en build release (NoClassDefFoundError)

**Archivo:** `android/app/build.gradle.kts`

**Qué se agregó:**
```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.mlkit:text-recognition:16.0.0")  // añadido
}
```

**Motivos:**
- Resolver error de clases faltantes en build release
- Incluir explícitamente soporte para reconocimiento de texto latino
- El plugin `google_mlkit_text_recognition` no siempre incluye las dependencias nativas correctamente

---

### 3.3 Configuración de ProGuard para ML Kit

**Error:** R8/ProGuard elimina clases de ML Kit en minificación

**Archivo:** `android/app/proguard-rules.pro` (CREAR si no existe)

**Contenido completo:**
```proguard
# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }

# Suppress warnings for optional ML Kit scripts (idiomas no usados)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
```

**Motivos:**
- Evitar que R8 elimine clases de ML Kit durante minificación
- Resolver errores de reflection en runtime
- Suprimir warnings de idiomas no soportados (solo usamos latino)

---

### 3.4 Vinculación de ProGuard en buildTypes

**Archivo:** `android/app/build.gradle.kts`

**Configuración final:**
```kotlin
android {
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("debug")  // cambiar a release en producción
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**Motivos:**
- Vincular correctamente las reglas ProGuard creadas en 3.3
- Habilitar minificación de código (reduce tamaño APK ~40%)
- Usar `proguard-android-optimize.txt` para optimizaciones adicionales

**IMPORTANTE:** Antes de publicar en Play Store, cambiar `signingConfig = signingConfigs.getByName("release")` con keystore real.

---

### 3.5 Resultado Build Release

✅ `flutter build apk --split-per-abi --release` funcional
✅ APK por arquitectura sin conflictos (armeabi-v7a, arm64-v8a, x86_64)
✅ ML Kit estable en release (OCR funciona correctamente)
✅ Minificación activa (tamaño reducido ~40%)

---

## Limitaciones Conocidas

### FTS5 en SQLite

**Contexto:**
- `sqflite` usa SQLite del sistema Android (no empaqueta versión propia)
- FTS5 (Full Text Search) está disponible en SQLite 3.9.0+ (2015)

**Estado por plataforma:**
- ✅ **Dispositivos ARM reales:** FTS5 disponible (Android 6.0+)
- ⚠️ **Emuladores x86_64:** Pueden no tener FTS5 (depende de imagen del sistema)
- ✅ **Windows (tests):** FTS5 disponible vía `sqflite_common_ffi`

**Recomendaciones:**
- Testear búsqueda FTS5 en dispositivo físico Android real
- Si emulador x86_64 falla en búsqueda, no es un bug del código
- La app maneja gracefully si FTS5 no está disponible (fallback a LIKE)

---

## Estado Final

### ✅ Checklist de Build

- [x] `flutter pub get` sin errores
- [x] `flutter analyze` sin issues
- [x] `flutter test` - 111/111 tests pasando
- [x] `flutter run -d emulator` funcional
- [x] `flutter build apk --split-per-abi --release` exitoso
- [x] `flutter build appbundle --release` exitoso
- [x] APKs instalables en dispositivo físico


### ✅ Archivos Modificados

```
pubspec.yaml                        → Dependencias ajustadas
android/app/build.gradle.kts        → NDK, minSDK, desugaring, ProGuard, ML Kit
android/app/proguard-rules.pro      → Reglas ML Kit (creado)
```

### 📦 Tamaño Final de APKs (split-per-abi)

- `app-armeabi-v7a-release.apk` → ~25 MB (Android 32-bit)
- `app-arm64-v8a-release.apk` → ~27 MB (Android 64-bit, más común)
- `app-x86_64-release.apk` → ~28 MB (emuladores)

---

## Notas para Futuras Sesiones

1. **Si aparecen errores de build:** Revisar este documento primero
2. **Nuevas dependencias nativas:** Verificar compatibilidad con minSDK 23 y NDK 27.x
3. **ProGuard adicional:** Agregar reglas en `proguard-rules.pro` si R8 elimina clases necesarias
4. **Signing para producción:** Configurar keystore real antes de publicar
5. **Testing en dispositivos:** Siempre verificar FTS5 en dispositivo físico ARM
