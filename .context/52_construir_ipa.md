# Guía: Construir IPA para App Store / TestFlight

## Regla de workflow
- **Editar directo en repo:** permisos, nombres, texto estático
- **Via scripts en yaml:** config Xcode (Bundle ID en pbxproj), entitlements, signing
- **Via env vars Codemagic:** secretos (certificados, API keys)

---

## Estado: lo ya hecho en el repo

- [x] `Info.plist` — NSCameraUsageDescription
- [x] `Info.plist` — NSPhotoLibraryAddUsageDescription
- [x] `Info.plist` — NSPhotoLibraryUsageDescription *(importar desde galería)*
- [x] `Info.plist` — NSMicrophoneUsageDescription *(speech_to_text)*
- [x] `Info.plist` — NSSpeechRecognitionUsageDescription *(speech_to_text)*
- [x] `Info.plist` — ITSAppUsesNonExemptEncryption = false *(export compliance)*
- [x] `pubspec.yaml` — flutter_launcher_icons con `remove_alpha_ios: true`
- [x] `ios/Podfile` — creado con iOS 15.5 mínimo + macros permission_handler
- [x] `ios/Runner/AppDelegate.swift` — UNUserNotificationCenter delegate para flutter_local_notifications

---

## Dependencias: compatibilidad iOS verificada

### ✅ Sin problemas (build + runtime)
| Paquete | Notas |
|---|---|
| `easy_localization` | OK. iOS necesita `CFBundleLocalizations` en Info.plist solo si Apple rechaza el build por idiomas — agregar si pasa |
| `sqflite` | Usa SQLite del sistema iOS, que sí tiene FTS5 |
| `sqlite3_flutter_libs` | En iOS no interfiere, se ignora silenciosamente |
| `file_picker` | OK — permisos ya en Info.plist |
| `flutter_doc_scanner` | Usa VisionKit nativo iOS 13+ |
| `flutter_image_compress` | OK en device. ⚠️ Crashes si se comprime en loop rápido — agregar delay entre llamadas |
| `image` | Dart puro, sin problemas |
| `pdf`, `printing`, `pdfrx` | OK — usan PDFKit nativo iOS |
| `pdf_to_image_converter` | OK — usa PDFKit |
| `gal` | OK — permisos ya en Info.plist |
| `speech_to_text` | OK — permisos ya en Info.plist + macros en Podfile |
| `flutter_local_notifications` | OK — AppDelegate ya tiene el delegate configurado |
| `permission_handler` | OK — macros activadas en Podfile |
| `provider`, `path`, `uuid`, `shared_preferences`, `path_provider` | Dart puro / multiplataforma, sin problemas |
| `google_fonts`, `flutter_markdown_plus` | Sin problemas |

### ⚠️ Verificar en device (no bloquean el build)
| Paquete | Qué verificar |
|---|---|
| `tflite_flutter` | No funciona en simulador iOS — probar siempre en device físico. Si el release build lanza "Failed to lookup symbol": agregar `config.build_settings['STRIP_STYLE'] = 'non-global'` en el Podfile post_install |
| `google_mlkit_text_recognition` | Descarga modelos de Google en el **primer uso** (necesita internet). Normal, no es un error |

### ❌ No implementado para iOS (evaluar post-MVP)
| Paquete | Qué falta |
|---|---|
| `receive_sharing_intent` | "Compartir desde otra app → EscanDoc" requiere un Share Extension (target separado en Xcode + App Group). Complejo. La app funciona sin eso — los documentos se pueden importar con `file_picker` |

---

## Variables a configurar en el dashboard de Codemagic

Crear grupo `app_store_credentials` con estas 4 variables:

| Variable | Dónde conseguirla |
|---|---|
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | App Store Connect → Usuarios → Claves de API |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Usuarios → Claves de API |
| `APP_STORE_CONNECT_PRIVATE_KEY` | El .p8 descargado al crear la clave |
| `CERTIFICATE_PRIVATE_KEY` | Exportar desde Keychain Access → cert de distribución iOS |

> El BUNDLE_ID `com.passalia.escandoc` va directo en el yaml (no como env var).

---

## El codemagic.yaml

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight
    max_build_duration: 120
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: codemagic-api
    environment:
      groups:
        - app_store_credentials
      vars:
        BUNDLE_ID: "com.passalia.escandoc"
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Set Bundle ID
        script: |
          sed -i "" "s/com.example.escandoc/$BUNDLE_ID/g" ios/Runner.xcodeproj/project.pbxproj
      - name: Get Flutter packages
        script: flutter pub get
      - name: Set up keychain
        script: keychain initialize
      - name: Fetch signing files
        script: |
          app-store-connect fetch-signing-files "$BUNDLE_ID" \
            --type IOS_APP_STORE \
            --create
      - name: Add certificates to keychain
        script: keychain add-certificates
      - name: Set up code signing
        script: xcode-project use-profiles
      - name: Build IPA
        script: flutter build ipa --release
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

---

## Pasos para el primer build

1. Crear la app en App Store Connect con Bundle ID `com.passalia.escandoc`
2. Configurar las 4 variables en Codemagic dashboard (grupo `app_store_credentials`)
3. Conectar el repo en Codemagic
4. Copiar el yaml de arriba al archivo `codemagic.yaml` en la raíz del repo
5. Triggerear el workflow `ios-testflight`

---

## Notas y posibles problemas

### flutter_doc_scanner en iOS
Usa VisionKit nativo. Verificar que el pod se instala correctamente en el build log.
Si falla: puede necesitar un `pod update` o cambio de versión en Podfile.

### receive_sharing_intent en iOS
Para que funcione "Compartir desde otra app → EscanDoc" en iOS se necesita un Share Extension
(target separado en Xcode + App Group). Es trabajo complejo que requiere iteración.
Por ahora la app puede funcionar sin eso — evaluar en TestFlight.

### tflite_flutter en iOS
El modelo `.tflite` está en `assets/models/`. Verificar en build log que se incluye en el bundle.
Si TFLite falla en iOS: puede necesitar `EXCLUDED_ARCHS = arm64` en el simulador (solo afecta simulator builds, no device).

### google_mlkit_text_recognition en iOS
Descarga modelos de Google en el primer uso (requiere internet la primera vez).
Agregar al Info.plist si hay problemas de red en build futuro:
`NSAppTransportSecurity → NSAllowsArbitraryLoads` (solo si es necesario, evitar si se puede).

### Iconos
`flutter_launcher_icons` se corre localmente: `fvm flutter pub run flutter_launcher_icons`
Los iconos ya deben estar generados en el repo antes del build de Codemagic.
