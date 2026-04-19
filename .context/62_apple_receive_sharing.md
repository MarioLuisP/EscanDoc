# receive_sharing_intent — iOS (postergado)

## Decisión

La share extension de iOS fue postergada para después del primer TestFlight.
En Android funciona sin cambios. En iOS requiere trabajo adicional sin Xcode.

## Qué hay que hacer cuando se retome

### 1. Apple Developer Portal
- Registrar App Group: `group.com.passalia.escandoc` (Identifiers → App Groups → +)
- Asociarlo al Bundle ID `com.passalia.escandoc`
- Registrar Bundle ID de la extension: `com.passalia.escandoc.ShareExtension`

### 2. En el repo
- `ios/Runner/Runner.entitlements` → agregar `com.apple.security.application-groups`
- Crear carpeta `ios/ShareExtension/` con:
  - `Info.plist` de la extension
  - `ShareViewController.swift` (código de la extension)
- `ios/Runner.xcodeproj/project.pbxproj` → agregar el target ShareExtension (el paso más frágil)

### 3. codemagic.yaml
- Agregar script que linkee el App Group en el entitlement vía PlistBuddy

## Por qué se postergó

Sin Xcode, agregar una Share Extension requiere editar `project.pbxproj` manualmente.
Es un archivo enorme y frágil — riesgo alto para el primer build del pipeline.
