
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