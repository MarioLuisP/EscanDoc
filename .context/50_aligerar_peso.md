flutter build apk --release --analyze-size

Eso genera un reporte que muestra exactamente qué ocupa qué.

Pero casi seguro el culpable principal es uno de estos:

┌─────────────────────────────────┬────────────────────┬─────────────────────┐
│           Componente            │    Peso típico     │      Solución       │
├─────────────────────────────────┼────────────────────┼─────────────────────┤
│ Fat APK (arm64 + x86 + armeabi) │ +30MB innecesarios │ Build split por ABI │
├─────────────────────────────────┼────────────────────┼─────────────────────┤
│ Google ML Kit OCR model bundled │ 5-10MB             │ Descargar on-demand │
├─────────────────────────────────┼────────────────────┼─────────────────────┤
│ Modelo TFLite clasificador      │ 1-8MB              │ Cuantizar a int8    │
├─────────────────────────────────┼────────────────────┼─────────────────────┤
│ flutter_doc_scanner nativo      │ 3-5MB              │ —                   │
├─────────────────────────────────┼────────────────────┼─────────────────────┤
│ Flutter engine                  │ 5-7MB por ABI      │ —                   │
└─────────────────────────────────┴────────────────────┴─────────────────────┘

La ganancia más grande con menos trabajo: si estás distribuyendo un fat APK, cambiar a split APKs baja el tamaño que el usuario descarga a la mitad o menos. En Play Store esto es automático con App Bundle:

flutter build appbundle --release

Un .aab en Play Store se instala como ~15-20MB en el dispositivo real (solo la ABI del device).

Pasame el output del --analyze-size y te digo exactamente dónde atacar.

✻ Churned for 37s

❯                                                                                                                                                                                                                                  
35 packages have newer versions incompatible with dependency constraints.                                                                                                                                                        
Try `flutter pub outdated` for more information.                                                                                                                                                                                 
Cannot perform code size analysis when building for multiple ABIs. Specify one of android-arm, android-arm64, or android-x64 in the --target-platform flag.


● Bash(cd /c/Users/Mario/Documents/escandoc && fvm flutter build apk --release --analyze-size --target-platform android-arm64 2>&1 | tail -50)
⎿  /usr/bin/bash: line 1: fvm: command not found

● Como siempre con FVM, necesito que lo corras vos en tu terminal:

fvm flutter build apk --release --analyze-size --target-platform android-arm64

Al terminar te genera una línea con el path al reporte, algo como:
▒ Size analysis for android-arm64:
...
Open the analysis file at: build/flutter_size_01/snapshot.arm64-v8a.json

Pegame las últimas líneas del output (el resumen de tamaños por categoría) y lo analizamos.

❯                                                                                                                                                                                                                              
35 packages have newer versions incompatible with dependency constraints.                                                                                                                                                    
Try `flutter pub outdated` for more information.                                                                                                                                                                                   Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 6132 bytes (99.6% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.           
Running Gradle task 'assembleRelease'...                          178,8s                                                                                                                                                           √ Built build\app\outputs\flutter-apk\app-release.apk (94.1MB)                                                                                                                                                                   
▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                                                                                                                                             
app-release.apk (total compressed)                                         94 MB                                                                                                                                                 
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                                                                                                                                                 
META-INF/                                                                                                                                                                                                                      
androidx                                                                3 KB                                                                                                                                                 
assets/                                                                                                                                                                                                                        
dexopt                                                                  1 KB                                                                                                                                                 
flutter_assets                                                          9 MB                                                                                                                                                 
mlkit-google-ocr-models                                                 1 MB                                                                                                                                                 
classes.dex                                                               1 MB                                                                                                                                                 
classes2.dex                                                             96 KB                                                                                                                                                 
lib/                                                                                                                                                                                                                           
arm64-v8a                                                              41 MB                                                                                                                                                 
Dart AOT symbols accounted decompressed size                            7 MB                                                                                                                                                 
package:flutter                                                       3 MB                                                                                                                                                 
dart:core                                                           274 KB                                                                                                                                                 
package:escandoc                                                    252 KB                                                                                                                                                 
dart:ui                                                             229 KB                                                                                                                                                 
dart:typed_data                                                     194 KB                                                                                                                                                 
package:flutter_localizations                                       171 KB                                                                                                                                                 
package:pdfrx                                                       156 KB                                                                                                                                                 
dart:async                                                          126 KB                                                                                                                                                 
dart:io                                                             125 KB                                                                                                                                                 
package:markdown                                                    106 KB                                                                                                                                                 
package:material_color_utilities                                     86 KB                                                                                                                                                 
dart:collection                                                      82 KB                                                                                                                                                 
package:pdfrx_engine                                                 69 KB                                                                                                                                                 
dart:convert                                                         57 KB                                                                                                                                                 
package:tflite_flutter                                               54 KB                                                                                                                                                 
package:flutter_markdown_plus                                        47 KB                                                                                                                                                 
package:sqflite_common                                               41 KB                                                                                                                                                 
package:vector_math/                                                                                                                                                                                                       
vector_math_64.dart                                                39 KB                                                                                                                                                 
package:intl                                                         38 KB                                                                                                                                                 
package:characters                                                   37 KB                                                                                                                                                 
armeabi-v7a                                                            15 MB                                                                                                                                                 
x86_64                                                                 26 MB                                                                                                                                                 
kotlin/                                                                                                                                                                                                                        
collections                                                             1 KB                                                                                                                                                 
kotlin.kotlin_builtins                                                  5 KB                                                                                                                                                 
ranges                                                                  1 KB                                                                                                                                                 
reflect                                                                 1 KB                                                                                                                                                 
org/                                                                                                                                                                                                                           
apache                                                                 56 KB                                                                                                                                                 
AndroidManifest.xml                                                       3 KB                                                                                                                                                 
res/                                                                                                                                                                                                                           
1I.9.png                                                                2 KB                                                                                                                                                 
1J.9.png                                                                2 KB                                                                                                                                                 
5J.9.png                                                                1 KB                                                                                                                                                 
9w.png                                                                  3 KB                                                                                                                                                 
BM.png                                                                 41 KB                                                                                                                                                 
CH.png                                                                 65 KB                                                                                                                                                 
FS.png                                                                  7 KB                                                                                                                                                 
G2.9.png                                                                1 KB                                                                                                                                                 
I3.9.png                                                                1 KB                                                                                                                                                 
IX.9.png                                                                2 KB                                                                                                                                                 
Li.9.png                                                                2 KB                                                                                                                                                 
MF.9.png                                                                3 KB                                                                                                                                                 
NA.9.png                                                                2 KB                                                                                                                                                 
Oi.xml                                                                  1 KB                                                                                                                                                 
RJ.png                                                                 12 KB                                                                                                                                                 
ZL.9.png                                                                1 KB                                                                                                                                                 
_p.png                                                                  1 KB                                                                                                                                                 
bB.png                                                                  8 KB                                                                                                                                                 
color-v23                                                               2 KB                                                                                                                                                 
dO.xml                                                                  1 KB                                                                                                                                                 
fY.xml                                                                  1 KB                                                                                                                                                 
h7.9.png                                                                1 KB                                                                                                                                                 
io.9.png                                                                1 KB                                                                                                                                                 
nf.png                                                                  1 KB                                                                                                                                                 
o-.png                                                                 19 KB                                                                                                                                                 
qD.9.png                                                                3 KB                                                                                                                                                 
rj.9.png                                                                1 KB                                                                                                                                                 
t1.xml                                                                  1 KB                                                                                                                                                 
tP.png                                                                 23 KB                                                                                                                                                 
us.9.png                                                                2 KB                                                                                                                                                 
w2.9.png                                                                1 KB                                                                                                                                                 
yi.png                                                                 15 KB                                                                                                                                                 
yn.png                                                                  5 KB                                                                                                                                                 
zV.9.png                                                                2 KB                                                                                                                                                 
zw.9.png                                                                1 KB                                                                                                                                                 
resources.arsc                                                          327 KB                                                                                                                                                 
▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                                                                                                                                                 
A summary of your APK analysis can be found at: C:\Users\Mario\.flutter-devtools\apk-code-size-analysis_01.json

To analyze your app size in Dart DevTools, run the following command:                                                                                                                                                            
dart devtools --appSizeBase=C:\Users\Mario\.flutter-devtools\apk-code-size-analysis_01.json

● Diagnóstico claro. El problema principal salta a la vista:                                                                                                                                                                          
lib/                                                                                                                                                                                                                             
arm64-v8a    41 MB  ← lo que necesita un phone moderno
armeabi-v7a  15 MB  ← phones viejos 32-bit                                                                                                                                                                                         x86_64       26 MB  ← emuladores

82MB de librerías nativas, pero un phone real solo necesita una. Los 53MB que ves instalado son arm64 + assets. El APK de 94MB es porque incluye las tres.

  ---
Tres niveles de ataque

Nivel 1 — Gratis, cero código: App Bundle

Para Play Store, en vez de APK:
fvm flutter build appbundle --release
Play Store entrega solo la ABI del dispositivo. El usuario descarga ~20-25MB en vez de 53MB. Sin tocar una línea de código.

Nivel 2 — Dependencias muertas (revisar)

El análisis muestra paquetes que no recuerdo ver en uso activo:

┌──────────────────────────────────┬──────────────────────┬──────────┐
│             Package              │        Tamaño        │ ¿Se usa? │
├──────────────────────────────────┼──────────────────────┼──────────┤
│ pdfrx + pdfrx_engine             │ 225 KB Dart + nativo │ Dudoso   │
├──────────────────────────────────┼──────────────────────┼──────────┤
│ flutter_markdown_plus + markdown │ 153 KB Dart          │ ¿Dónde?  │
└──────────────────────────────────┴──────────────────────┴──────────┘

Si no se usan, sacarlos del pubspec.yaml reduce el nativo también. ¿Los recordás activos?

Nivel 3 — Los 9MB de flutter_assets

Eso es alto. Probablemente es el modelo TFLite. Verificá:
fvm flutter pub run --

Mejor: ¿sabés cuánto pesa assets/models/ o donde tenés el .tflite?

Si el modelo está en float32, cuantizarlo a int8 lo reduce ~75% con mínima pérdida de precisión.

  ---
Resumen de impacto esperado

┌──────────────────────────┬────────────────────────┐
│          Acción          │       Reducción        │
├──────────────────────────┼────────────────────────┤
│ App Bundle (Play Store)  │ -30MB descarga         │
├──────────────────────────┼────────────────────────┤
│ Sacar pdfrx si no se usa │ -5-8MB nativo estimado │
├──────────────────────────┼────────────────────────┤
│ Cuantizar modelo TFLite  │ -2-4MB                 │
├──────────────────────────┼────────────────────────┤
│ Total realista           │ ~15-20MB instalado     │
└──────────────────────────┴────────────────────────┘

Empezaría por confirmar si pdfrx y flutter_markdown_plus están en uso real.

✻ Churned for 44s

❯ el modelo pesa 1.3M, no se por que hay 9 m en assets                                                                                                                                                                                                                                    
● Searched for 1 pattern (ctrl+o to expand)                                                                                                                                                                                                                                                                                                                                                                                                                           
● Encontrado. 7.7MB son las imágenes — no el modelo.                                                                                                                                                                                                                                                                                                                             
● Read 1 file (ctrl+o to expand)

● Ahí está el problema. Son mockups de diseño que se colaron en el bundle:

┌───────────────┬────────┬──────────────────────────────┐                                                                                                                                                                        
│    Archivo    │ Tamaño │             Uso              │                                                                                                                                                                          ├───────────────┼────────┼──────────────────────────────┤                                                                                                                                                                        
│ documento.png │ 2.0MB  │ Mockup                       │                                                                                                                                                                          ├───────────────┼────────┼──────────────────────────────┤                                                                                                                                                                        
│ ver_todos.png │ 1.6MB  │ Mockup                       │
├───────────────┼────────┼──────────────────────────────┤
│ notas.png     │ 1.4MB  │ Mockup                       │
├───────────────┼────────┼──────────────────────────────┤
│ buscar.png    │ 1.3MB  │ Mockup                       │
├───────────────┼────────┼──────────────────────────────┤
│ home.png      │ 1.1MB  │ Mockup (el que me mostraste) │
├───────────────┼────────┼──────────────────────────────┤
│ logo.png      │ 348KB  │ Usado en la app ✅           │
├───────────────┼────────┼──────────────────────────────┤
│ nombre.png    │ 89KB   │ Mockup                       │
└───────────────┴────────┴──────────────────────────────┘

6 mockups de referencia visual dentro del APK. Vamos a confirmar que ninguno se usa en el código:

● Searched for 1 pattern (ctrl+o to expand)

● Ninguna referencia en código. Revisemos el pubspec:                                                                                                                                                                                 
● Searched for 1 pattern (ctrl+o to expand)                                                                                                                                                                                                          
● Causa confirmada: pubspec.yaml declara assets/images/ como directorio completo → incluye todos los archivos, mockups incluidos.                                                                                                                    
La solución es doble: sacar los mockups del directorio de assets y declarar solo logo.png:                                                                                                                                                         
● Bash(mkdir -p "/c/Users/Mario/Documents/escandoc/.context/mockups" && mv "/c/Users/Mario/Documents/escandoc/assets/images/buscar.png" "/c/Users/Mario/Documents/escan…)                                                          
⎿  Interrupted · What should Claude do instead?
❯ aaa, jajaja, ya lo hago yo, dejo solo logo                                                                                                                                                                                                                                                                                                                                                                                                                          
● Sí, hacelo vos — es mover archivos nomás.                                                                                                                                                                                                                                                                                                                                                                                                                           
Y después en pubspec.yaml cambiá:
# Antes                                                                                                                                                                                                                            - assets/images/                                                                                                                                                                                                                                                                                                                                                                                                                                                      # Después                                                                                                                                                                                                                          - assets/images/logo.png                                                                                                                                                                                                                                                                                                                                                                                                                                              Con eso la ganancia es:                                                                                                                                                                                                            - -7.4MB del bundle (de 9MB a ~1.6MB en flutter_assets)                                                                                                                                                                            - App instalada: ~45MB → ~18-20MB con App Bundle en Play Store
Dos cambios, sin tocar código.
