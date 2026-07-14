# Investigación — Ícono no aparece en TestFlight / App Store Connect

**Estado: ★ FIX APLICADO en el repo (2026-07-14). Falta commit + build Codemagic +
validar.** Causa raíz: perfil de color ICC (`iCCP`) embebido en el ícono. Se limpió
el source y se regeneraron los 21 íconos sin `iCCP`. Ver "★ FIX APLICADO" abajo.

---

## ★ CAUSA RAÍZ (hallada 2026-07-14, comparando con QueHacemosClean)

Se comparó EscanDoc contra **QueHacemosClean** (misma cuenta, mismo Codemagic, el
ícono se ve BIEN). **Todo es idéntico** — `Contents.json` idéntico (diff sin
diferencias), mismas 3 configs con `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`,
mismo build `flutter build ipa --release`, Info.plist sin `CFBundleIcon*` en ambas —
salvo **UNA cosa**: el formato del PNG del ícono.

| | QueHacemosClean (FUNCIONA) | EscanDoc (BLANCO) |
|---|---|---|
| Chunks del PNG 1024 | `IHDR, PLTE, IDAT, IEND` | `IHDR, **iCCP**, tEXt, IDAT, IEND` |
| **Perfil ICC embebido (`iCCP`)** | **No** | **SÍ** ← la diferencia |
| colortype | Palette (indexado) | RGB (truecolor) |
| Alfa | No | No |

**El ícono de EscanDoc trae un perfil de color ICC embebido (chunk `iCCP`).** Es una
causa **conocida** de que Apple no renderice el ícono: `actool` de Xcode y la
extracción de íconos de App Store Connect se traban con PNGs que traen perfil ICC y
muestran placeholder/blanco. QH no lo trae → se ve bien.

### Origen
El source `assets/images/logo.png` trae `iCCP` + `gAMA` + `cHRM` + `pHYs`.
`flutter_launcher_icons` **preserva ese perfil** al generar los 21 íconos iOS.
Cadena: `logo.png` con iCCP → flutter_launcher_icons → íconos con iCCP → Apple no
los renderiza.

### ★ FIX APLICADO (2026-07-14)
No había ImageMagick; se usó un stripper de chunks en Python (lossless, no toca
IDAT) → `scratchpad/png_tools.py` (list/strip).

1. **Source limpiado:** `assets/images/logo.png` — se removieron `gAMA, cHRM,
   iCCP, pHYs, tEXt`. Quedó solo `IHDR, IDAT, IEND`.
2. **Regenerado:** `dart run flutter_launcher_icons` (v0.14.4) → 21 íconos iOS +
   íconos Android. `remove_alpha_ios: true` intacto.
3. **Verificado:** los 21 íconos iOS quedaron **RGB, sin `iCCP`, sin alfa,
   `aux=[]`**. El 1024 se ve igual que antes (logo verde, sin fondo raro).
4. **Versión subida** a `1.0.0+7` en `pubspec.yaml`.

**Pendiente (lo hace Mario):**
- Commit + push de los cambios (source + 21 íconos iOS + íconos Android + pubspec).
- Disparar workflow `ios-testflight` en Codemagic.
- Cuando procese, validar que el header de ASC / TestFlight / iPhone muestren el
  logo verde. **Esta es la validación final de que el iCCP era la causa.**

Archivos modificados por el fix: `assets/images/logo.png`, los 21
`ios/.../AppIcon.appiconset/Icon-App-*.png`, íconos Android (`mipmap-*/ic_launcher.png`
+ `drawable-*/ic_launcher_foreground.png`), `pubspec.yaml`.

---

## Síntoma

- En **App Store Connect** (header arriba a la izquierda, al lado de "EscanDoc")
  aparece el **placeholder de cuadrícula gris**, no el logo verde.
- El ícono **tampoco aparecía en TestFlight**.
- Versión en ese momento: **`1.0.0+6`**. La app figura como "1.0 En preparación
  para el envío".

---

## Verificación del repo (hecha ANTES de hallar la causa)

> ⚠️ Esta sección se hizo antes de comparar con QH. Todo lo de abajo es correcto
> **pero incompleto**: el chequeo de alfa miró colortype pero NO los chunks
> auxiliares, y ahí estaba escondido el `iCCP`. Sirve para saber qué ya se
> descartó; la causa real está arriba (★ CAUSA RAÍZ).

| Chequeo | Resultado | Cómo se verificó |
|---------|-----------|------------------|
| Todos los tamaños de ícono presentes (incl. 1024) | ✅ | `ls` de `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — 21 PNGs + Contents.json |
| Sin canal alfa (Apple lo rechaza) | ✅ | Los 21 PNGs son **colortype=2 (RGB)**. `remove_alpha_ios: true` en pubspec funcionó. |
| El PNG de 1024 es un ícono válido (no está en blanco) | ✅ | Se abrió: es el logo verde con documento + check. |
| Íconos committeados (Codemagic los ve) | ✅ | `git ls-files` los lista; `git status` limpio. |
| `Contents.json` con filenames correctos | ✅ | Incluye `1024x1024 ios-marketing`; todos los filenames matchean. |
| `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` | ✅ | Presente en las **3** configs (Debug/Release/Profile) del `project.pbxproj`. |
| `Assets.xcassets` en Resources build phase | ✅ | Línea 217 del `project.pbxproj` → `actool` lo procesa. |
| `codemagic.yaml` no toca los íconos | ✅ | Workflow `ios-testflight` hace `flutter build ipa --release`; sus pasos son entitlements, code signing y export compliance. Nada que borre/pise `Assets.xcassets`. |

### Dato decisivo: el IPA del 9-may YA tenía el ícono correcto

- El build del **9-may-2026** salió del commit **`db5ff2d`** ("fix 15.5").
- El blob hash del PNG de 1024 en ese commit es **`afeab7c89d27ccfb1d22005b5de541d25b467122`**,
  **idéntico** al de hoy (HEAD). Todos los tamaños ya existían el 9-may.
- Conclusión: **el IPA del 9-may se compiló desde un repo con el ícono verde
  correcto.** No es un "build viejo sin ícono".

---

## Conclusión del diagnóstico (SUPERADA — ver ★ CAUSA RAÍZ arriba)

> ❌ Conclusión previa, quedó descartada: se creyó que era caché/procesamiento de
> App Store Connect porque el repo "se veía correcto". La comparación con QH
> encontró la diferencia real (perfil `iCCP` embebido). NO era caché.

---

## Nota cosmética (aparte, no es la causa del blanco)

El ícono de origen tiene **esquinas redondeadas y una sombra "horneadas"** en el
PNG. iOS aplica su propia máscara redondeada encima, así que conviene que el ícono
fuente sea un **cuadrado lleno hasta el borde, sin esquinas redondeadas ni sombra
propia**, para evitar bordes blancos raros tras la máscara. Mejora para pulir, no
urgente.
