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
