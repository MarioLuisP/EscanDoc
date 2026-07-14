# EscanDoc — Fase 0: Monetización (Stores + RevenueCat)

**Fecha:** 14 de julio de 2026
**Objetivo de la fase:** dejar armado el papeleo de Play Console, App Store Connect y RevenueCat para poder empezar a codear el flujo de compras (Fase 2), sin depender de trámites administrativos a mitad de camino.

---

## 1. Google Play Console

### 1.1 Ficha de la app
- App creada: **EscanDocs**
- Package name: *(pendiente de confirmar/registrar acá — completar cuando se defina el nombre final: ScanDoc / EscanDoc / EscanDocs)*

### 1.2 Cuenta de comerciante / Perfil de pagos
- Se creó la cuenta de comerciante de Google Payments asociada al perfil de pagos existente: **Mario Luis Passalia** (Persona física, ID de perfil 8327-8476-6796).
- Información pública de la empresa cargada:
    - Nombre de la empresa: Mario Luis Passalia
    - Categoría: Software de computadoras
    - Nombre del resumen de tarjeta de crédito: `ESCANDOC`
    - Correo de atención al cliente: cargado (dedicado, distinto al personal)
- **Nota:** en el proceso apareció una notificación bajo el nombre "TranvIA Solution" — se confirmó que es el nombre de empresa/comerciante cargado en el perfil, no una app distinta. No requiere acción.

### 1.3 Forma de pago
- Cuenta bancaria cargada: **Banco del Sol**, CBU terminado en `...8006`, titular Mario Luis Passalia.
- SWIFT/BIC utilizado: `SLLOARBAXXX` (obtenido de directorio público Wise; **pendiente confirmación directa con soporte de Banco del Sol** para descartar error, aunque ya fue aceptado por Google).
- Verificación bancaria: **aprobada** — se subió como comprobante el resumen de cuenta (Caja de Ahorro por Banda) de junio 2026, con CBU visible coincidente.
- Estado actual: forma de pago activa ("Transferencia bancaria a una cuenta ••••8006").
- Umbral de pago confirmado en la plataforma: **USD 1.00** (se paga mensualmente si se supera ese mínimo acumulado). *No hay umbral de 50/100 USD como se pensaba inicialmente — eso puede corresponder a otra plataforma.*

### 1.4 Programa de cargos del servicio del 15%
- Pendiente de evaluar: banner visible en Perfil de pagos para agrupar cuentas de desarrollador y acceder a la tasa reducida del 15% (vs. 30%) hasta el primer millón de USD anuales. **No se tocó, decisión para más adelante.**

### 1.5 Suscripciones — BLOQUEADO
- Estado: `Monetiza con Play → Productos → Suscripciones` ya es accesible (sin bloqueo de requisitos), pero **no se pudo crear ningún producto todavía**.
- **Motivo del bloqueo:** Play Console exige tener al menos un build (AAB) subido a algún track (alcanza con el track interno de pruebas) antes de habilitar la creación de la primera suscripción.
- **Acción pendiente:** compilar `flutter build appbundle` y subirlo a `Prueba y lanza → Testing → Interno`. Una vez subido, crear:
    - `pro_mensual` (suscripción, base plan mensual)
    - `pro_anual` (suscripción, base plan anual)
    - `pro_lifetime` (producto único, no consumible)

---

## 2. App Store Connect

### 2.1 Acceso
- Hubo un bloqueo temporal por falta del código de acceso (gestionado por el sobrino de Mario, tester iOS). **Resuelto**, acceso recuperado.

### 2.2 TestFlight
- Se subió un IPA a TestFlight. El ícono de la app no aparecía en el listado (a diferencia de otra app ya publicada).
- **Causas posibles identificadas** (a confirmar con Claude Code):
    1. Build aún en estado "Processing"
    2. Falta configurar/generar el ícono en `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
    3. Ícono con canal alfa (transparencia) — Apple lo rechaza para el ícono principal
    4. Falta alguna resolución obligatoria (ej. 1024×1024 para App Store)
- **Estado:** derivado a Claude Code para diagnóstico y fix. Pendiente de confirmar causa y solución.

### 2.3 Productos creados
Se crearon los 3 productos, todos en estado **"Faltan metadatos"** (creados pero incompletos — falta nombre visible, descripción y precio):

| Producto | Tipo | ID | Duración | Estado |
|---|---|---|---|---|
| Pro Lifetime | No consumible | `pro_lifetime` | — | Faltan metadatos |
| Pro Mensual | Suscripción auto-renovable | `pro_mensual` | 1 mes | Faltan metadatos |
| Pro Anual | Suscripción auto-renovable | `pro_anual` | 1 año | Faltan metadatos |

- `pro_mensual` y `pro_anual` quedaron dentro del mismo **subscription group** (`pro`), nivel 1 y 2 respectivamente — esto permite que el usuario pueda subir/bajar de plan sin duplicar cobro.

### 2.4 Pendiente importante — regla de Apple
> La primera compra dentro de la app (de cualquier tipo) **debe enviarse junto con una versión nueva de la app a revisión**. Recién después de que esa primera IAP sea enviada a revisión, se pueden enviar las demás de forma independiente.

**Acción pendiente:**
1. Completar metadatos de al menos un producto (nombre visible, descripción, precio, captura de paywall)
2. Seleccionarlo en la sección "Compras dentro de la app y suscripciones" de la ficha de versión
3. Enviar la versión completa a revisión de Apple

### 2.5 Prerequisito no confirmado
- **Paid Apps Agreement**: no se confirmó explícitamente en esta sesión si está firmado con datos bancarios/impositivos para EscanDoc. Falta verificar — es requisito para que los productos pagos se puedan vender de verdad, aunque estén creados.

---

## 3. RevenueCat

### 3.1 Proyecto
- Proyecto creado: **EscanDocs**
- Categoría: Productivity
- Tipo de proyecto: app nueva con compras in-app
- Plataformas: iOS + Android (Flutter)
- Plan: Free tier (gratis hasta USD 2.500 de MTR mensual, luego 1% sobre lo generado ese mes). No se cargó tarjeta.
- **Pendiente:** confirmar el correo electrónico de la cuenta (banner de confirmación pendiente visto en el dashboard).

### 3.2 Entitlement
- Identifier definitivo: **`pro`** (display name: "EscanDocs Pro")
- *Nota de proceso: el wizard automático había generado un entitlement con identifier `EscanDocs pro` (con espacio y mayúscula) — no editable una vez creado. Se creó uno nuevo manualmente con el identifier correcto (`pro`); el anterior quedó descartado sin productos reales asociados.*

### 3.3 Productos (Test Store)
Se generaron automáticamente y se attachearon al entitlement `pro`:

| Producto | ID interno | Tipo |
|---|---|---|
| Monthly | `monthly` | Suscripción |
| Yearly | `yearly` | Suscripción |
| Lifetime | `lifetime` | Compra única |

Estos son productos de **Test Store** (sandbox de RevenueCat) — permiten simular compras y probar toda la lógica de entitlements sin depender de builds firmados ni de las stores reales.

### 3.4 Offering
- Offering **`default`** ya armado por el wizard, con 3 packages correctamente mapeados:
    - `$rc_monthly` → producto `monthly`
    - `$rc_annual` → producto `yearly`
    - `$rc_lifetime` → producto `lifetime`

### 3.5 Pendiente
- Cuando existan los productos reales en Play Console y App Store Connect (`pro_mensual`, `pro_anual`, `pro_lifetime` en cada plataforma), hay que:
    1. Crearlos también como productos en RevenueCat (uno por plataforma)
    2. Attachearlos al mismo entitlement `pro` (van a convivir con los de Test Store)
- Obtener las **Public SDK API Keys** (Project Settings → API Keys):
    - Una que empieza con `goog_...` (Android)
    - Una que empieza con `appl_...` (iOS)
    - (No confundir con el "REST API Identifier", que es para backend, no para el SDK de la app)

---

## 4. Desarrollo en paralelo (Claude Code)

Mientras se resolvía el papeleo, se avanzó en paralelo la arquitectura de dominio para la Fase 2:

- ✅ `Entitlement` enum + `FreeTierLimits` + `PremiumFeature` enum
- ✅ UseCase `CanAddDocument` (TDD)
- 🔄 UseCase `IsPremiumFeatureUnlocked` (TDD) — en progreso
- ⬜ Interface `PurchaseRepository` + entidades — pendiente

El identifier `pro` del entitlement de RevenueCat y los nombres de producto ya están confirmados como compatibles con el enum `PurchasePlan { monthly, annual, lifetime }` del dominio (el mapeo store→dominio lo resuelve la capa de data, no hace falta que los nombres sean idénticos).

Próximo paso acordado con Claude Code: armar el esqueleto de Fase 2 (pubspec + `PurchaseRepositoryImpl` con mapeo y caché), sin cargar las API keys reales todavía.

---

## 5. Resumen de bloqueos activos

| Bloqueo | Plataforma | Qué se necesita para destrabarlo |
|---|---|---|
| No se pueden crear suscripciones | Play Console | Subir un AAB a un track (interno alcanza) |
| Ícono no aparece en TestFlight | App Store Connect | Diagnóstico de Claude Code (ver §2.2) |
| Productos con "Faltan metadatos" | App Store Connect | Completar nombre, descripción, precio de cada producto |
| Primera IAP no enviada a revisión | App Store Connect | Requiere build + metadatos completos antes de poder enviar |
| Confirmar Paid Apps Agreement | App Store Connect | Verificar estado en la cuenta (no confirmado en esta sesión) |
| Productos reales no attacheados | RevenueCat | Depende de que existan en Play/Apple primero |
| Confirmar SWIFT de Banco del Sol | Play Console (dato ya cargado) | Chequeo opcional con soporte del banco |
| Confirmar email de cuenta | RevenueCat | Click en link de confirmación enviado por mail |
| Monotributo / situación fiscal | General | Pendiente, no bloqueante para esta fase técnica |

---

## 6. Próximos pasos sugeridos (orden recomendado)

1. Resolver con Claude Code el tema del ícono de TestFlight.
2. Compilar y subir el AAB a Play Console (track interno) → desbloquea creación de suscripciones ahí.
3. Crear `pro_mensual` / `pro_anual` / `pro_lifetime` en Play Console con esa vía destrabada.
4. Completar metadatos de los 3 productos en App Store Connect y enviar la primera IAP a revisión junto con una versión de la app.
5. Attachear los productos reales (Android + iOS) al entitlement `pro` en RevenueCat.
6. Obtener las API keys (`goog_...` / `appl_...`) y pasárselas a Claude Code para completar `PurchaseRepositoryImpl`.
7. Confirmar situación de Paid Apps Agreement en Apple.
8. (No bloqueante) Resolver situación de monotributo antes de que la app empiece a facturar de verdad.