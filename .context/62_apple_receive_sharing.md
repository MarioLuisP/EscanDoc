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


❯ ¿en serio receive sharing no se puede scriptear en el codemagic.yaml?                                                                                                                                                                                                                                   
● Se puede, pero hay dos partes con niveles de dificultad muy diferentes:

Lo que SÍ es fácil de scriptear en yaml:                                                                                                                                                                                           - Entitlements con App Groups (PlistBuddy)
- Provisioning profile para el target de la extensión (fetch-signing-files para com.passalia.escandoc.ShareExtension)

Lo que es difícil — agregar el target al project.pbxproj:                                                                                                                                                                          Existe la gema xcodeproj (Ruby, viene con CocoaPods) que permite manipular el pbxproj programáticamente. Se puede hacer con un script Ruby en el yaml. Pero es complejo de escribir bien.                                                                                                                                                                                                                                                                           
El enfoque más pragmático:
Hacer la modificación del pbxproj una sola vez con un script Ruby localmente o aceptando el riesgo de editarlo a mano, commitearlo al repo, y que el yaml solo maneje los entitlements y profiles de la extensión. Así el yaml   
queda simple.

