# 67 — Monetización

Documento vivo. Centraliza **todo lo referido a monetización** de EscanDoc.
Reemplaza como fuente de verdad a la sección 7 del PVD (`00_docscan_pro_pvd.md`),
que queda como referencia histórica.

Estado: **decisiones cerradas (2026-07-13)** — ver §9. Plan de implementación en §10.

---

## 1. Punto de partida (lo que ya estaba en el PVD)

Modelo original: **4 opciones de pago**.

| Plan | Precio | Detalle |
|------|--------|---------|
| Gratis | $0 | 15 documentos · 30 notas · features básicas · sin ads · sin marca de agua · OCR completo |
| Pro Mensual | $2.99 USD/mes | todo ilimitado, cloud backup, export batch |
| Pro Anual | $24.99 USD/año | igual que mensual, ~30% de ahorro |
| Licencia Extendida | $49.99 USD (una vez) | válida 5 años, renovable con descuento al finalizar |

Implementación prevista: **RevenueCat**, botón "Restaurar compras" muy visible,
cancelación en 1 toque, email de confirmación, sin contratos anuales forzados.

Proyección conservadora: 500-1000 descargas/mes, 3-5% conversión, **$50-150 USD/mes** año 1.

---

## 2. Replanteo del público (esto cambia el análisis)

La app **no se pensó para rechazar al público medio**. Se pensó con **un solo objetivo
de diseño**: que una persona mayor (60-85) la pueda usar **sin fricción**.

Pero por debajo, la app es una **navaja suiza** que reemplaza ~4 apps sueltas:

- Escáner de documentos (UI nativa)
- Escáner / guardado de fotos a galería
- Clasificador automático + OCR (extracción de texto)
- Importar / exportar + OCR de PDF (únicos o multipágina)
- Bloc de notas
- Recordatorio de vencimientos y otras fechas

**Conclusión:** son **dos públicos**, no uno.

- **Mayor:** capaz no la usa toda. Necesita cero fricción y un camino obvio.
- **Medio / power user:** la adopta en serio, consolida 4 apps en una,
  y para ese público **tener opciones de pago es un beneficio, no ruido**.

> Corrección respecto de la charla inicial: "cortar a 2 tiers" era una conclusión
> válida solo si el público fuera exclusivamente el mayor. Con público dual, ofrecer
> varias opciones tiene sentido.

---

## 3. Principio rector: no es *cuántas* opciones, es *a quién le mostrás qué*

El error a evitar no es "tener muchos planes". Es **mostrarle a todos la misma
pantalla de precios**. La solución es **divulgación progresiva**:

- **El mayor** ve un camino corto y evidente:
  `Gratis` → **"Desbloqueá todo"** (una sola acción, sin comparar tablas).
- **El medio** que quiere comparar entra a **"Ver planes"** y ahí sí encuentra
  el cuadro completo (mensual / anual / de por vida).

Así se sirve a los dos sin sacrificar a ninguno: opciones para el que las busca,
cero parálisis para el que no.

---

## 4. El tema de los "5 años" — decisión a cerrar

### El planteo original
La licencia extendida vencía a los **5 años** con opción de renovar.
Razón de Mario: *"en 5 años vaya a saber qué pasa o si la mantengo"* —
no querer comprometerse a soportarla para siempre.

### El problema
Una licencia que **vence y hay que renovar** es una **suscripción disfrazada**.
Reintroduce la ansiedad de compromiso recurrente que justamente el pago único
quería eliminar. Y es confusa para **los dos públicos**: el mayor no la entiende,
y el medio se pregunta "¿por qué mi compra 'única' se vence?".

### La distinción clave (esto resuelve la preocupación de Mario)

> **"Tuyo para siempre" es una promesa sobre la LICENCIA, no sobre el SOPORTE.**

Que la licencia sea de por vida **no obliga a mantener la app 100 años**. Son
dos cosas separadas:

- **Licencia de por vida:** el usuario que pagó una vez conserva el acceso a las
  features que compró, en la versión que compró, mientras la app funcione en su
  dispositivo. No caduca por calendario.
- **Soporte / mantenimiento:** es discrecional de Mario. Si en 5 años decide no
  seguir, la app **sigue funcionando** para quien ya pagó; simplemente deja de
  haber updates. Eso es lo estándar en software de pago único y nadie lo siente
  como una estafa.

Con esta distinción, el miedo de "¿y si no la mantengo en 5 años?" **desaparece
sin necesidad de poner un vencimiento**. El pago único de por vida es viable.

### Opciones sobre la mesa
1. **De por vida real** (pago único, sin vencimiento) — coherente con el pitch
   anti-suscripción, es el diferencial más fuerte. *(Recomendado)*
2. **Suscripción honesta** (mensual/anual) para quien prefiere pagar de a poco.
3. Tener **ambas** (1 + 2) está perfecto. Lo único a eliminar es el **híbrido
   confuso**: el pago "único" que en realidad vence.

**CERRADO (2026-07-13):** de por vida **real**, sin vencimiento. Se mantienen además
mensual y anual. Lo único que muere es el híbrido de los 5 años. Ver §9.

---

## 5. Ángulo de marketing (más importante que el $/mes)

El mejor argumento de venta **y** la mejor justificación de precio es:

> **"Reemplazá 4 apps con una."**

El usuario medio que entiende que consolida escáner + OCR + notas + recordatorios
paga la de-por-vida sin pestañear, porque ya sabe lo que cuesta tener 4 apps
sueltas. Ese mensaje merece estar **en el centro**, por encima de la comparativa
de $/mes contra Adobe/CamScanner.

---

## 6. Diferenciadores de la decisión

- **Pago único / de por vida** — casi nadie lo ofrece; match perfecto con el mayor.
- **Sin ads en el free** — a diferencia de CamScanner.
- **Privacidad local-first** — dato que refuerza confianza.
- **4-en-1** — consolidación real de funciones.

---

## 7. Implementación (técnico)

- **RevenueCat** para manejar complejidad cross-platform (iOS + Android).
- Botón **"Restaurar compras"** muy visible (crítico para el mayor que cambia de teléfono).
- Cancelación en 1 toque desde la app.
- Email de confirmación inmediato.
- Sin contratos anuales forzados (lección de Adobe Scan).
- Recordar el corte de las stores (Apple/Google 15-30%) al calcular ingreso neto.

*(Sin implementar todavía — es diseño de producto, no código aún.)*

---

## 8. Free tier — qué límite dispara el upgrade

Límite actual propuesto: **15 documentos / 30 notas**.

**CERRADO (2026-07-13):** el "momento upgrade" es **contextual, en los gates**:
el paywall aparece solo al chocar con un límite — guardar el documento nº 16,
importar un PDF multipágina, o usar export batch. Sin banners, sin contadores,
sin nags. El mayor que nunca choca, nunca ve precios.

Nota de schema: el límite "30 notas" ya no aplica — desde la DB v3 las notas
viven en `note_content` dentro de `documents`, no son entidades aparte.
El único límite de cantidad es **15 documentos**.

---

## 9. Decisiones cerradas (2026-07-13, con Mario)

- [x] **"5 años" vs "de por vida real"** → **De por vida real**, sin vencimiento.
      La licencia no caduca; el soporte sigue siendo discrecional (ver §4).
- [x] **Planes ofrecidos** → **Mensual ($2.99) + Anual ($24.99) + De por vida ($49.99)**.
      Se mantienen los 3; con divulgación progresiva (§3) el mayor nunca ve la tabla,
      así que tener 3 opciones no le agrega fricción y sirve al usuario medio.
- [x] **Free vs premium** → Free: **todas las features funcionales** (escáner, OCR,
      clasificador, notas, vencimientos) con límite de **15 documentos**.
      Premium: documentos ilimitados + import/OCR de **PDF multipágina** + **export batch**.
- [x] **Momento upgrade** → **contextual en los gates** (doc nº 16, PDF multipágina,
      export batch). Cero UI persistente (ver §8).
- [x] **Quién paga** → mecanismos de store (métodos de pago familiares, "Restaurar
      compras" prominente, paywall que un familiar entiende en 10 segundos)
      **+ promo codes nativos** de Play/App Store para regalar caso por caso.
      Sin backend ni sistema de regalo propio.
- [x] **Precios por región** → precio base USD + **plantillas automáticas** de las
      stores (ajuste por poder adquisitivo). Revisar **Argentina a mano** por
      volatilidad. Cero lógica propia de precios.

---

## 10. Plan de implementación

Orden obligatorio del proyecto: **Domain → Tests → Data → UI**, con TDD
(RED → GREEN → REFACTOR) en todo lo que no dependa de plugins nativos.

### **Fase 0 — Stores y RevenueCat (sin código)

1. **Play Console:** crear productos — `pro_mensual` (sub mensual), `pro_anual`
   (sub anual), `pro_lifetime` (in-app no consumible). Precios base USD con
   plantillas automáticas; revisar ARS a mano.
2. **App Store Connect:** los mismos 3 productos. Prerequisito: Paid Apps
   Agreement firmado + datos bancarios/impositivos cargados.
3. **RevenueCat:** proyecto con app Android + iOS, entitlement `pro`, offering
   `default` con 3 packages (monthly/annual/lifetime), API keys por plataforma.
4. **Promo codes:** se generan desde cada store cuando haga falta — no requieren
   código en la app (el flujo de canje es de la store).**

### Fase 1 — Domain (TDD, Dart puro, sin Flutter)

5. Entidad/enum `Entitlement` (`free` / `pro`) + constante del límite (15).
6. UseCase `CanAddDocument(currentCount, entitlement)` → test RED → GREEN.
7. UseCase `IsPremiumFeatureUnlocked(feature, entitlement)` para
   `multipagePdf` y `batchExport` → TDD.
8. Interface `PurchaseRepository` (getEntitlement, getOfferings, purchase,
   restore) — abstracción pura, sin RevenueCat.

### Fase 2 — Data

9. Agregar `purchases_flutter` (SDK RevenueCat) a pubspec.
10. `PurchaseRepositoryImpl` sobre RevenueCat + **caché local del entitlement**
    (para que la app arranque offline sabiendo si es pro). Depende de plugin
    nativo → **no se testea unitariamente**, verificación manual en dispositivo.

### Fase 3 — Presentation

11. `PurchaseProvider` (entitlement, offerings, loading, errores) → tests de
    lógica de estado con mocktail (repo mockeado).
12. **Paywall "Desbloqueá todo"** (camino del mayor): una pantalla, un botón
    grande con el precio de por vida, lenguaje según reglas UX mayores
    ("test del nene de 5 años"), y link discreto "Ver planes".
13. **Pantalla "Ver planes"**: comparativa mensual/anual/de por vida, con
    "Reemplazá 4 apps con una" como mensaje central (§5).
14. **"Restaurar compras"** en Settings **y** dentro del paywall.
15. Claves de localización **es/en/pt con paridad total** + regla
    EasyLocalization/Navigator en las pages nuevas.

### Fase 4 — Gates (enforcement)

16. Gate de cantidad en el **pipeline compartido scan/import** al persistir:
    si `COUNT(documents) >= 15` y entitlement free → paywall en vez de guardar
    (sin perder lo escaneado: se guarda tras el upgrade o se descarta con aviso).
17. Gate en **import de PDF multipágina** (`ImportProvider.prepareImport`).
18. Gate en **export batch**.

### Fase 5 — Verificación manual (dispositivo)

19. Android: license testers en Play + compras de prueba reales.
20. iOS: sandbox testers vía TestFlight/Codemagic (recordar: capabilities y
    config Xcode van por scripts yaml, no editar pbxproj a mano).
21. Probar "Restaurar compras" en un segundo dispositivo y el canje de un
    promo code de punta a punta.

---

## Historial

- **2026-07-13** — Creación del doc. Se replantea público (dual, no solo mayor),
  se introduce divulgación progresiva, y se separa "licencia de por vida" de
  "soporte eterno" para resolver el miedo de los 5 años.
- **2026-07-13 (2)** — Mario cierra las 6 decisiones abiertas (ver §9): lifetime
  real, se mantienen los 3 planes, free = 15 docs, paywall contextual, promo
  codes de store, precios por plantillas automáticas. Se agrega §10 (plan de
  implementación en 5 fases).



revision:


● Leí el plan completo de Fable. Te doy mi lectura honesta: está muy bien armado y sí, se puede arrancar la próxima sesión — pero con un matiz de secuencia importante.

Lo que está bien

- Respeta el orden del proyecto (Domain→Tests→Data→UI) y marca bien qué se testea con TDD y qué se verifica en device (las capas de plugin nativo). Correcto.
- RevenueCat + caché local del entitlement para arrancar offline sabiendo si es pro — es exactamente lo que necesita tu público (el mayor no va a estar siempre online, y la app tiene que saber al instante si desbloqueó).
- Gates contextuales sin UI persistente + "Restaurar compras" prominente — fiel a la filosofía UX. El mayor que nunca choca, nunca ve precios.
- El domain abstrae RevenueCat detrás de PurchaseRepository — limpio, testeable, y si mañana cambiás de proveedor no tocás la lógica.

El matiz clave de secuencia

No todo se puede empezar igual. Hay dos ritmos:

- Fase 1 (Domain) está 100% libre — es Dart puro, sin depender de las stores ni de RevenueCat. Eso lo arrancamos ya la próxima sesión con TDD (los UseCases CanAddDocument, IsPremiumFeatureUnlocked, la interface
  PurchaseRepository). Es el arranque perfecto y no depende de nada externo.
- Fase 0 (stores) tiene tiempo de calendario y bloquea TODO el testing real. El Paid Apps Agreement, los datos bancarios/impositivos en App Store Connect y la cuenta de merchant en Play tardan días y necesitan tus datos. Sin
  eso, no podés probar una sola compra. Así que eso lo tenés que empezar vos en paralelo, cuanto antes, mientras yo hago el domain.

Resumen: la próxima sesión = Fase 1 (domain, TDD), y vos disparás Fase 0 por tu lado.

Tres cosas para clavar antes de llegar a los gates

1. ¿Qué cuenta para el límite de 15? Las notas son documentos, y un PDF multipágina son N documentos. Un PDF de 12 páginas te comería 12 slots de una. Hay que definir si el free cuenta notas y páginas, o solo "documentos     
   raíz". (Nota: el multipágina ya es premium, así que se cruza — conviene alinearlo.)
2. Qué pasa con lo escaneado al chocar el gate. El gate salta al guardar el doc 16, cuando el usuario ya escaneó y esperó el OCR. "Se guarda tras el upgrade o se descarta con aviso" está bien en el papel, pero para un mayor  
   es delicado — merece diseño de UX, no solo código. Perder lo que acabás de escanear frustra.
3. El testing de iOS depende del primer TestFlight, que todavía no saliste (está en tus pendientes). Android lo podés probar antes (internal testing track). Así que las compras iOS van a esperar a que el pipeline de Codemagic
   esté andando.

Un detalle lindo

El gate de "PDF multipágina = premium" se enchufa justo en ImportProvider, donde acabamos de trabajar con el selector de rango. Hay continuidad — cuando lleguemos a Fase 4, ya conocemos ese código al dedillo.

Veredicto: plan sólido, listo para ejecutar. La próxima sesión arrancamos por el domain (Fase 1) y vos ponés en marcha el papeleo de las stores (Fase 0) en paralelo. 

✅ Fase 1 (Domain) completa↓— 13/13 tests GREEN, analyzer sin issues.

Lo que quedó armado

lib/features/subscription/domain/
├── entitlement.dart              enum Entitlement (free/pro) + FreeTierLimits.maxDocuments = 15
├── premium_feature.dart          enum PremiumFeature (multipagePdf, batchExport)                                                                                                                                                
├── purchase_package.dart         PurchasePlan, PurchasePackage, Offering
├── repositories/
│   └── purchase_repository.dart  interface pura (getEntitlement, getOfferings, purchase, restore)
└── usecases/
├── can_add_document.dart          pro=ilimitado · free < 15
└── is_premium_feature_unlocked.dart   pro desbloquea todo · free nada

Todo el domain es Dart puro, sin Flutter, sin RevenueCat — como manda el plan. La lógica de negocio quedó testeada con TDD real (RED→GREEN verificado en cada UseCase).

Decisión de diseño que confirmo: CanAddDocument recibe currentCount como parámetro, así que el domain no sabe "qué cuenta para los 15" (notas, páginas de PDF). Esa es la pregunta abierta nº1 del revisor y la resolvemos en    
Fase 4 (gates), sin bloquear nada ahora.

Estado de las fases

┌────────────────────────────────────────────────────┬─────────────────────────────────────────────┐
│                        Fase                        │                   Estado                    │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ 0 — Stores + RevenueCat (papeleos)                 │ �её vos, en curso (Play Console)            │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ 1 — Domain (TDD)                                   │ ✅ hecha                                    │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ 2 — Data (PurchaseRepositoryImpl sobre RevenueCat) │ ⏳ bloqueada por Fase 0 (necesita API keys) │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ 3 — Presentation (paywall, providers)              │ ⏳                                          │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ 4 — Gates                                          │ ⏳                                          │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────┤
│ 5 — Verificación en dispositivo                    │ ⏳                                          │
└────────────────────────────────────────────────────┴─────────────────────────────────────────────┘

Próximo paso

La Fase 2 necesita las API keys de RevenueCat (que salen de la Fase 0), pero puedo adelantar trabajo que no las requiere: agregar purchases_flutter al pubspec y dejar el esqueleto de PurchaseRepositoryImpl con el mapeo       
RevenueCat→dominio y la caché local del entitlement, listo para enchufar las keys.