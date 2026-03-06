● Perfecto, voy a hacer un análisis profundo. Empiezo leyendo el contexto principal y explorando la estructura del proyecto.

● Searched for 1 pattern, read 2 files (ctrl+o to expand)

● Voy a lanzar varios agentes en paralelo para analizar distintas áreas del proyecto.

● 4 Explore agents launched (ctrl+o to expand)                                                                                                                                                                                     
├─ Analyze lib/ structure and code                                                                                                                                                                                              
│  ⎿  Running in the background                                                                                                                                                                                                 
├─ Analyze tests and coverage                                                                                                                                                                                                   
│  ⎿  Running in the background                                                                                                                                                                                                 
├─ Analyze pubspec and dependencies                                                                                                                                                                                             
│  ⎿  Running in the background            
└─ Analyze DB and data layer                                                                                                                                                                                                    
⎿  Running in the background                                                                                                                                                                                                    
● Lancé 4 agentes en paralelo analizando:
1. Estructura y calidad del código en lib/
2. Tests y cobertura
3. Dependencias y configuración de build
4. Capa de datos y DB

Estoy esperando los resultados. Dame un momento mientras terminan el análisis profundo.

✻ Churned for 43s · 4 background tasks still running (↓ to manage)

● Agent "Analyze lib/ structure and code" completed                                                                                                                                                                                   
● Primer agente terminó. Esperando los otros 3...                                                                                                                                                                                                                                        
● Agent "Analyze tests and coverage" completed                                                                                                                                                                                                                                           
● Segundo agente listo. Faltan 2 más...                                                                                                                                                                                                                                             
● Agent "Analyze pubspec and dependencies" completed                                                                                                                                                                                                                                
● Tercer agente listo. Falta el último (capa de datos y DB)...                                                                                                                                                                                                                           
● Agent "Analyze DB and data layer" completed                                                                                                                                                                                                                                                                 
● Los 4 análisis terminaron. Acá va la síntesis consolidada.
  ---                                                                                                                                                                                                                              
Análisis del proyecto EscanDoc

Primero: la arquitectura es sólida. Clean Architecture bien aplicada, TDD en domain al 100%, pipeline de escaneo bien optimizado con tiempos reales medidos. 
Se nota el trabajo iterativo con Logcat. Lo que sigue son
oportunidades de mejora, no problemas graves.
  ---                                                                                                                                                                                                                              
PRIORIDAD ALTA — Antes de producción

1. Bundle ID Android sigue en com.example.escandoc
   En android/app/build.gradle.kts el applicationId es el placeholder. Play Store lo rechaza. Debe ser com.passalia.escandoc (como ya tenés en la config iOS).

2. Signing config usa debug en release                                                                                                                                                                                           
   build.gradle.kts línea 42: signingConfig = signingConfigs.getByName("debug"). El APK de release necesita un keystore propio.

3. PDFs grandes pueden causar OOM                                                                                                                                                                                                
   ImportProvider.importPdfPages() renderiza todas las páginas a JPG en memoria antes de procesarlas. 
En un Moto G52 con un PDF de 50+ páginas, podría crashear. Procesar página por página con cleanup inmediato sería más seguro.

4. Sin timeouts en operaciones pesadas                                                                                                                                                                                           
   OCR (_textRecognizer.processImage), TFLite (_interpreter.run), y el render de PDF no tienen timeout. 
Un archivo corrupto podría colgar la app indefinidamente. Un .timeout(Duration(seconds: 30)) en las operaciones críticas    
   previene eso.

5. Errores silenciados en el repositorio                                                                                                                                                                                         
   DocumentRepository atrapa todas las excepciones y retorna [] o null sin loguear nada:
   catch (e) { return []; }  // ¿DB corrupta o sin docs? No se sabe                                                                                                                                                                   Al menos un debugPrint ayudaría a diagnosticar problemas en producción.
   6. Sin estrategia de migración de DB                                                                                                                                                                                             
   _upgradeDB está vacío con un TODO. La versión está fija en 1. Cuando actives Phase 2 (due_dates), los usuarios existentes no van a poder migrar. Conviene dejar la infraestructura lista ahora.

  ---                                                                                                                                                                                                                              
PRIORIDAD MEDIA — Calidad y mantenibilidad

7. ScanProvider e ImportProvider duplican ~90% del código
   Ambos implementan el mismo pipeline: clasificar → comprimir → guardar → OCR background. En main.dart también se instancian los mismos servicios dos veces (líneas 108-146 vs 148-186). Extraer un DocumentProcessingProvider base   o al menos una factory de servicios compartidos reduciría bastante la duplicación.
8. Tipos de documento comparados como strings en ProcessOCR                                                                                                                                                                      
   if (refinement.refinedClass == 'manuscrito') { ... }
   Esto es frágil. Ya tenés DocumentType como enum — usarlo consistentemente en domain evitaría errores por typos.

9. DateTime.parse() sin try-catch en DocumentModel                                                                                                                                                                               
   Si algún registro en BD tiene una fecha corrupta, la app crashea al cargar documentos. Un DateTime.tryParse() sería más defensivo.

10. Métodos deprecados sin eliminar                                                                                                                                                                                              
    scanAndSave() y importAndSave() están marcados @Deprecated pero siguen existiendo. Si ya no se usan, sacarlos limpia el código.                                                                                                  
    11. Share intent sin error handling
    En home_page.dart, getInitialMedia().then(...) no tiene .catchError(). Si _processSharedFile falla, el error se pierde.

12. Falta de transacciones en operaciones multi-paso                                                                                                                                                                             
    deleteDocument() hace 3 pasos secuenciales (fetch → borrar archivo → borrar de DB) sin transacción. Si el borrado de archivo falla, queda un registro huérfano en la DB apuntando a un archivo inexistente.                      
    ---             
    PRIORIDAD BAJA — Deuda técnica aceptable para MVP

13. Search con 23 REPLACE() anidados
    Funciona bien para pocos documentos, pero escala linealmente. Con 500+ docs en un Moto G52 podría sentirse lento. Si llegás ahí, FTS5 sería el upgrade natural. Por ahora está bien, pero falta un índice en title y             
    note_content.
14. Providers sin tests (0% de cobertura)                                                                                                                                                                                        
    Domain está al 100% — excelente. Pero ScanProvider, ImportProvider, DocumentsProvider y SearchProvider no tienen tests. Son los que orquestan el flujo completo. No bloquea el MVP, pero sería el próximo bloque lógico de tests.
15. Camera/Crop pages son placeholders                                                                                                                                                                                           
    camera_page.dart y crop_page.dart tienen solo un Text('TODO'). Si no se van a usar (porque el scanner nativo maneja eso), conviene eliminarlas para no confundir.                                                                
    16. Parser EXIF manual
    DocumentOrientationServiceImpl parsea JPEG/EXIF byte por byte. Funciona, pero un JPEG malformado podría causar un out-of-bounds. Una librería publicada sería más robusta, aunque para el flujo actual (fotos propias) el riesgo
    es bajo.
17. uuid posiblemente sin usar                                                                                                                                                                                                   
    Está en pubspec.yaml pero no encontré imports directos en lib/. Vale la pena verificar si realmente se usa.
    ---             
    Resumen visual

┌──────────────────────┬────────────┬────────────────────────────────────────┐
│         Área         │   Estado   │                  Nota                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Arquitectura         │ Muy bien   │ Clean Arch + Feature-First correcto    │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                   
│ Domain/UseCases      │ Excelente  │ 100% TDD, bien testeados               │                                                                                                                                                   
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Pipeline escaneo     │ Muy bien   │ Optimizado con mediciones reales       │                                                                                                                                                   
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Seguridad SQL        │ Excelente  │ Todo parametrizado                     │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Error handling       │ Mejorable  │ Errores silenciados en data layer      │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Tests providers      │ Pendiente  │ 0/4 providers testeados                │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Config build Android │ Bloqueante │ Bundle ID + signing                    │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Config iOS           │ Bien       │ Permisos y deployment target correctos │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ DB migrations        │ Pendiente  │ Infraestructura vacía                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤                                                                                                                                                     │ Performance búsqueda │ Aceptable  │ Escala hasta ~500 docs                 │
└──────────────────────┴────────────┴────────────────────────────────────────┘
  ---                                                                                                                                                                                                                              
¿Querés que profundice en algún punto en particular, o que arranquemos a atacar alguno de estos?

✻ Cogitated for 47s               
❯ lo que podemos profundizar es el punto 13_empecé a implementar fts5 y crasheaba todo, luego vi que fts4 si tenia mi celular y lo implementé, pero tuve un monton de problemas y decidimos que por lo que es la app, no era         necesario o un poco overkill usar fts|No lo voy a usar, pero necesito hacer muy eficiente su reemplazo, 13 remplaces anidados es improducente|que optimizaciones crees que podemos hacer sin volver a fts?

● Buena pregunta. Déjame ver exactamente cómo está implementado hoy el search para proponer optimizaciones concretas.

● Read 2 files (ctrl+o to expand)                                                                                                                                                                                                                                                                        
● Ahora veo el cuadro completo. Déjame verificar todos los puntos donde se escriben documentos para tener el plan completo.

Searching for 1 pattern, reading 2 files… (ctrl+o to expand)                                                                                                                                                                     
⎿  lib\features\documents\data\models\document_model.dart

● Ahora tengo el cuadro completo. Hay una optimización clara y potente que no requiere FTS.                                                                                                                                        
---                                                                                                                                                                                                                                Estrategia: columnas shadow pre-normalizadas                                                                                                                                                                                                                                                                                                                                                                                                                        
El problema actual es que cada búsqueda ejecuta 23 REPLACE() anidados por cada fila, en 2 columnas. Con 100 documentos son ~4600 llamadas a REPLACE() por búsqueda. Y eso crece linealmente.

La solución: normalizar al escribir, no al leer.                                                                                                                                                                                                                                                                                                                                                                                                                      Cómo funciona
1. Agregar 2 columnas: title_search y note_search                                                                                                                                                                                  2. Al insertar/actualizar un documento, calcular el texto normalizado en Dart (tu _normalizeText() ya existe) y guardarlo en esas columnas
3. El query de búsqueda pasa de esto:                                                                                                                                                                                            
   ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   ❯                 
   ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   esc to interrupt

▐▛███▜▌   Claude Code v2.1.69
▝▜█████▛▘  Opus 4.6 · Claude Pro
▘▘ ▝▝    ~\Documents\escandoc

↑ Install the PyCharm plugin from the JetBrains Marketplace: https://docs.claude.com/s/claude-code-jetbrains

❯ holaa, hace meses que estoy desarrolando esta app, ya estoy en la etapa de refinamistos y features finales, aunquye falta bastante| me pareció que es momento de que hagas un analisis exasustivo y sin ser absolutos,           
veamos si hay algún punto que se puede mejorar u aoptimizar|.context/46_nuevo_flujo.md encontrarás una sintesis de lo que es la app, y en .context/hay mas de 50 documentos, con los nombres bien orientados, en donde           
puedes recabar información|todas las features fueron tranquilamente estudiadas e iteradas, haciendo pruebas de test, de emulador y luego de tiempops realies y cuallos de botellas mediante logs de Logcat en mi motog 52

● Perfecto, voy a hacer un análisis profundo. Empiezo leyendo el contexto principal y explorando la estructura del proyecto.

● Searched for 1 pattern, read 2 files (ctrl+o to expand)

● Voy a lanzar varios agentes en paralelo para analizar distintas áreas del proyecto.

● 4 Explore agents launched (ctrl+o to expand)
├─ Analyze lib/ structure and code
│  ⎿  Running in the background
├─ Analyze tests and coverage
│  ⎿  Running in the background
├─ Analyze pubspec and dependencies
│  ⎿  Running in the background
└─ Analyze DB and data layer
⎿  Running in the background

● Lancé 4 agentes en paralelo analizando:
1. Estructura y calidad del código en lib/
2. Tests y cobertura
3. Dependencias y configuración de build
4. Capa de datos y DB

Estoy esperando los resultados. Dame un momento mientras terminan el análisis profundo.

✻ Churned for 43s · 4 background tasks still running (↓ to manage)

● Agent "Analyze lib/ structure and code" completed

● Primer agente terminó. Esperando los otros 3...

● Agent "Analyze tests and coverage" completed

● Segundo agente listo. Faltan 2 más...

● Agent "Analyze pubspec and dependencies" completed

● Tercer agente listo. Falta el último (capa de datos y DB)...

● Agent "Analyze DB and data layer" completed

● Los 4 análisis terminaron. Acá va la síntesis consolidada.

  ---
Análisis del proyecto EscanDoc

Primero: la arquitectura es sólida. Clean Architecture bien aplicada, TDD en domain al 100%, pipeline de escaneo bien optimizado con tiempos reales medidos. Se nota el trabajo iterativo con Logcat. Lo que sigue son
oportunidades de mejora, no problemas graves.

  ---
PRIORIDAD ALTA — Antes de producción

1. Bundle ID Android sigue en com.example.escandoc
   En android/app/build.gradle.kts el applicationId es el placeholder. Play Store lo rechaza. Debe ser com.passalia.escandoc (como ya tenés en la config iOS).

2. Signing config usa debug en release
   build.gradle.kts línea 42: signingConfig = signingConfigs.getByName("debug"). El APK de release necesita un keystore propio.

3. PDFs grandes pueden causar OOM
   ImportProvider.importPdfPages() renderiza todas las páginas a JPG en memoria antes de procesarlas. En un Moto G52 con un PDF de 50+ páginas, podría crashear. Procesar página por página con cleanup inmediato sería más seguro.

4. Sin timeouts en operaciones pesadas
   OCR (_textRecognizer.processImage), TFLite (_interpreter.run), y el render de PDF no tienen timeout. Un archivo corrupto podría colgar la app indefinidamente. Un .timeout(Duration(seconds: 30)) en las operaciones críticas    
   previene eso.

5. Errores silenciados en el repositorio
   DocumentRepository atrapa todas las excepciones y retorna [] o null sin loguear nada:
   catch (e) { return []; }  // ¿DB corrupta o sin docs? No se sabe
   Al menos un debugPrint ayudaría a diagnosticar problemas en producción.

6. Sin estrategia de migración de DB
   _upgradeDB está vacío con un TODO. La versión está fija en 1. Cuando actives Phase 2 (due_dates), los usuarios existentes no van a poder migrar. Conviene dejar la infraestructura lista ahora.

  ---
PRIORIDAD MEDIA — Calidad y mantenibilidad

7. ScanProvider e ImportProvider duplican ~90% del código
   Ambos implementan el mismo pipeline: clasificar → comprimir → guardar → OCR background. En main.dart también se instancian los mismos servicios dos veces (líneas 108-146 vs 148-186). Extraer un DocumentProcessingProvider base
   o al menos una factory de servicios compartidos reduciría bastante la duplicación.

8. Tipos de documento comparados como strings en ProcessOCR
   if (refinement.refinedClass == 'manuscrito') { ... }
   Esto es frágil. Ya tenés DocumentType como enum — usarlo consistentemente en domain evitaría errores por typos.

9. DateTime.parse() sin try-catch en DocumentModel
   Si algún registro en BD tiene una fecha corrupta, la app crashea al cargar documentos. Un DateTime.tryParse() sería más defensivo.

10. Métodos deprecados sin eliminar
    scanAndSave() y importAndSave() están marcados @Deprecated pero siguen existiendo. Si ya no se usan, sacarlos limpia el código.

11. Share intent sin error handling
    En home_page.dart, getInitialMedia().then(...) no tiene .catchError(). Si _processSharedFile falla, el error se pierde.

12. Falta de transacciones en operaciones multi-paso
    deleteDocument() hace 3 pasos secuenciales (fetch → borrar archivo → borrar de DB) sin transacción. Si el borrado de archivo falla, queda un registro huérfano en la DB apuntando a un archivo inexistente.

  ---
PRIORIDAD BAJA — Deuda técnica aceptable para MVP

13. Search con 23 REPLACE() anidados
    Funciona bien para pocos documentos, pero escala linealmente. Con 500+ docs en un Moto G52 podría sentirse lento. Si llegás ahí, FTS5 sería el upgrade natural. Por ahora está bien, pero falta un índice en title y
    note_content.

14. Providers sin tests (0% de cobertura)
    Domain está al 100% — excelente. Pero ScanProvider, ImportProvider, DocumentsProvider y SearchProvider no tienen tests. Son los que orquestan el flujo completo. No bloquea el MVP, pero sería el próximo bloque lógico de tests.

15. Camera/Crop pages son placeholders
    camera_page.dart y crop_page.dart tienen solo un Text('TODO'). Si no se van a usar (porque el scanner nativo maneja eso), conviene eliminarlas para no confundir.

16. Parser EXIF manual
    DocumentOrientationServiceImpl parsea JPEG/EXIF byte por byte. Funciona, pero un JPEG malformado podría causar un out-of-bounds. Una librería publicada sería más robusta, aunque para el flujo actual (fotos propias) el riesgo
    es bajo.

17. uuid posiblemente sin usar
    Está en pubspec.yaml pero no encontré imports directos en lib/. Vale la pena verificar si realmente se usa.

  ---
Resumen visual

┌──────────────────────┬────────────┬────────────────────────────────────────┐
│         Área         │   Estado   │                  Nota                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Arquitectura         │ Muy bien   │ Clean Arch + Feature-First correcto    │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Domain/UseCases      │ Excelente  │ 100% TDD, bien testeados               │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Pipeline escaneo     │ Muy bien   │ Optimizado con mediciones reales       │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Seguridad SQL        │ Excelente  │ Todo parametrizado                     │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Error handling       │ Mejorable  │ Errores silenciados en data layer      │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Tests providers      │ Pendiente  │ 0/4 providers testeados                │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Config build Android │ Bloqueante │ Bundle ID + signing                    │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Config iOS           │ Bien       │ Permisos y deployment target correctos │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ DB migrations        │ Pendiente  │ Infraestructura vacía                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Performance búsqueda │ Aceptable  │ Escala hasta ~500 docs                 │
└──────────────────────┴────────────┴────────────────────────────────────────┘

  ---
¿Querés que profundice en algún punto en particular, o que arranquemos a atacar alguno de estos?

✻ Cogitated for 47s

❯ lo que podemos profundizar es el punto 13_empecé a implementar fts5 y crasheaba todo, luego vi que fts4 si tenia mi celular y lo implementé, pero tuve un monton de problemas y decidimos que por lo que es la app, no era       
necesario o un poco overkill usar fts|No lo voy a usar, pero necesito hacer muy eficiente su reemplazo, 13 remplaces anidados es improducente|que optimizaciones crees que podemos hacer sin volver a fts?

● Buena pregunta. Déjame ver exactamente cómo está implementado hoy el search para proponer optimizaciones concretas.

● Read 2 files (ctrl+o to expand)

● Ahora veo el cuadro completo. Déjame verificar todos los puntos donde se escriben documentos para tener el plan completo.

● Searching for 1 pattern, reading 2 files… (ctrl+o to expand)
⎿  lib\features\documents\data\models\document_model.dart

● Ahora tengo el cuadro completo. Hay una optimización clara y potente que no requiere FTS.

  ---
Estrategia: columnas shadow pre-normalizadas

El problema actual es que cada búsqueda ejecuta 23 REPLACE() anidados por cada fila, en 2 columnas. Con 100 documentos son ~4600 llamadas a REPLACE() por búsqueda. Y eso crece linealmente.

La solución: normalizar al escribir, no al leer.

Cómo funciona

1. Agregar 2 columnas: title_search y note_search
2. Al insertar/actualizar un documento, calcular el texto normalizado en Dart (tu _normalizeText() ya existe) y guardarlo en esas columnas
3. El query de búsqueda pasa de esto:

-- HOY: 46 REPLACE() por fila
───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────❯                                                                                                                                                                                                                                  ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
esc to interrupt

▐▛███▜▌   Claude Code v2.1.69
▝▜█████▛▘  Opus 4.6 · Claude Pro
▘▘ ▝▝    ~\Documents\escandoc

↑ Install the PyCharm plugin from the JetBrains Marketplace: https://docs.claude.com/s/claude-code-jetbrains

❯ holaa, hace meses que estoy desarrolando esta app, ya estoy en la etapa de refinamistos y features finales, aunquye falta bastante| me pareció que es momento de que hagas un analisis exasustivo y sin ser absolutos,           
veamos si hay algún punto que se puede mejorar u aoptimizar|.context/46_nuevo_flujo.md encontrarás una sintesis de lo que es la app, y en .context/hay mas de 50 documentos, con los nombres bien orientados, en donde           
puedes recabar información|todas las features fueron tranquilamente estudiadas e iteradas, haciendo pruebas de test, de emulador y luego de tiempops realies y cuallos de botellas mediante logs de Logcat en mi motog 52

● Perfecto, voy a hacer un análisis profundo. Empiezo leyendo el contexto principal y explorando la estructura del proyecto.

● Searched for 1 pattern, read 2 files (ctrl+o to expand)

● Voy a lanzar varios agentes en paralelo para analizar distintas áreas del proyecto.

● 4 Explore agents launched (ctrl+o to expand)
├─ Analyze lib/ structure and code
│  ⎿  Running in the background
├─ Analyze tests and coverage
│  ⎿  Running in the background
├─ Analyze pubspec and dependencies
│  ⎿  Running in the background
└─ Analyze DB and data layer
⎿  Running in the background

● Lancé 4 agentes en paralelo analizando:
1. Estructura y calidad del código en lib/
2. Tests y cobertura
3. Dependencias y configuración de build
4. Capa de datos y DB

Estoy esperando los resultados. Dame un momento mientras terminan el análisis profundo.

✻ Churned for 43s · 4 background tasks still running (↓ to manage)

● Agent "Analyze lib/ structure and code" completed

● Primer agente terminó. Esperando los otros 3...

● Agent "Analyze tests and coverage" completed

● Segundo agente listo. Faltan 2 más...

● Agent "Analyze pubspec and dependencies" completed

● Tercer agente listo. Falta el último (capa de datos y DB)...

● Agent "Analyze DB and data layer" completed

● Los 4 análisis terminaron. Acá va la síntesis consolidada.

  ---
Análisis del proyecto EscanDoc

Primero: la arquitectura es sólida. Clean Architecture bien aplicada, TDD en domain al 100%, pipeline de escaneo bien optimizado con tiempos reales medidos. Se nota el trabajo iterativo con Logcat. Lo que sigue son
oportunidades de mejora, no problemas graves.

  ---
PRIORIDAD ALTA — Antes de producción

1. Bundle ID Android sigue en com.example.escandoc
   En android/app/build.gradle.kts el applicationId es el placeholder. Play Store lo rechaza. Debe ser com.passalia.escandoc (como ya tenés en la config iOS).

2. Signing config usa debug en release
   build.gradle.kts línea 42: signingConfig = signingConfigs.getByName("debug"). El APK de release necesita un keystore propio.

3. PDFs grandes pueden causar OOM
   ImportProvider.importPdfPages() renderiza todas las páginas a JPG en memoria antes de procesarlas. En un Moto G52 con un PDF de 50+ páginas, podría crashear. Procesar página por página con cleanup inmediato sería más seguro.

4. Sin timeouts en operaciones pesadas
   OCR (_textRecognizer.processImage), TFLite (_interpreter.run), y el render de PDF no tienen timeout. Un archivo corrupto podría colgar la app indefinidamente. Un .timeout(Duration(seconds: 30)) en las operaciones críticas    
   previene eso.

5. Errores silenciados en el repositorio
   DocumentRepository atrapa todas las excepciones y retorna [] o null sin loguear nada:
   catch (e) { return []; }  // ¿DB corrupta o sin docs? No se sabe
   Al menos un debugPrint ayudaría a diagnosticar problemas en producción.

6. Sin estrategia de migración de DB
   _upgradeDB está vacío con un TODO. La versión está fija en 1. Cuando actives Phase 2 (due_dates), los usuarios existentes no van a poder migrar. Conviene dejar la infraestructura lista ahora.

  ---
PRIORIDAD MEDIA — Calidad y mantenibilidad

7. ScanProvider e ImportProvider duplican ~90% del código
   Ambos implementan el mismo pipeline: clasificar → comprimir → guardar → OCR background. En main.dart también se instancian los mismos servicios dos veces (líneas 108-146 vs 148-186). Extraer un DocumentProcessingProvider base
   o al menos una factory de servicios compartidos reduciría bastante la duplicación.

8. Tipos de documento comparados como strings en ProcessOCR
   if (refinement.refinedClass == 'manuscrito') { ... }
   Esto es frágil. Ya tenés DocumentType como enum — usarlo consistentemente en domain evitaría errores por typos.

9. DateTime.parse() sin try-catch en DocumentModel
   Si algún registro en BD tiene una fecha corrupta, la app crashea al cargar documentos. Un DateTime.tryParse() sería más defensivo.

10. Métodos deprecados sin eliminar
    scanAndSave() y importAndSave() están marcados @Deprecated pero siguen existiendo. Si ya no se usan, sacarlos limpia el código.

11. Share intent sin error handling
    En home_page.dart, getInitialMedia().then(...) no tiene .catchError(). Si _processSharedFile falla, el error se pierde.

12. Falta de transacciones en operaciones multi-paso
    deleteDocument() hace 3 pasos secuenciales (fetch → borrar archivo → borrar de DB) sin transacción. Si el borrado de archivo falla, queda un registro huérfano en la DB apuntando a un archivo inexistente.

  ---
PRIORIDAD BAJA — Deuda técnica aceptable para MVP

13. Search con 23 REPLACE() anidados
    Funciona bien para pocos documentos, pero escala linealmente. Con 500+ docs en un Moto G52 podría sentirse lento. Si llegás ahí, FTS5 sería el upgrade natural. Por ahora está bien, pero falta un índice en title y
    note_content.

14. Providers sin tests (0% de cobertura)
    Domain está al 100% — excelente. Pero ScanProvider, ImportProvider, DocumentsProvider y SearchProvider no tienen tests. Son los que orquestan el flujo completo. No bloquea el MVP, pero sería el próximo bloque lógico de tests.

15. Camera/Crop pages son placeholders
    camera_page.dart y crop_page.dart tienen solo un Text('TODO'). Si no se van a usar (porque el scanner nativo maneja eso), conviene eliminarlas para no confundir.

16. Parser EXIF manual
    DocumentOrientationServiceImpl parsea JPEG/EXIF byte por byte. Funciona, pero un JPEG malformado podría causar un out-of-bounds. Una librería publicada sería más robusta, aunque para el flujo actual (fotos propias) el riesgo
    es bajo.

17. uuid posiblemente sin usar
    Está en pubspec.yaml pero no encontré imports directos en lib/. Vale la pena verificar si realmente se usa.

  ---
Resumen visual

┌──────────────────────┬────────────┬────────────────────────────────────────┐
│         Área         │   Estado   │                  Nota                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Arquitectura         │ Muy bien   │ Clean Arch + Feature-First correcto    │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Domain/UseCases      │ Excelente  │ 100% TDD, bien testeados               │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Pipeline escaneo     │ Muy bien   │ Optimizado con mediciones reales       │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Seguridad SQL        │ Excelente  │ Todo parametrizado                     │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Error handling       │ Mejorable  │ Errores silenciados en data layer      │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Tests providers      │ Pendiente  │ 0/4 providers testeados                │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Config build Android │ Bloqueante │ Bundle ID + signing                    │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Config iOS           │ Bien       │ Permisos y deployment target correctos │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ DB migrations        │ Pendiente  │ Infraestructura vacía                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Performance búsqueda │ Aceptable  │ Escala hasta ~500 docs                 │
└──────────────────────┴────────────┴────────────────────────────────────────┘

  ---
¿Querés que profundice en algún punto en particular, o que arranquemos a atacar alguno de estos?

✻ Cogitated for 47s

❯ lo que podemos profundizar es el punto 13_empecé a implementar fts5 y crasheaba todo, luego vi que fts4 si tenia mi celular y lo implementé, pero tuve un monton de problemas y decidimos que por lo que es la app, no era       
necesario o un poco overkill usar fts|No lo voy a usar, pero necesito hacer muy eficiente su reemplazo, 13 remplaces anidados es improducente|que optimizaciones crees que podemos hacer sin volver a fts?

● Buena pregunta. Déjame ver exactamente cómo está implementado hoy el search para proponer optimizaciones concretas.

● Read 2 files (ctrl+o to expand)

● Ahora veo el cuadro completo. Déjame verificar todos los puntos donde se escriben documentos para tener el plan completo.

Searching for 1 pattern, reading 2 files… (ctrl+o to expand)
⎿  lib\features\documents\data\models\document_model.dart

● Ahora tengo el cuadro completo. Hay una optimización clara y potente que no requiere FTS.

  ---
Estrategia: columnas shadow pre-normalizadas

El problema actual es que cada búsqueda ejecuta 23 REPLACE() anidados por cada fila, en 2 columnas. Con 100 documentos son ~4600 llamadas a REPLACE() por búsqueda. Y eso crece linealmente.

La solución: normalizar al escribir, no al leer.

Cómo funciona

1. Agregar 2 columnas: title_search y note_search
2. Al insertar/actualizar un documento, calcular el texto normalizado en Dart (tu _normalizeText() ya existe) y guardarlo en esas columnas
3. El query de búsqueda pasa de esto:

-- HOY: 46 REPLACE() por fila
WHERE REPLACE(REPLACE(REPLACE(...LOWER(d.title)...)...) LIKE ?
OR REPLACE(REPLACE(REPLACE(...LOWER(d.note_content)...)...) LIKE ?                                                                                                                                                            
A esto:

-- PROPUESTO: cero funciones por fila
WHERE title_search LIKE ? OR note_search LIKE ?

Impacto esperado                                                                                                                                                                                                                                                                                                                                                                                                                                                    
┌────────────────────────┬──────────────────┬───────────────────────────────┐                                                                                                                                                      │        Métrica         │ Hoy (23 REPLACE) │      Propuesto (shadow)       │
├────────────────────────┼──────────────────┼───────────────────────────────┤                                                                                                                                                    
│ Funciones SQL por fila │ 46               │ 0                             │
├────────────────────────┼──────────────────┼───────────────────────────────┤
│ Costo de escritura     │ 0                │ ~despreciable (Dart)          │
├────────────────────────┼──────────────────┼───────────────────────────────┤                                                                                                                                                      │ Complejidad del query  │ Enorme           │ Trivial                       │
├────────────────────────┼──────────────────┼───────────────────────────────┤                                                                                                                                                      │ Storage extra          │ 0                │ ~duplica title + note_content │
└────────────────────────┴──────────────────┴───────────────────────────────┘                                                                                                                                                                      
El tradeoff es mínimo: un poco más de espacio en disco (textos cortos duplicados) a cambio de búsquedas dramáticamente más rápidas.                                                                                                                
Puntos de escritura a cubrir (ya los identifiqué)                                                                                                                                                                                                  
Son solo 4 lugares donde se escribe a documents:
1. DocumentRepository.insertDocument() — inserción inicial                                                                                                                                                                         2. DocumentRepository.updateDocument() — actualización general
3. DocumentRepository.updateNote() — actualiza solo note_content
4. DocumentRepository.createNoteDocument() — usa insertDocument() internamente, se cubre solo

La normalización se hace en Dart con la misma función _normalizeText() que ya tenés en SearchRepositoryImpl, solo hay que moverla a un lugar compartido (un helper en core/ o directamente en DocumentRepository).                                                                                                                                                                                                                                                  
Nota sobre LIKE '%term%' e índices                                                                                                                                                                                                                 
Un LIKE '%term%' con wildcard al inicio no usa índices B-tree — eso es una limitación de SQLite sin FTS. Pero el cuello de botella actual no es la falta de índice, sino los 46 REPLACE() por fila. Eliminar eso es el 95% de la   ganancia. Para tu volumen esperado de documentos (decenas a cientos, no miles), un simple scan con LIKE sobre texto plano va a ser instantáneo.
                                                                                                                                                                                                                                   
---             
¿Querés que arranquemos con la implementación? El plan sería:
1. Test para la función de normalización compartida
2. Migration para agregar las columnas + poblarlas con datos existentes
3. DocumentRepository — calcular las shadow columns en insert/update
4. SearchRepositoryImpl — simplificar el query                                                                                                                                                                                   
   ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────❯                                                                                                                                                                                                                                  ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   esc to interrupt

▐▛███▜▌   Claude Code v2.1.69
▝▜█████▛▘  Opus 4.6 · Claude Pro
▘▘ ▝▝    ~\Documents\escandoc

↑ Install the PyCharm plugin from the JetBrains Marketplace: https://docs.claude.com/s/claude-code-jetbrains

❯ holaa, hace meses que estoy desarrolando esta app, ya estoy en la etapa de refinamistos y features finales, aunquye falta bastante| me pareció que es momento de que hagas un analisis exasustivo y sin ser absolutos,           
veamos si hay algún punto que se puede mejorar u aoptimizar|.context/46_nuevo_flujo.md encontrarás una sintesis de lo que es la app, y en .context/hay mas de 50 documentos, con los nombres bien orientados, en donde           
puedes recabar información|todas las features fueron tranquilamente estudiadas e iteradas, haciendo pruebas de test, de emulador y luego de tiempops realies y cuallos de botellas mediante logs de Logcat en mi motog 52

● Perfecto, voy a hacer un análisis profundo. Empiezo leyendo el contexto principal y explorando la estructura del proyecto.

● Searched for 1 pattern, read 2 files (ctrl+o to expand)

● Voy a lanzar varios agentes en paralelo para analizar distintas áreas del proyecto.

● 4 Explore agents launched (ctrl+o to expand)
├─ Analyze lib/ structure and code
│  ⎿  Running in the background
├─ Analyze tests and coverage
│  ⎿  Running in the background
├─ Analyze pubspec and dependencies
│  ⎿  Running in the background
└─ Analyze DB and data layer
⎿  Running in the background

● Lancé 4 agentes en paralelo analizando:
1. Estructura y calidad del código en lib/
2. Tests y cobertura
3. Dependencias y configuración de build
4. Capa de datos y DB

Estoy esperando los resultados. Dame un momento mientras terminan el análisis profundo.

✻ Churned for 43s · 4 background tasks still running (↓ to manage)

● Agent "Analyze lib/ structure and code" completed

● Primer agente terminó. Esperando los otros 3...

● Agent "Analyze tests and coverage" completed

● Segundo agente listo. Faltan 2 más...

● Agent "Analyze pubspec and dependencies" completed

● Tercer agente listo. Falta el último (capa de datos y DB)...

● Agent "Analyze DB and data layer" completed

● Los 4 análisis terminaron. Acá va la síntesis consolidada.

  ---
Análisis del proyecto EscanDoc

Primero: la arquitectura es sólida. Clean Architecture bien aplicada, TDD en domain al 100%, pipeline de escaneo bien optimizado con tiempos reales medidos. Se nota el trabajo iterativo con Logcat. Lo que sigue son
oportunidades de mejora, no problemas graves.

  ---
PRIORIDAD ALTA — Antes de producción

1. Bundle ID Android sigue en com.example.escandoc
   En android/app/build.gradle.kts el applicationId es el placeholder. Play Store lo rechaza. Debe ser com.passalia.escandoc (como ya tenés en la config iOS).

2. Signing config usa debug en release
   build.gradle.kts línea 42: signingConfig = signingConfigs.getByName("debug"). El APK de release necesita un keystore propio.

3. PDFs grandes pueden causar OOM
   ImportProvider.importPdfPages() renderiza todas las páginas a JPG en memoria antes de procesarlas. En un Moto G52 con un PDF de 50+ páginas, podría crashear. Procesar página por página con cleanup inmediato sería más seguro.

4. Sin timeouts en operaciones pesadas
   OCR (_textRecognizer.processImage), TFLite (_interpreter.run), y el render de PDF no tienen timeout. Un archivo corrupto podría colgar la app indefinidamente. Un .timeout(Duration(seconds: 30)) en las operaciones críticas    
   previene eso.

5. Errores silenciados en el repositorio
   DocumentRepository atrapa todas las excepciones y retorna [] o null sin loguear nada:
   catch (e) { return []; }  // ¿DB corrupta o sin docs? No se sabe
   Al menos un debugPrint ayudaría a diagnosticar problemas en producción.

6. Sin estrategia de migración de DB
   _upgradeDB está vacío con un TODO. La versión está fija en 1. Cuando actives Phase 2 (due_dates), los usuarios existentes no van a poder migrar. Conviene dejar la infraestructura lista ahora.

  ---
PRIORIDAD MEDIA — Calidad y mantenibilidad

7. ScanProvider e ImportProvider duplican ~90% del código
   Ambos implementan el mismo pipeline: clasificar → comprimir → guardar → OCR background. En main.dart también se instancian los mismos servicios dos veces (líneas 108-146 vs 148-186). Extraer un DocumentProcessingProvider base
   o al menos una factory de servicios compartidos reduciría bastante la duplicación.

8. Tipos de documento comparados como strings en ProcessOCR
   if (refinement.refinedClass == 'manuscrito') { ... }
   Esto es frágil. Ya tenés DocumentType como enum — usarlo consistentemente en domain evitaría errores por typos.

9. DateTime.parse() sin try-catch en DocumentModel
   Si algún registro en BD tiene una fecha corrupta, la app crashea al cargar documentos. Un DateTime.tryParse() sería más defensivo.

10. Métodos deprecados sin eliminar
    scanAndSave() y importAndSave() están marcados @Deprecated pero siguen existiendo. Si ya no se usan, sacarlos limpia el código.

11. Share intent sin error handling
    En home_page.dart, getInitialMedia().then(...) no tiene .catchError(). Si _processSharedFile falla, el error se pierde.

12. Falta de transacciones en operaciones multi-paso
    deleteDocument() hace 3 pasos secuenciales (fetch → borrar archivo → borrar de DB) sin transacción. Si el borrado de archivo falla, queda un registro huérfano en la DB apuntando a un archivo inexistente.

  ---
PRIORIDAD BAJA — Deuda técnica aceptable para MVP

13. Search con 23 REPLACE() anidados
    Funciona bien para pocos documentos, pero escala linealmente. Con 500+ docs en un Moto G52 podría sentirse lento. Si llegás ahí, FTS5 sería el upgrade natural. Por ahora está bien, pero falta un índice en title y
    note_content.

14. Providers sin tests (0% de cobertura)
    Domain está al 100% — excelente. Pero ScanProvider, ImportProvider, DocumentsProvider y SearchProvider no tienen tests. Son los que orquestan el flujo completo. No bloquea el MVP, pero sería el próximo bloque lógico de tests.

15. Camera/Crop pages son placeholders
    camera_page.dart y crop_page.dart tienen solo un Text('TODO'). Si no se van a usar (porque el scanner nativo maneja eso), conviene eliminarlas para no confundir.

16. Parser EXIF manual
    DocumentOrientationServiceImpl parsea JPEG/EXIF byte por byte. Funciona, pero un JPEG malformado podría causar un out-of-bounds. Una librería publicada sería más robusta, aunque para el flujo actual (fotos propias) el riesgo
    es bajo.

17. uuid posiblemente sin usar
    Está en pubspec.yaml pero no encontré imports directos en lib/. Vale la pena verificar si realmente se usa.

  ---
Resumen visual

┌──────────────────────┬────────────┬────────────────────────────────────────┐
│         Área         │   Estado   │                  Nota                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Arquitectura         │ Muy bien   │ Clean Arch + Feature-First correcto    │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Domain/UseCases      │ Excelente  │ 100% TDD, bien testeados               │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Pipeline escaneo     │ Muy bien   │ Optimizado con mediciones reales       │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Seguridad SQL        │ Excelente  │ Todo parametrizado                     │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Error handling       │ Mejorable  │ Errores silenciados en data layer      │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Tests providers      │ Pendiente  │ 0/4 providers testeados                │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Config build Android │ Bloqueante │ Bundle ID + signing                    │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Config iOS           │ Bien       │ Permisos y deployment target correctos │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ DB migrations        │ Pendiente  │ Infraestructura vacía                  │
├──────────────────────┼────────────┼────────────────────────────────────────┤
│ Performance búsqueda │ Aceptable  │ Escala hasta ~500 docs                 │
└──────────────────────┴────────────┴────────────────────────────────────────┘

  ---
¿Querés que profundice en algún punto en particular, o que arranquemos a atacar alguno de estos?

✻ Cogitated for 47s

❯ lo que podemos profundizar es el punto 13_empecé a implementar fts5 y crasheaba todo, luego vi que fts4 si tenia mi celular y lo implementé, pero tuve un monton de problemas y decidimos que por lo que es la app, no era       
necesario o un poco overkill usar fts|No lo voy a usar, pero necesito hacer muy eficiente su reemplazo, 13 remplaces anidados es improducente|que optimizaciones crees que podemos hacer sin volver a fts?

● Buena pregunta. Déjame ver exactamente cómo está implementado hoy el search para proponer optimizaciones concretas.

● Read 2 files (ctrl+o to expand)

● Ahora veo el cuadro completo. Déjame verificar todos los puntos donde se escriben documentos para tener el plan completo.

● Searched for 1 pattern, read 2 files (ctrl+o to expand)

● Ahora tengo el cuadro completo. Hay una optimización clara y potente que no requiere FTS.

  ---
Estrategia: columnas shadow pre-normalizadas

El problema actual es que cada búsqueda ejecuta 23 REPLACE() anidados por cada fila, en 2 columnas. Con 100 documentos son ~4600 llamadas a REPLACE() por búsqueda. Y eso crece linealmente.

La solución: normalizar al escribir, no al leer.

Cómo funciona

1. Agregar 2 columnas: title_search y note_search
2. Al insertar/actualizar un documento, calcular el texto normalizado en Dart (tu _normalizeText() ya existe) y guardarlo en esas columnas
3. El query de búsqueda pasa de esto:

-- HOY: 46 REPLACE() por fila
WHERE REPLACE(REPLACE(REPLACE(...LOWER(d.title)...)...) LIKE ?
OR REPLACE(REPLACE(REPLACE(...LOWER(d.note_content)...)...) LIKE ?

A esto:

-- PROPUESTO: cero funciones por fila
WHERE title_search LIKE ? OR note_search LIKE ?

Impacto esperado

┌────────────────────────┬──────────────────┬───────────────────────────────┐
│        Métrica         │ Hoy (23 REPLACE) │      Propuesto (shadow)       │
├────────────────────────┼──────────────────┼───────────────────────────────┤
│ Funciones SQL por fila │ 46               │ 0                             │
├────────────────────────┼──────────────────┼───────────────────────────────┤
│ Costo de escritura     │ 0                │ ~despreciable (Dart)          │
├────────────────────────┼──────────────────┼───────────────────────────────┤
│ Complejidad del query  │ Enorme           │ Trivial                       │
├────────────────────────┼──────────────────┼───────────────────────────────┤
│ Storage extra          │ 0                │ ~duplica title + note_content │
└────────────────────────┴──────────────────┴───────────────────────────────┘

El tradeoff es mínimo: un poco más de espacio en disco (textos cortos duplicados) a cambio de búsquedas dramáticamente más rápidas.

Puntos de escritura a cubrir (ya los identifiqué)

Son solo 4 lugares donde se escribe a documents:

1. DocumentRepository.insertDocument() — inserción inicial
2. DocumentRepository.updateDocument() — actualización general
3. DocumentRepository.updateNote() — actualiza solo note_content
4. DocumentRepository.createNoteDocument() — usa insertDocument() internamente, se cubre solo

La normalización se hace en Dart con la misma función _normalizeText() que ya tenés en SearchRepositoryImpl, solo hay que moverla a un lugar compartido (un helper en core/ o directamente en DocumentRepository).

Nota sobre LIKE '%term%' e índices

Un LIKE '%term%' con wildcard al inicio no usa índices B-tree — eso es una limitación de SQLite sin FTS. Pero el cuello de botella actual no es la falta de índice, sino los 46 REPLACE() por fila. Eliminar eso es el 95% de la
ganancia. Para tu volumen esperado de documentos (decenas a cientos, no miles), un simple scan con LIKE sobre texto plano va a ser instantáneo.

  ---
¿Querés que arranquemos con la implementación? El plan sería:

1. Test para la función de normalización compartida
2. Migration para agregar las columnas + poblarlas con datos existentes
3. DocumentRepository — calcular las shadow columns en insert/update
4. SearchRepositoryImpl — simplificar el query
5. Que corras los tests

● El punto 7 era la duplicación entre ScanProvider e ImportProvider (~90% código compartido). Déjame releer ambos para darte una propuesta precisa.

Reading 2 files… (ctrl+o to expand)
⎿  lib\features\documents\presentation\providers\import_provider.dart

● Ahora puedo ver el cuadro exacto. La duplicación es real y significativa, pero las diferencias también son concretas. Acá va el análisis.

  ---
Diagnóstico: qué se duplica y qué no

Idéntico (~130 líneas duplicadas)

┌─────────────────────────────────────────────────────────────────┬───────────────────────────────┬───────────────────────────────────────────────────┐
│                             Lógica                              │         ScanProvider          │                  ImportProvider                   │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ PreparationResult class                                         │ ScanPreparationResult         │ ImportPreparationResult — mismos 4 campos exactos │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ Pipeline prepare: convert → classify → normalize/thumbnail      │ prepareScan() líneas 128-174  │ prepareImport() líneas 127-177                    │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ Pipeline complete: normalize si foto → save → OCR               │ completeScan() líneas 224-267 │ completeImport() líneas 230-277                   │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ OCR background                                                  │ _processOCRInBackground()     │ _processOCRInBackground()                         │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤                                                                            │ State: _isSaving, _isProcessingOCR, _error, _lastClassification │ sí                            │ sí                                                │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤                                                                          
│ clearError()                                                    │ sí                            │ sí                                                │
└─────────────────────────────────────────────────────────────────┴───────────────────────────────┴───────────────────────────────────────────────────┘                                                                             
Diferente (lo que hace a cada provider único)                                                                                                                                                                                                      
┌────────────────────────────┬───────────────────────────────────────┬────────────────────────────────────────────────┐
│                            │             ScanProvider              │                 ImportProvider                 │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ Origen del archivo         │ _scanDocument.call() (scanner nativo) │ recibe File por parámetro                      │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ _statusMessage             │ no tiene                              │ sí, actualiza en cada paso                     │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ PDF multi-página           │ no                                    │ importPdfPages(), checkPdfPageCount()          │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ Tracking OCR               │ booleano simple                       │ _processingOcrIds (Set, múltiples simultáneos) │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ onOcrComplete callback     │ no                                    │ sí                                             │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ onStatus callback al OCR   │ no                                    │ sí                                             │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ _isScanning / _isImporting │ _isScanning                           │ _isImporting                                   │
└────────────────────────────┴───────────────────────────────────────┴────────────────────────────────────────────────┘

  ---
Propuesta: composición con DocumentPipeline

Ni herencia ni mixin. Composición: extraer la lógica compartida a una clase pura (no es un provider, no extiende ChangeNotifier) que ambos providers usan internamente.

┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│ ScanProvider │────▶│ DocumentPipeline  │◀────│ImportProvider│
│              │     │  (lógica pura)    │     │              │
│ + scanner    │     │                   │     │ + PDF import │
│ + isScanning │     │ prepare(file)     │     │ + statusMsg  │
│              │     │ complete(prep)    │     │ + ocrIds     │
│              │     │ processOCR(id)    │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘

DocumentPipeline contendría:

class DocumentPipeline {
final ImportDocument _importDocument;
final ImageClassifier _imageClassifier;
final SaveScannedDocument _saveDocument;
final ProcessOCR _processOCR;
final ThumbnailGenerator _thumbnailGenerator;

    // 1. Preparar: convert → classify → normalize/thumbnail
    Future<PreparationResult> prepare(File file);

    // 2. Completar: normalize si foto → save → retorna documento
    Future<DocumentModel> complete(PreparationResult prep, String locale);

    // 3. OCR background
    Future<void> processOCR(int docId, String tfliteClass, String locale);
}

PreparationResult unificado:

Una sola clase reemplaza ScanPreparationResult e ImportPreparationResult (son idénticas hoy).

Cada provider mantiene su personalidad:

ScanProvider queda liviano:
Future<PreparationResult?> prepareScan() async {
_isScanning = true; notifyListeners();
final file = await _scanDocument.call();  // lo único propio
if (file == null) { ... return null; }
final result = await _pipeline.prepare(file);  // delegado
_isScanning = false; notifyListeners();
return result;
}

ImportProvider mantiene sus extras:
Future<PreparationResult?> prepareImport(File file) async {
_isImporting = true;
_statusMessage = 'status_preparing';  // lo propio
notifyListeners();
final result = await _pipeline.prepare(file);  // delegado
_statusMessage = null;
_isImporting = false;
notifyListeners();
return result;
}

Y importPdfPages(), checkPdfPageCount(), _processingOcrIds se quedan exclusivamente en ImportProvider.

  ---
Ventajas de esta propuesta

1. Elimina ~130 líneas duplicadas sin forzar herencia artificial
2. DocumentPipeline es testeable aislado — lógica pura, sin ChangeNotifier
3. En main.dart se instancian los servicios una sola vez: se crea un DocumentPipeline y se inyecta a ambos providers
4. Cada provider sigue siendo independiente: no hay acoplamiento entre scan e import
5. Los debugPrint de timing pueden vivir en Pipeline: un solo lugar para el logging de performance

Riesgo bajo

El refactor es mecánico: extraer, delegar, no cambia comportamiento. Los tests de domain (usecases) no se tocan. Solo necesitarías verificar que los flujos completos siguen funcionando igual en emulador.

El refactor está completo. Corré fvm flutter test para confirmar.

  ---
Resumen de lo hecho:

Nuevo archivo: lib/core/services/document_pipeline.dart
- Clase pura DocumentPipeline con 3 métodos: prepare(), complete(), processOCRBackground()
- Clase PreparationResult unificada (reemplaza ScanPreparationResult e ImportPreparationResult)

scan_provider.dart — de 320 → ~140 líneas:
- Constructor: ScanDocument + DocumentPipeline (antes tenía 6 deps)
- prepareScan() y completeScan() delegan al pipeline
- Mantiene solo _isScanning y OCR simple (sin Set, sin callbacks)

import_provider.dart — de 460 → ~260 líneas:
- Constructor: DocumentPipeline + PdfImportService? (antes tenía 5 deps)
- PDF methods intactos, _processingOcrIds, onOcrComplete, onStatus callbacks
- _processOCRInBackground pasa onStatus al pipeline → provider actualiza _statusMessage + notifyListeners()

main.dart — ~60 líneas menos:
- Provider<DocumentPipeline> como primer provider (servicios instanciados UNA vez)
- ScanProvider y ImportProvider reciben el pipeline vía context.read<DocumentPipeline>()
                                                                                                                                                                            
~250 líneas netas eliminadas. Y encima el código nuevo (DocumentPipeline) 
es más testeable que lo que reemplaza, porque es una clase pura sin ChangeNotifier.  