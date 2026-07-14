# 68 — Monetización · Avance de código

Documento vivo. Registra **lo que se implementó en código** de la monetización,
sesión por sesión. Complementa a `67_monetizacion.md` (decisiones de producto y
plan de las 5 fases); este archivo es el **diario de implementación**.

Orden del proyecto: **Domain → Tests → Data → UI**, con TDD (RED → GREEN → REFACTOR).

---

## Sesión 2026-07-13/14 — Fase 1 (Domain) completa

Feature nueva: `lib/features/subscription/`. Solo capa de dominio, **Dart puro**
(sin Flutter, sin RevenueCat). Corresponde a la Fase 1 del plan (§10 del doc 67).

### Archivos de producción creados

| Archivo | Qué contiene |
|---------|--------------|
| `domain/entitlement.dart` | `enum Entitlement { free, pro }` + `FreeTierLimits.maxDocuments = 15` (fuente de verdad única del límite free). |
| `domain/premium_feature.dart` | `enum PremiumFeature { multipagePdf, batchExport }` — las dos únicas features detrás del paywall. |
| `domain/purchase_package.dart` | `enum PurchasePlan { monthly, annual, lifetime }`, value object `PurchasePackage` (plan + productId + priceString) y `Offering` (lista de packages + `packageFor(plan)`). |
| `domain/repositories/purchase_repository.dart` | Interface abstracta `PurchaseRepository`: `getEntitlement()`, `getOfferings()`, `purchase(package)`, `restore()`. Abstrae al proveedor de pagos; el dominio no conoce RevenueCat. |
| `domain/usecases/can_add_document.dart` | `CanAddDocument.call(currentCount, entitlement) → bool`. `pro` = ilimitado; `free` = `currentCount < 15`. |
| `domain/usecases/is_premium_feature_unlocked.dart` | `IsPremiumFeatureUnlocked.call(feature, entitlement) → bool`. `pro` desbloquea todo; `free` nada. |

### Tests creados (TDD RED → GREEN verificado)

| Test | Casos |
|------|-------|
| `test/features/subscription/domain/usecases/can_add_document_test.dart` | pro ilimitado; free permite 0/14, bloquea 15/16/100; usa la constante como umbral. |
| `test/features/subscription/domain/usecases/is_premium_feature_unlocked_test.dart` | pro desbloquea todas; free bloquea multipagePdf, batchExport y todas. |
| `test/features/subscription/domain/purchase_package_test.dart` | igualdad por valor de `PurchasePackage`; `Offering.packageFor` devuelve el paquete o null. |

**Resultado: 13/13 tests GREEN · `flutter analyze` sin issues.**
Cada UseCase se escribió con un stub que lanzaba `UnimplementedError` (RED
verificado corriendo el test) antes de implementarlo (GREEN).

### Decisiones de diseño tomadas en código

1. **El dominio es agnóstico a "qué cuenta para los 15".** `CanAddDocument`
   recibe `currentCount` como parámetro. Si una nota o cada página de un PDF
   cuentan como documento se decide en el **gate** (Fase 4), no acá. Esto responde
   la pregunta abierta nº1 del revisor sin bloquear el domain.
2. **`IsPremiumFeatureUnlocked` recibe `feature` aunque hoy no lo use** en el
   cuerpo (todas son pro-only). El parámetro existe para que sumar una feature
   premium con otra condición sea agregar un valor al enum, sin tocar llamadores.
3. **Precios como String, nunca como número.** `PurchasePackage.priceString`
   viene formateado/localizado por la store. Cero lógica propia de precios
   (coherente con §9 del doc 67).
4. **Los 3 planes otorgan el mismo `pro`.** El dominio distingue `PurchasePlan`
   solo para que la UI arme la comparativa "Ver planes"; para desbloquear, los
   tres son equivalentes.

### Alineación con RevenueCat (verificado con Mario esta sesión)

- Entitlement en RevenueCat: **`pro`** → matchea `Entitlement.pro`. ✅
- Offering `default` con 3 packages (`$rc_monthly`, `$rc_annual`, `$rc_lifetime`)
  apuntando a productos monthly/yearly/lifetime del **Test Store**. ✅
- Falta (fuera de código): attachear los **productos reales** de Play/Apple al
  entitlement `pro` cuando existan.

---

## Pendiente (próximas sesiones)

- **Fase 2 — Data:** agregar `purchases_flutter` a pubspec + `PurchaseRepositoryImpl`
  sobre RevenueCat con **caché local del entitlement** (arranque offline).
  Bloqueada por las **API keys públicas** de RevenueCat (`goog_…` / `appl_…`),
  que salen de la Fase 0. No se testea unitariamente (plugin nativo).
- **Fase 3 — Presentation:** `PurchaseProvider` (tests con mocktail), paywall
  "Desbloqueá todo", pantalla "Ver planes", "Restaurar compras", claves es/en/pt.
- **Fase 4 — Gates:** cantidad (doc nº 16), PDF multipágina, export batch.
- **Fase 5 — Verificación en dispositivo.**

---

## Multiplataforma — iOS (revisado 2026-07-14)

**Todo lo de monetización funciona igual en iOS con el MISMO código.** No hay una
rama iOS aparte.

- **Domain (Fase 1):** Dart puro, 100% agnóstico de plataforma. Igual en ambas.
- **RevenueCat (`purchases_flutter`):** cross-platform por diseño. Única diferencia:
  la API key al inicializar. En `PurchaseRepositoryImpl` (Fase 2):
  ```dart
  final apiKey = Platform.isIOS ? 'appl_...' : 'goog_...';
  await Purchases.configure(PurchasesConfiguration(apiKey));
  ```
  Las keys públicas (`goog_`/`appl_`) están diseñadas para viajar en el binario;
  no son secretos. Se pueden poner en código (o inyectar por `--dart-define`, opcional).
- El entitlement `pro` y el offering `default` de RevenueCat unifican ambas tiendas.

### El `codemagic.yaml` NO necesita cambios para IAP/RevenueCat

- **In-App Purchase / StoreKit está disponible para todas las apps por defecto:**
  NO lleva entitlement, capability toggle ni entrada en `Info.plist`. Es distinto de
  Push Notifications (eso sí tiene el paso `aps-environment` en el yaml).
- `purchases_flutter` es una dependencia Flutter normal → el `flutter pub get` +
  `pod install` que Codemagic ya corre la compilan sola. `flutter build ipa` la
  empaqueta. **Cero pasos nuevos de CI.**

### Recordatorio para Fase 2 (deployment target)

- Deployment target actual: **iOS 15.5** (`project.pbxproj` ×3 + `Podfile`).
- `purchases_flutter` pide iOS 13+ → **holgado, no hay conflicto**.
- Aun así, al agregar la dependencia, reconfirmar el mínimo del plugin por el
  historial de "Module not found" por deployment target (ver
  `memory/feedback_ios_deployment_target.md`).

### iOS — lo "doble" es el papeleo, no el código (Fase 0)

- Crear los 3 productos **también** en App Store Connect (además de Play).
- Prerequisito Apple: **Paid Apps Agreement** firmado + datos bancarios/impositivos.
- Testing de compras iOS: **sandbox testers vía TestFlight** (por eso dependía de
  tener TestFlight andando).

---

## Historial

- **2026-07-13/14** — Fase 1 (Domain) implementada con TDD. 13 tests GREEN,
  analyzer limpio. Feature `subscription` creada. Nada dependiente de plugins
  nativos todavía.
- **2026-07-14** — Confirmado que la monetización funciona en iOS con el mismo
  código y que el `codemagic.yaml` NO necesita cambios para IAP/RevenueCat (ver
  sección "Multiplataforma — iOS").
