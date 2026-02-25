 Ahora que cambiamos a TFLite, el resize A4 previo ya NO es tan necesario. Déjame explicar:                                                                                                                      
  🔍 Con Laplacian (antes):                                                                                                                                                                                                        
                                                                                                                                                                                                                                   
  Resize A4 → Clasificar Laplacian                                                                                                                                                                                                     ↓           ↓                                                                                                                                                                                                                  
  ~1458ms    Lee TODOS los píxeles (8.7MP)
             Calcula varianza → ~1s

  VS sin resize:
  Clasificar Laplacian directo (24MP) → 3-5s

  Beneficio claro: 3-5x más rápido clasificar A4 que imagen original.

  ---
  🧠 Con TFLite (ahora):

  Resize A4 → Clasificar TFLite
    ↓           ↓
  ~1458ms    dart:ui decode A4 (8.7MP) → resize a 224×224
             ~92ms + inferencia ~160ms TOTAL

  VS sin resize:
  Clasificar TFLite directo (original 24MP)
     ↓
  dart:ui decode original → resize a 224×224
  ~200-300ms + inferencia ~160ms TOTAL

  Diferencia: Solo ~100-200ms más lento clasificar original vs A4.

  ---
  💡 ¿Qué conviene?

  Opción A (actual):

  Convertir JPG → Resize A4 → Clasificar → Comprimir si doc → Guardar
     ~500ms      ~1458ms      ~160ms        ~2000ms
  - ❌ Resize A4 siempre (aunque sea foto cancelada)
  - ⏱️ TOTAL foto cancelada: ~2100ms

  Opción B (óptima):

  Convertir JPG → Clasificar → Si acepta → Resize A4 + Comprimir → Guardar
     ~500ms      ~300ms      (usuario)    ~1458 + 2000ms
  - ✅ Resize A4 solo si se acepta
  - ✅ Clasificación ~200ms más lenta (no importa)
  - ⏱️ TOTAL foto cancelada: ~800ms (ahorro 1300ms)

  ---
  🎯 Mi recomendación:

  Eliminar resize A4 previo:
  1. TFLite hace su propio resize a 224×224 de todos modos
  2. Ahorra ~1300ms en fotos canceladas
  3. Solo ~200ms más lento clasificar (insignificante)

  Nuevo flujo:
  Scanner/Import → JPG → Clasificar → Modal
                                 ↓
                            ┌────┴────┐
                            ↓         ↓
                        DOCUMENTO   FOTO
                            ↓         ↓
                      Resize A4   Espera usuario
                      Compress        ↓
                      Guardar    Acepta/Cancela
                      OCR            ↓
                                  Resize A4
                                  Compress
                                  Guardar
                                  OCR

  ¿Cuándo hacer resize A4?
  - Documentos: Inmediatamente después de clasificar
  - Fotos: Solo si usuario acepta
  - Nunca: Si foto cancelada (ahorro tiempo)

  ¿Te gusta esta idea? Básicamente movemos resize A4 a después de clasificar, condicionalmente.

✻ Cogitated for 51s

❯ yo hago conversion a jpg y resize| la conversion no lleva tiempo?                                                                                                                                                                                                                                    
● Excelente punto! Sí, la conversión a JPG toma tiempo. Déjame desglosar el flujo real:                                                                                                                                                               
  📊 Flujo ACTUAL (con timings reales):                                                                                                                                                                                            
                                      
  Caso 1: Import PNG 24MP                                                                                                                                                                                                                                                                                                                                                                                                                                             
  1. Convertir PNG → JPG: ~500-1000ms
     └─ flutter_image_compress @ quality 90

  2. Resize JPG A4: ~1458ms
     └─ flutter_image_compress minWidth/Height @ quality 95

  3. Clasificar A4: ~499ms
     └─ dart:ui decode A4 + resize a 224

  TOTAL: ~2.5-3s

  Caso 2: Import/Scanner JPG 24MP

  1. Convertir: 0ms (pass-through, ya es JPG)

  2. Resize JPG A4: ~1458ms

  3. Clasificar A4: ~499ms

  TOTAL: ~2s

  ---
  💡 Si ELIMINAMOS Resize A4 previo:

  Caso 1: Import PNG 24MP

  1. Convertir PNG → JPG: ~500-1000ms

  2. Clasificar JPG original 24MP: ~300-500ms
     └─ dart:ui decode 24MP + resize a 224

  Si acepta:
  3. Resize A4 + Comprimir: ~3.5s

  TOTAL pre-guardado: ~800-1500ms (foto cancelada)
  TOTAL completo: ~4.3-5s (foto/doc aceptado)

  Caso 2: Scanner/Import JPG 24MP

  1. Convertir: 0ms

  2. Clasificar JPG original: ~300-500ms

  Si acepta:
  3. Resize A4 + Comprimir: ~3.5s

  TOTAL pre-guardado: ~300-500ms (foto cancelada)
  TOTAL completo: ~3.8-4s (foto/doc aceptado)

  ---
  🎯 Comparación: ¿Vale la pena?

  ┌──────────────────────┬────────┬──────────────────────┬──────────┐
  │      Escenario       │ Actual │ Sin Resize A4 previo │  Ahorro  │
  ├──────────────────────┼────────┼──────────────────────┼──────────┤
  │ PNG → Foto cancelada │ ~2.5s  │ ~1s                  │ ~1.5s ✅ │
  ├──────────────────────┼────────┼──────────────────────┼──────────┤
  │ JPG → Foto cancelada │ ~2s    │ ~0.5s                │ ~1.5s ✅ │
  ├──────────────────────┼────────┼──────────────────────┼──────────┤
  │ PNG → Doc guardado   │ ~4s    │ ~4.5s                │ -0.5s ⚠️ │
  ├──────────────────────┼────────┼──────────────────────┼──────────┤
  │ JPG → Doc guardado   │ ~3.5s  │ ~4s                  │ -0.5s ⚠️ │
  └──────────────────────┴────────┴──────────────────────┴──────────┘

  ---
  🤔 Mi conclusión:

  Sí conviene eliminar Resize A4 previo:

  ✅ Pros:
  - Foto cancelada: 1.5s más rápido (50% mejora)
  - Feedback más rápido al usuario (clasificación inmediata)
  - Conversión es inevitable (la hacemos igual)

  ⚠️ Cons:
  - Doc/Foto aceptada: 0.5s más lento
  - Pero usuario ya aceptó, no le importa esperar 0.5s más

  Trade-off: Ganar 1.5s en cancelaciones vs perder 0.5s en aceptaciones → Vale la pena porque las cancelaciones son críticas para UX (feedback rápido).

