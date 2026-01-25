# ÉPICA 5 - ONBOARDING: Especificación de Desarrollo

**Fecha:** 24 de Enero 2026  
**Versión:** 1.0  
**Historias:** HU-013

---

## OBJETIVO DE LA ÉPICA

Implementar tutorial inicial de 3 pasos para primera experiencia. Crítico para validación con usuarios mayores (60-85 años). Versión básica funcional, refinamiento post-ajustes UI.

**Dependencia:** Ninguna (puede implementarse independiente).

---

## HISTORIAS DE USUARIO

### HU-013: Tutorial inicial obligatorio

### HU-013: Tutorial inicial obligatorio
**Prioridad:** ALTA

**Como** persona mayor usando la app por primera vez  
**Quiero** un tutorial simple de 3 pasos  
**Para** entender cómo usarla

**Criterios de Aceptación:**
- [ ] Primera vez que abre app, muestra onboarding
- [ ] 3 pantallas máximo:
   1. "Escaneá documentos fácilmente" (imagen botón ESCANEAR)
   2. "Encontralos con búsqueda" (imagen lupa)
   3. "Agregá notas y recordatorios" (imagen nota)
- [ ] Botón "SIGUIENTE" grande en cada pantalla (200x60 dp)
- [ ] Última pantalla: "EMPEZAR" (cierra tutorial, va a home)
- [ ] Opción "Ver tutorial de nuevo" en menú configuración
- [ ] Texto grande (20sp), imágenes claras
- [ ] Guarda en SharedPreferences que completó onboarding
- [ ] No vuelve a aparecer automáticamente

---


**Criterios clave:**
- 3 pantallas máximo
- Botón "SIGUIENTE" grande (200x60dp)
- Última pantalla: "EMPEZAR"
- Texto 20sp, imágenes claras
- Guarda en SharedPreferences
- Opción "Ver tutorial de nuevo" en configuración

---

## CONTRATO DE TESTS

### PASO 1: Domain (lógica mínima)

**Tests unitarios requeridos:**

```
test/features/onboarding/domain/usecases/

└── check_onboarding_status_test.dart
    ├── ✓ Debe retornar false si nunca completó onboarding
    ├── ✓ Debe retornar true si ya completó
    └── ✓ Debe guardar estado después de completar
```

**Cobertura mínima Domain:** 100% (es simple)

---

### PASO 2: Presentation

**Tests de widget (opcional para MVP):**

```
test/features/onboarding/presentation/pages/

└── onboarding_page_test.dart
    ├── ✓ Debe mostrar 3 páginas
    ├── ✓ Botón SIGUIENTE avanza a siguiente página
    ├── ✓ Última página muestra EMPEZAR
    └── ✓ Al completar, navega a home
```

**Cobertura mínima:** 60% (opcional)

---

## ORDEN DE IMPLEMENTACIÓN

### PASO 1: Domain Layer (mínimo)

**Objetivo:** Lógica de estado de onboarding

**Artefactos a crear:**
```
lib/features/onboarding/domain/usecases/
├── check_onboarding_status.dart
└── complete_onboarding.dart
```

**CheckOnboardingStatus UseCase:**
- Lee SharedPreferences
- Retorna bool (completado o no)

**CompleteOnboarding UseCase:**
- Guarda en SharedPreferences clave: 'onboarding_completed' = true
- Retorna void

**Workflow:**
1. Tests primero
2. Implementar con SharedPreferences
3. Tests en verde

**Criterio de avance:** Tests Domain en verde

---

### PASO 2: Presentation Layer

**Objetivo:** 3 pantallas simples + navegación

**Artefactos a crear:**
```
lib/features/onboarding/presentation/
├── pages/
│   └── onboarding_page.dart
└── widgets/
    └── onboarding_step.dart
```

**OnboardingPage:**
- PageView con 3 páginas
- PageController para navegación
- Botón SIGUIENTE (índice 0-1)
- Botón EMPEZAR (índice 2)
- Al completar: llama CompleteOnboarding → navega a /home

**OnboardingStep (widget reutilizable):**
- Recibe: título, descripción, imagen (asset)
- Layout vertical centrado
- Imagen 200x200
- Título 24sp bold
- Descripción 18sp
- Padding generoso

**Contenido de pasos (básico):**
1. **Paso 1:**
    - Título: "Escaneá documentos fácilmente"
    - Descripción: "Tocá el botón ESCANEAR y apuntá a tu factura"
    - Imagen: ícono botón scan grande

2. **Paso 2:**
    - Título: "Encontralos con búsqueda"
    - Descripción: "Buscá por nombre o contenido del documento"
    - Imagen: ícono lupa

3. **Paso 3:**
    - Título: "Agregá notas y recordatorios"
    - Descripción: "Anotá detalles importantes en cada documento"
    - Imagen: ícono nota

**Workflow:**
1. Crear OnboardingStep widget
2. Crear OnboardingPage con PageView
3. Integrar CheckOnboardingStatus en main.dart
4. Testing manual

**Criterio de avance:** Tutorial funciona completo

---

## INTEGRACIÓN CON MAIN.DART

**Modificar routing inicial:**

Lógica en main.dart:
1. Al iniciar app, llamar CheckOnboardingStatus
2. Si false → initialRoute = '/onboarding'
3. Si true → initialRoute = '/home'

**Agregar en routes:**
- '/onboarding': OnboardingPage

**Agregar opción "Ver tutorial" en settings (futuro):**
- Botón en configuración
- Navega a /onboarding
- Al completar, vuelve a settings (no home)

---

## ASSETS REQUERIDOS

**Crear carpeta:**
```
assets/onboarding/
├── scan_icon.png      (placeholder simple por ahora)
├── search_icon.png    (placeholder simple por ahora)
└── notes_icon.png     (placeholder simple por ahora)
```

**Nota:** Imágenes placeholder temporales. Refinar después de ajustes UI finales.

---

## LOCALIZACIÓN

**Claves a agregar en es.json / en.json:**

```
Onboarding:
- onboarding_step1_title
- onboarding_step1_desc
- onboarding_step2_title
- onboarding_step2_desc
- onboarding_step3_title
- onboarding_step3_desc
- onboarding_button_next
- onboarding_button_start
```

---

## CRITERIOS DE COMPLETITUD ÉPICA 5

**Checklist antes de declarar MVP completo:**

### Tests
- [ ] Tests Domain pasan (CheckOnboarding, CompleteOnboarding)
- [ ] No hay tests rojos

### Funcionalidad
- [ ] Primera apertura muestra onboarding
- [ ] 3 pantallas visibles
- [ ] Botón SIGUIENTE avanza (200x60dp, texto 20sp)
- [ ] Última pantalla muestra EMPEZAR
- [ ] Al tocar EMPEZAR, guarda estado y va a home
- [ ] Aperturas siguientes van directo a home
- [ ] Texto grande (20sp) y legible
- [ ] Imágenes centradas y claras

### Navegación
- [ ] No se puede saltar onboarding (sin back button)
- [ ] Solo termina si toca EMPEZAR
- [ ] Estado persiste entre cierres de app

### Localización
- [ ] Textos traducidos ES/EN
- [ ] Funciona en ambos idiomas

---

## ENTREGABLES ESPERADOS

```
lib/features/onboarding/
├── domain/
│   └── usecases/
│       ├── check_onboarding_status.dart  ✓ Completo + tests
│       └── complete_onboarding.dart      ✓ Completo + tests
└── presentation/
    ├── pages/
    │   └── onboarding_page.dart          ✓ UI básica funcional
    └── widgets/
        └── onboarding_step.dart          ✓ Completo

test/features/onboarding/
└── domain/
    └── usecases/                         ✓ 2 archivos, ~5 tests

assets/onboarding/
├── scan_icon.png                         ✓ Placeholder
├── search_icon.png                       ✓ Placeholder
└── notes_icon.png                        ✓ Placeholder

Modificaciones:
lib/main.dart                             ✓ Routing condicional
assets/l10n/es.json                       ✓ Claves onboarding
assets/l10n/en.json                       ✓ Claves onboarding
```

---

## NOTAS PARA CLAUDE CODE

1. **SharedPreferences simple** - Solo bool 'onboarding_completed'
2. **PageView básico suficiente** - Sin animaciones fancy
3. **Assets placeholder** - Imágenes simples por ahora
4. **Sin skip** - Usuario debe completar tutorial
5. **Testing manual crítico** - Validar primera experiencia
6. **Refinar después** - Post-ajustes UI agregar screenshots reales

---

## POST-MVP (refinar tutorial)

**Después de ajustes UI finales:**
- Reemplazar placeholders con screenshots reales de app
- Ajustar textos según feedback de validación
- Agregar animaciones sutiles si corresponde
- Mejorar layout según diseño final

---

## REFERENCIAS

- **Historias completas:** `/mnt/project/user_stories_mvp.md` (HU-013)
- **Épicas previas:** Todas las anteriores completadas
- **Package:** shared_preferences ^2.3.2