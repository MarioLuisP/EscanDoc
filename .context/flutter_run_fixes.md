# Correcciones Flutter Run Inicial

## Cambios en pubspec.yaml

### Dependencias agregadas
```yaml
easy_localization: ^3.0.7             # Localization simplificada
sqflite_common_ffi: ^2.3.4            # SQLite para tests en desktop (dev)
```

### Versiones ajustadas por compatibilidad
```yaml
shared_preferences: ^2.3.2            # antes: ^2.5.4 (downgrade)
google_mlkit_text_recognition: ^0.15.0 # antes: ^0.14.0 (upgrade)
image: ^4.5.0                         # antes: ^4.7.2 (downgrade)
```

## Cambios en android/app/build.gradle.kts

## 1. Android NDK Version
**Error:** Conflicto de versiones NDK entre proyecto (26.x) y plugins (27.x)
```kotlin
ndkVersion = "27.0.12077973"  // antes: flutter.ndkVersion
```

## 2. Core Library Desugaring
**Error:** `flutter_local_notifications` requiere desugaring para APIs modernas de Java
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    isCoreLibraryDesugaringEnabled = true  // añadido
}
```

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")  // añadido
}
```

## 3. MinSDK Version
**Error:** `flutter_doc_scanner` requiere minSDK 23 (Android 6.0+)
```kotlin
minSdk = 23  // antes: flutter.minSdkVersion (21)
```

## Resultado
✅ App compila y ejecuta correctamente en emulador





# Informe de Cambios - Proyecto Flutter

## Cambios Realizados

### 1. Eliminación de `ndk { abiFilters }`
**Archivo:** `android/app/build.gradle.kts`

**Qué se hizo:**
```kotlin
// Se comentó/eliminó:
// ndk {
//     abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
// }
```

**Motivo:**
- Conflicto con el comando `flutter build apk --split-per-abi`
- Flutter maneja las arquitecturas automáticamente
- No es necesario para habilitar FTS5 en SQLite

---

### 2. Agregada dependencia de ML Kit Text Recognition
**Archivo:** `android/app/build.gradle.kts`

**Qué se agregó:**
```kotlin
dependencies {
    implementation("com.google.mlkit:text-recognition:16.0.0")
}
```

**Motivo:**
- Resolver error de clases faltantes en build release
- Soporte para reconocimiento de texto latino

---

### 3. Configuración de ProGuard para ML Kit
**Archivo:** `android/app/proguard-rules.pro`

**Se creó:**
```proguard
# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }

# Suppress warnings for optional ML Kit scripts
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
```

**Motivo:**
- Evitar que R8 elimine clases de ML Kit en builds release
- Resolver error de minificación con ProGuard

---

### 4. Corrección de configuración release
**Archivo:** `android/app/build.gradle.kts`

**Configuración final:**
```kotlin
buildTypes {
    getByName("release") {
        isMinifyEnabled = true
        signingConfig = signingConfigs.getByName("debug")
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

**Motivo:**
- Vincular correctamente las reglas ProGuard
- Unificar configuración release

---

## Limitación Conocida

**FTS5 en SQLite:**
- `sqflite` usa SQLite del sistema Android
- FTS5 disponible en dispositivos ARM reales
- Emuladores x86_64 pueden no tener FTS5
- Se recomienda pruebas en dispositivo físico

---

## Estado Final
✅ Build release funcional  
✅ APK por arquitectura sin conflictos  
✅ ML Kit estable en release
