# Manual de Firestore Sync + Cache Local en Flutter

Manual reusable para apps Flutter con **datos remotos en Firestore + cache local en SQLite + cache en memoria**. Basado en la experiencia real de QueHacemos: 128 commits de iteración (incluyendo WorkManager abandonado, "ventana 1 AM" descubierta a los golpes, y 4 fixes de "api 28" por minification) hasta llegar al estado en producción (Play Store + App Store).

> Para notif locales/FCM ver los manuales aparte. Este se enfoca en el "engine" de datos: descargar de Firestore, persistir local, exponer en memoria con UI optimista.

---

## 1. ¿Cuándo usar este patrón?

| Caso | Solución |
|------|----------|
| App con catálogo grande (eventos, productos, posts) que cambia 1x/día | **Este patrón** ✅ |
| Datos en tiempo real (chat, scores) | Streams de Firestore directo, sin cache |
| Datos solo locales (notas personales) | SQLite directo, sin Firestore |
| Datos del usuario (preferencias) | Firestore con SDK persistence |

**El patrón asume:**
- Catálogo de N items (≥100) en Firestore.
- Updates infrecuentes desde el server (1x/día típico).
- App debe funcionar offline.
- UI lee miles de veces, escribe poco (read-heavy).

---

## 2. Stack mínimo

```yaml
dependencies:
  cloud_firestore: ^6.0.0
  firebase_core: ^4.0.0
  sqflite: ^2.4.2
  shared_preferences: ^2.5.3
  internet_connection_checker_plus: ^2.8.0   # ojo: NO connectivity_plus
  provider: ^6.1.2                            # o riverpod
  http: ^1.5.0                                # solo si descargás thumbnails
```

> **Lección de QueHacemos**: en la 1ª iteración usaron `connectivity_plus`. Lo reemplazaron por `internet_connection_checker_plus` porque el primero solo te dice "hay wifi" sin garantía de internet real (puede haber wifi sin salida). El segundo hace ping a un host público.

---

## 3. Modelo de datos: lotes (batches) en Firestore

**Anti-patrón común:** 1 documento por item (`/eventos/{id}`). Suena simple pero **explota los reads de Firestore**: descargar 500 eventos = 500 reads = $$$.

**Patrón usado en QueHacemos** (verificado en `firestore_client.dart:23-27`):

```
/eventos_lotes/                       ← colección
  ├─ lote_2026-05-01/                 ← 1 doc por día/batch
  │   ├─ metadata: {
  │   │     fecha_subida: "2026-05-01",
  │   │     nombre_lote: "lote_2026-05-01"
  │   │   }
  │   └─ eventos: [                   ← array embebido (max ~1MB doc)
  │         { code: "EVT001", ... },
  │         { code: "EVT002", ... },
  │         ...
  │       ]
  │
  ├─ lote_2026-05-02/
  └─ lote_2026-05-03/
```

**Beneficios:**
- 1 read = N items. Si tu lote tiene 50 eventos, descargás 50 events con 1 read.
- `metadata.fecha_subida` permite ordenar y descargar solo los últimos N lotes.
- `metadata.nombre_lote` funciona como ETag — comparás el último que tenés vs. el primero del server, si coinciden no procesás.

**Limitación**: documentos de Firestore tienen límite de 1 MB. Si tu lote supera, partilo (`lote_2026-05-01_a`, `lote_2026-05-01_b`).

**Cómo se carga el lote**: un script server-side (Cloud Function con cron, o admin manual) corre 1x/día agregando los nuevos items en un nuevo doc-lote.

---

## 4. Schema SQLite local

Tabla principal `eventos` (verificada en `database_helper.dart:44-66`):

```sql
CREATE TABLE eventos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE,                    -- ID de negocio (no autoincrement)
  date TEXT,                           -- ISO8601: '2026-05-15T20:00:00'
  title TEXT, description TEXT,
  imageUrl TEXT, thumbnailBlob BLOB,   -- thumbnail local pre-descargado
  type TEXT, location TEXT, district TEXT,
  rating REAL,
  favorite INTEGER DEFAULT 0,
  -- ... resto de columnas de tu modelo
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_eventos_code ON eventos(code);
CREATE INDEX idx_eventos_date ON eventos(date);
CREATE INDEX idx_eventos_favorite ON eventos(favorite);
```

Tabla `app_settings` (key/value para flags y trackings):

```sql
CREATE TABLE app_settings (
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT
);
-- Ejemplos de claves:
--   'last_batch_version'         → "lote_2026-05-01"
--   'notif_table_last_cleanup'   → "2026-05-01"
--   'first_install_done'         → "true"
```

**Por qué `code TEXT UNIQUE` y no usar `id`:**
- El `id` autoincrement es local. Si reinstalás, los IDs cambian.
- El `code` viene del server, es estable. Permite UPSERT con `ON CONFLICT(code) DO UPDATE`.
- Index en `code` da O(log n) para cualquier búsqueda por código de negocio.

**Por qué `thumbnailBlob BLOB`:**
- Pre-descargás el thumbnail al sync, lo guardás como bytes en SQLite.
- Renderizado de cards = 0 network calls. Scroll fluido offline.
- Costo: ~5 KB por thumbnail × 1000 eventos = 5 MB de DB. Aceptable.

---

## 5. FirestoreClient: timing y descarga

Singleton que encapsula todo lo que toca Firestore directo. Patrón verificado en `firestore_client.dart`:

### 5.1 `shouldSync()` — política de cuándo

```dart
Future<bool> shouldSync() async {
  final prefs = await SharedPreferences.getInstance();
  final lastSyncString = prefs.getString('last_sync_timestamp');
  final now = DateTime.now();

  if (lastSyncString == null) return true;   // primera vez → sync

  final lastSync = DateTime.parse(lastSyncString);
  final today = DateTime(now.year, now.month, now.day);
  final lastSyncDay = DateTime(lastSync.year, lastSync.month, lastSync.day);

  // Si ya sincronizó hoy → NO
  if (!today.isAfter(lastSyncDay)) return false;

  // Día nuevo Y hora >= 1 AM → SÍ
  if (now.hour >= 1) return true;

  // Día nuevo PERO entre 00:00 y 00:59 → NO (ventana de upload del backend)
  return false;
}
```

> **🔥 La "ventana 1 AM"** (verificada en commit `44306a5 add multiples lotes y ventana 0 1`): el backend de QueHacemos sube los lotes nuevos entre 00:00 y 01:00. Si la app sincroniza durante esa ventana, puede agarrar lotes a medio cargar. Por eso `shouldSync()` retorna `false` entre 00:00 y 01:00 aunque sea día nuevo. Si tu backend tiene su propia ventana, ajustar.

### 5.2 `downloadDailyBatches()` — descarga lotes

```dart
static const int lotesPorDia = 1;
static const int maxLotes = 10;

Future<List<Map<String, dynamic>>> downloadDailyBatches() async {
  final daysMissed = await _getDaysSinceLastSync();
  final lotesToDownload = (daysMissed * lotesPorDia).clamp(1, maxLotes);

  final query = await FirebaseFirestore.instance
      .collection('eventos_lotes')
      .orderBy('metadata.fecha_subida', descending: true)
      .limit(lotesToDownload)
      .get();

  return query.docs.map((d) => d.data()).toList();
}
```

**Por qué `clamp(1, 10)`**: si el usuario abrió la app después de 30 días, no querés bajar 30 lotes (eso sería muchos MB). El cap a 10 es pragmático: cubre 99% de los casos sin romper a quien volvió de un viaje largo.

### 5.3 `updateSyncTimestamp()` — registrar éxito

```dart
Future<void> updateSyncTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
}
```

> **Cuidado**: solo llamar tras éxito completo. Si lo llamás antes y el sync explota a mitad, el próximo arranque cree que ya sincronizó.

---

## 6. SyncService: orquestación

Singleton que coordina download → cleanup → process → notify. Verificado en `sync_service.dart`:

```dart
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  static final _syncCompleteController = StreamController<SyncResult>.broadcast();
  static Stream<SyncResult> get onSyncComplete => _syncCompleteController.stream;

  Future<SyncResult> performAutoSync() async {
    if (_isSyncing) return SyncResult.notNeeded();
    if (!await _firestoreClient.shouldSync()) return SyncResult.notNeeded();

    _isSyncing = true;
    try {
      // 1. Capturar batchVersion ANTES (para detectar "nada nuevo")
      final currentBatchVersion = (await _firestoreClient.getSyncStatus())['batchVersion'];

      // 2. Descargar
      final batches = await _firestoreClient.downloadDailyBatches();
      if (batches.isEmpty) return SyncResult.noNewData();

      // 3. Cleanup ANTES de procesar (libera espacio + dedupe previo)
      await _performCleanup();

      // 4. Procesar lotes uno por uno (insert + dedupe + clean)
      final eventCountBefore = await _eventRepository.getTotalEvents();
      await _processEvents(batches);
      final netChange = await _eventRepository.getTotalEvents() - eventCountBefore;

      // 5. Update timestamp DESPUÉS de éxito
      await _firestoreClient.updateSyncTimestamp();

      // 6. Comparar batchVersion: si es el mismo lote, no hay novedades
      final newBatchVersion = await _getNewBatchVersion();
      final isSameBatch = currentBatchVersion == newBatchVersion;

      if (!isSameBatch && netChange > 0) {
        _syncCompleteController.add(SyncResult.success(eventsAdded: netChange));
      } else {
        _syncCompleteController.add(SyncResult.noNewData());
      }

      _homeProvider?.refresh();   // re-hidrata cache desde DB
      return SyncResult.success(eventsAdded: netChange);
    } catch (e) {
      return SyncResult.error(e.toString());
    } finally {
      _isSyncing = false;
    }
  }
}
```

### 6.1 Stream `onSyncComplete` — clave para coordinar UI

Otros widgets se suscriben (`SyncSnackbarWidget`, providers) y reaccionan: mostrar SnackBar de "X eventos nuevos", recargar cache, navegar a deep links pendientes. **Es la columna vertebral de la UX post-sync.**

### 6.2 Procesar lotes con thumbnails paralelos

Verificado en `sync_service.dart:143-189`:

```dart
Future<void> _downloadThumbnailsInParallel(List<Map> eventos) async {
  const int maxConcurrent = 10;

  for (int i = 0; i < eventos.length; i += maxConcurrent) {
    final chunk = eventos.sublist(i, min(i + maxConcurrent, eventos.length));
    await Future.wait(chunk.map((e) async {
      // Skip thumbnails de eventos antes de ayer (no se renderizan nunca)
      if (_isEventBeforeYesterday(e['date'])) {
        e['thumbnailBlob'] = null;
        return;
      }
      final url = _buildThumbnailUrl(e['imageUrl']);
      e['thumbnailBlob'] = url != null ? await _downloadThumbnail(url) : null;
    }));
  }
}

Future<Uint8List?> _downloadThumbnail(String url) async {
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    return r.statusCode == 200 ? r.bodyBytes : null;
  } catch (_) {
    return null;   // graceful: si falla, evento sin thumbnail (no rompe sync)
  }
}
```

> **Lección de QueHacemos**: descargar thumbnails secuenciales tomaba **~25s para 50 eventos**. Paralelo con max 10 concurrentes bajó a **~5s**. El cap a 10 evita saturar conexiones móviles.

### 6.3 Por qué cleanup ANTES y DESPUÉS

`_performCleanup()` corre antes (libera espacio). Y dentro de `_processEvents` cada lote vuelve a hacer `removeDuplicatesByCodes()` + `cleanOldEvents()`:

```dart
for (final batch in completeBatches) {
  await _downloadThumbnailsInParallel(eventos);
  await _eventRepository.insertEvents(eventos);
  await _eventRepository.removeDuplicatesByCodes();   // dedupe inmediato
  await _eventRepository.cleanOldEvents();             // limpieza inmediata
}
```

**Razón:** si el sync explota a mitad (sin internet, error de Firestore), los lotes ya procesados quedan limpios. Solo se pierde lo no procesado.

---

## 7. EventCacheService: cache singleton en memoria

Capa de memoria sobre SQLite. Patrón en `event_cache_service.dart`. **El propósito:** la UI lee miles de veces durante un scroll. Tocar SQLite cada vez es caro. El cache resuelve eso con un `List<EventCacheItem>` en memoria + maps precalculados.

### 7.1 Hidratación con precálculo

```dart
class EventCacheService {
  static final EventCacheService _instance = EventCacheService._internal();
  factory EventCacheService() => _instance;
  EventCacheService._internal();

  List<EventCacheItem> _cache = [];
  bool _isLoaded = false;

  // Precálculos para O(1) lookup en UI
  final Map<String, List<EventCacheItem>> _eventsByDate = {};
  Map<String, int> _eventCountsByDate = {};

  Future<void> loadCache({String theme = 'normal'}) async {
    if (_isLoaded) return;          // lazy: solo la primera vez

    final raw = await EventRepository().getAllEvents();
    _cache = raw.map((m) => EventCacheItem.fromMap(m, theme: theme)).toList();
    _cache.sort((a, b) => a.date.compareTo(b.date));
    _precalculateGroups();
    _isLoaded = true;
  }

  void _precalculateGroups() {
    _eventsByDate.clear();
    _eventCountsByDate.clear();
    for (final event in _cache) {
      final dateKey = event.date.substring(0, 10);   // 'YYYY-MM-DD'
      _eventsByDate.putIfAbsent(dateKey, () => []).add(event);
    }
    _eventCountsByDate = _eventsByDate.map((d, evs) => MapEntry(d, evs.length));
  }
}
```

### 7.2 Qué se precalcula en `EventCacheItem.fromMap`

Cosas que se computan al hidratar (1 vez), no en cada rebuild de UI:
- **Colores por tema**: 12 categorías × 6 temas = 72 combos. Pre-renderizar en cache evita lookup en runtime.
- **Formatos de fecha/hora**: `"21:30hs"`, `"Lunes, 5 de Mayo"`.
- **Emojis por categoría**: `🎭`, `🎵`, `🎬`...
- **Rating "humano"**: estrellas precomputadas.

> **Costo**: ~1.1 ms por item × 1000 = 1.1s en hidratación. **Pero**: ahorrás esos 1.1ms × N rebuilds de UI. Trade vale claramente.

### 7.3 Filter en memoria, NO en DB

```dart
FilteredEvents filter({Set<String>? categories, String? searchQuery, DateTime? selectedDate}) {
  if (!_isLoaded) return FilteredEvents.empty;

  List<EventCacheItem> filtered = _cache;

  if (categories?.isNotEmpty == true) {
    filtered = filtered.where((e) => categories!.contains(e.type.toLowerCase())).toList();
  }
  if (searchQuery?.isNotEmpty == true) {
    final q = searchQuery!.toLowerCase();
    filtered = filtered.where((e) =>
      e.title.toLowerCase().contains(q) ||
      e.location.toLowerCase().contains(q)
    ).toList();
  }
  if (selectedDate != null) {
    final ds = selectedDate.toIso8601String().substring(0, 10);
    filtered = filtered.where((e) => e.date.startsWith(ds)).toList();
  }

  // Sort triple: rating DESC, category ASC, date ASC
  filtered.sort((a, b) {
    final r = b.rating.compareTo(a.rating);
    if (r != 0) return r;
    final c = a.type.compareTo(b.type);
    if (c != 0) return c;
    return a.date.compareTo(b.date);
  });

  return FilteredEvents(events: filtered, /* ... */);
}
```

**Performance medido**: 1000 eventos, 3 filtros + sort = **<50 ms**. Aceptable para `setState` síncrono.

### 7.4 Optimistic update de favoritos

```dart
bool toggleFavorite(int eventId) {
  if (!_isLoaded) return false;
  final i = _cache.indexWhere((e) => e.id == eventId);
  if (i == -1) return false;
  final newState = !_cache[i].favorite;
  _cache[i] = _cache[i].copyWith(favorite: newState);
  return newState;
}
```

UI actualiza **inmediatamente**. La persistencia a SQLite la hace el provider con debounce (§10).

### 7.5 Recalcular tema sin recargar DB

```dart
void recalculateColorsForTheme(String theme) {
  if (!_isLoaded) return;
  for (int i = 0; i < _cache.length; i++) {
    _cache[i] = _cache[i].copyWith(theme: theme);
  }
}
```

Cuando el user cambia tema, **NO recargás de DB**. Recomputás colores in-place. ~50ms para 1000 eventos.

### 7.6 Reload tras sync

```dart
Future<void> reloadCache() async {
  _isLoaded = false;
  _cache.clear();
  _eventsByDate.clear();
  _eventCountsByDate.clear();
  await loadCache();
}
```

Llamado desde el listener de `SyncService.onSyncComplete` cuando hay netChange > 0.

---

## 8. DailyTaskManager: recovery on-resume sin WorkManager

> **🔥 Lección histórica**: QueHacemos instaló `workmanager` (`fd9610a workmanager instalado en daily`). Pelearon **semanas**. Lo sacaron (`7eae1d7 sin workmanager`, **+369 / -424 líneas**, 10 archivos). Lo reemplazaron por este patrón: corre cuando la app está abierta o vuelve del background.

Verificado en `daily_task_manager.dart`:

```dart
class DailyTaskManager {
  static final _instance = DailyTaskManager._internal();
  factory DailyTaskManager() => _instance;
  DailyTaskManager._internal();

  bool _isInitialized = false;
  Timer? _connectivityTimer;
  static const _retryInterval = Duration(minutes: 20);

  Future<void> initialize() async {
    if (_isInitialized) return;
    SyncService.onSyncComplete.listen((r) {
      if (r.success) _cancelConnectivityTimer();
    });
    _isInitialized = true;
  }

  /// Llamar al startup (postFrame) y en didChangeAppLifecycleState(resumed).
  Future<void> checkOnAppOpen() async {
    if (!_isInitialized) await initialize();
    final now = DateTime.now();

    if (now.hour >= 2) {
      // Día normal: chequear si necesita sync
      await _performRecoveryCheck();
    } else if (now.hour <= 1) {
      // Madrugada (00-01): solo si NO sincronizó hoy todavía
      if (await needsSyncToday()) {
        await _performRecoveryCheck();
      }
    }
  }

  Future<void> _performRecoveryCheck() async {
    if (!await needsSyncToday()) return;

    if (await _checkConnectivity()) {
      await SyncService().performAutoSync();
    } else {
      _startConditionalTimer();   // sin internet → timer 20 min
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      return await InternetConnection().hasInternetAccess;
    } catch (_) {
      return false;
    }
  }

  void _startConditionalTimer() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer(_retryInterval, () => _performRecoveryCheck());
  }

  void _cancelConnectivityTimer() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }
}
```

### 8.1 Por qué este patrón funciona donde WorkManager fallaba

| Problema | WorkManager | DailyTaskManager |
|----------|-------------|------------------|
| OEMs agresivos matan tareas en background | ❌ se rompe | ✅ corre solo cuando app está activa |
| Dart isolate aislado del estado de la app | ❌ requiere rebootear contexto | ✅ usa el contexto vivo |
| Permisos en Android 12+ | ❌ requiere foreground service para >15min | ✅ no requiere nada especial |
| Latencia de ejecución | ❌ horas en algunos OEMs | ✅ inmediato al abrir app |
| Debugging | ❌ pesadilla (logs separados) | ✅ logcat normal |
| **Garantía de que corra cada día** | ❌ NO | ❌ NO (si user no abre, no corre) |

**El trade**: si el usuario NO abre la app en N días, no se sincroniza. Pero ese caso era ya inevitable con WorkManager por los OEMs. Mejor reconocerlo y diseñar UX en torno a eso.

### 8.2 Notificación "sin internet" 1x/día

```dart
Future<void> _notifyNoInternetIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  final lastDate = prefs.getString('last_no_internet_notification_date');
  final today = _todayString();   // '2026-05-01'
  if (lastDate == today) return;   // ya notifiqué hoy
  // ... addNotification(...)
  await prefs.setString('last_no_internet_notification_date', today);
}
```

Throttle por día. Sin esto, cada `_performRecoveryCheck` cada 20 min spamea la campanita.

---

## 9. FirstInstallService: primer arranque

El primer arranque tiene reglas distintas: NO hay `last_sync_timestamp` en SharedPreferences, hay que descargar todo, mostrar splash diferenciado, manejar retries explícitos. Patrón típico:

```dart
class FirstInstallService {
  static const _kFirstInstallDoneKey = 'first_install_done';

  Future<bool> isFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kFirstInstallDoneKey) != 'true';
  }

  Future<bool> performFirstInstallSync({int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        if (!await InternetConnection().hasInternetAccess) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        await SyncService().performAutoSync();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kFirstInstallDoneKey, 'true');
        return true;
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }
}
```

**UX típica:**
- Splash con loading "Descargando eventos..." mientras corre.
- Si falla los 3 retries → modal "Sin conexión, abrí la app cuando tengas internet".
- Si éxito → marcar flag y proceder.

---

## 10. Optimistic updates con debounce 300 ms

El patrón de toggle de favorito (verificado en `favorites_provider.dart`):

```dart
class FavoritesProvider extends ChangeNotifier {
  Timer? _debounceTimer;
  final Set<int> _pendingWrites = {};

  Future<void> toggleFavorite(int eventId) async {
    // 1. Update inmediato del cache en memoria (UI responde sin lag)
    final newState = EventCacheService().toggleFavorite(eventId);
    notifyListeners();

    // 2. Debounce write a SQLite
    _pendingWrites.add(eventId);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _flushWrites);
  }

  Future<void> _flushWrites() async {
    final ids = _pendingWrites.toList();
    _pendingWrites.clear();
    for (final id in ids) {
      final ev = EventCacheService().getEventById(id);
      if (ev != null) {
        await EventRepository().updateFavorite(id, ev.favorite);
      }
    }
    // Side effect: re-schedule notif locales si las tenés
    _maintainNotificationSchedules();
  }
}
```

**Por qué 300 ms:**
- Toques múltiples rápidos (usuario indeciso) consolidan en 1 escritura.
- Latencia imperceptible para el user.
- Reduce I/O a SQLite ~90% en sesiones intensivas.

**Cuidado:** si la app va a background mientras hay writes pendientes, hacé `flush()` en `didChangeAppLifecycleState(paused)`.

---

## 11. Cleanup: dedupe + old events

Verificado en `event_repository.dart`:

```dart
Future<int> removeDuplicatesByCodes() async {
  final db = await _database;
  // Conservar la fila con id MÁS BAJO por code (la más vieja, asumiendo INSERT en orden)
  return await db.rawDelete('''
    DELETE FROM eventos
    WHERE id NOT IN (
      SELECT MIN(id) FROM eventos GROUP BY code
    )
  ''');
}

Future<Map<String, int>> cleanOldEvents({int normalDays = 3, int favoriteDays = 7}) async {
  final db = await _database;
  final cutoffNormal = _isoDate(DateTime.now().subtract(Duration(days: normalDays)));
  final cutoffFav = _isoDate(DateTime.now().subtract(Duration(days: favoriteDays)));

  final normalRemoved = await db.delete(
    'eventos',
    where: 'date < ? AND favorite = 0',
    whereArgs: [cutoffNormal],
  );
  final favRemoved = await db.delete(
    'eventos',
    where: 'date < ? AND favorite = 1',
    whereArgs: [cutoffFav],
  );

  return {'normalEvents': normalRemoved, 'favoriteEvents': favRemoved};
}
```

### 11.1 Por qué dual-window (3d / 7d)

- Eventos no-favoritos: borrar al cabo de 3 días post-fecha. Ya pasaron, no aportan.
- Favoritos: dar 7 días de gracia. El user puede querer recordar a qué fue la semana pasada.

**Ajustá los días según tu caso.** Eventos pasados pueden seguir siendo relevantes (histórico) → no borrar. Productos efímeros → cleanup más agresivo.

### 11.2 Atomicidad

> **Caveat real verificado:** estos `DELETE` NO están en transacción. Si la app explota a mitad, podés tener un cleanup parcial. **Mitigación**: el siguiente sync vuelve a correrlo. La pérdida de consistencia transitoria es aceptable para datos de catálogo.

Si tu app maneja datos críticos (transacciones, dinero), envolvé en `db.transaction()`.

---

## 12. Lecciones de iteración (commits reales de QueHacemos)

Cada commit se verificó en repo1. Es la historia real de cómo se llegó al patrón final.

### 12.1 WorkManager → DailyTaskManager

| Commit | Mensaje | Qué pasó |
|--------|---------|----------|
| `fd9610a` | workmanager instalado en daily | Setup del primer intento |
| `08d1d89` | implementand not back y debug wm | Pelea con background contexto |
| `7eae1d7` | sin workmanager | Eliminación: 10 archivos, +369/-424 líneas |

**Razón del abandono**: latencia inconsistente en Motorola/Xiaomi/Huawei (las tareas WorkManager se "olvidaban" durante días enteros), debugging imposible (logs separados del isolate), permisos progresivamente más restrictivos en Android 12+.

### 12.2 La "ventana 1 AM"

| Commit | Mensaje |
|--------|---------|
| `44306a5` | add multiples lotes y ventana 0 1 |
| `2a3fb9f` | fix multiples lotes en sync diario |

**Origen real**: el script server-side de QueHacemos sube los lotes nuevos entre 00:00 y 01:00 AM. Antes de implementar la ventana, los devices que abrían la app a las 00:30 sincronizaban a medio camino y veían lotes incompletos. Fix: `shouldSync()` retorna `false` durante esa hora aunque sea día nuevo.

**Generalización**: si tu backend tiene ventanas de mantenimiento conocidas, codeálas en `shouldSync()`.

### 12.3 Recovery iteraciones

`4dc5405` → `ffef7ab` → `eaab8da` (3 commits con mensaje idéntico "recovery notifications") → `de9c905 fix recovrery` → `17a68e8 fix recov y otros` → `8e3e5ee recovery y sync final`.

**Lo que se aprendió en esos 6 commits**:
1. El recovery debe correr **post-resume**, no en `initState` (puede haber sincronizado en otro lifecycle event).
2. Throttle por timestamp diario (`last_sync_timestamp` ya cubre, no necesita flag adicional).
3. El stream `onSyncComplete` debe broadcast (multi-listener) — `StreamController.broadcast()`.
4. Si recovery dispara sync y sync explota, el flag NO se setea → próximo abrir intenta de nuevo. Coherente.

### 12.4 Multi-batch cap

| Commit | Mensaje |
|--------|---------|
| `b906df2` | syn 5 lotes |
| `44306a5` | add multiples lotes y ventana 0 1 |

**Iteración del cap**: empezó en 5 lotes, terminó en 10 (`maxLotes = 10` actual). El cambio fue por feedback de usuarios que volvían de viajes largos y veían "no novedades". Subir a 10 cubrió el 99% de casos sin bajar muchos MB.

### 12.5 API 28 (Android 9) — minification rompe Firebase

`2051d3e` → `a10e985` → `d132931` → `0705e33` (4 fixes seguidos: "api 28 fix", "fix 2º", "fix 3º", "fix 4 º").

**Mismo fenómeno que documentamos en el manual de FCM**: con `isMinifyEnabled = true`, R8 ofusca clases internas de `cloud_firestore` y queries fallan en silencio en Android 9 release.

**Fix obligatorio en `proguard-rules.pro`**:

```proguard
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firebase.firestore.**
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
```

Si tu app debe correr en API 28 (Android 9 todavía es ~2-5% del mercado en Latam), agregá estas reglas el día 1.

### 12.6 connectivity_plus → internet_connection_checker_plus

Sin commit explícito pero verificable en pubspec de repo1 vs repo4: `connectivity_plus` sale, entra `internet_connection_checker_plus`.

**Razón**: `connectivity_plus` solo te dice si hay wifi/mobile activos. NO garantiza que llegues a internet. El segundo hace ping a un host público (Google DNS por default) y devuelve la verdad. **Para pre-flight de sync, el primero te miente**.

---

## 13. Bugs silenciosos conocidos

Tabla destilada de los 128 commits + verificación en código.

| # | Síntoma | Causa | Fix |
|---|---------|-------|-----|
| 1 | App primera apertura no descarga nada | `shouldSync()` retorna false sin lastSync porque la lógica chequea hour antes | Caso `lastSyncString == null → return true` debe ir PRIMERO (línea 81 firestore_client) |
| 2 | Sincroniza a las 00:30 y los datos quedan incompletos | Ventana de upload del backend | "Ventana 1 AM" en `shouldSync()` (§5.1) |
| 3 | Eventos duplicados en la lista tras varios syncs | INSERT sin UNIQUE constraint | `code TEXT UNIQUE` + `removeDuplicatesByCodes()` post-insert |
| 4 | Cache stale tras sync | Provider no se entera | `SyncService.onSyncComplete.listen` → `cache.reloadCache()` |
| 5 | Sync corre 2 veces simultáneas | Dos triggers (startup + resume) sin flag | `_isSyncing` boolean (single-thread Dart suficiente) |
| 6 | Toggle de favorito hace lag | UI espera al SQLite write | Optimistic update + debounce 300ms (§10) |
| 7 | App con WorkManager nunca corre tareas en Motorola | OEM-killing | Migrar a DailyTaskManager (§8) |
| 8 | "Sin internet" notif spammea | Sin throttle | 1x/día con flag en SharedPreferences |
| 9 | Release Android 9 no descarga de Firestore | Minification rompe firestore | ProGuard rules (§12.5) |
| 10 | `connectivity_plus` reporta "hay wifi" pero sync falla | Wifi sin internet real | Cambiar a `internet_connection_checker_plus` |
| 11 | Cambio de tema lagea con 1000+ eventos | Recargar de DB cada vez | `recalculateColorsForTheme()` in-place sin DB (§7.5) |
| 12 | Filtros lentos | Filtrar en SQLite con LIKE | Filtrar en memoria sobre `_cache` (§7.3) |
| 13 | Thumbnails secuenciales = 25s para 50 eventos | Sin paralelismo | `Future.wait` con max 10 concurrentes (§6.2) |
| 14 | Thumbnail roto rompe el sync entero | `http.get` sin timeout/catch | Try/catch con `return null` graceful (§6.2) |
| 15 | `cleanOldEvents` borra favoritos viejos | Mismo cutoff para todos | Dual-window 3d normal / 7d favoritos (§11.1) |
| 16 | App abre offline y muestra "0 eventos" | Cache no se hidrata sin DB | `loadCache` lee de SQLite (offline funciona si hay datos previos) |
| 17 | Reinstalar pierde IDs y rompe links | `id` autoincrement local | Usar `code` (server-side) para todas las referencias |
| 18 | Modal de detalle abre vacío al tap-en-FCM | Race entre sync y deep link | "Esperar a que sync termine" pattern (manual FCM §9.2) |

---

## 14. Coexistencia con FCM y notif locales

Si tu app además usa FCM o notif locales (recomendado), coordinar con sync:

- **FCM silent push** puede triggerear `SyncService.performAutoSync()` (1 read de Firestore on-demand). Patrón "FCM como wakeup" (ver manual FCM §11).
- **Notif locales** programadas con datos del cache: cuando sync trae eventos nuevos, re-programar notif (`maintainNotificationSchedules()`).
- **Stream `onSyncComplete`**: tanto el provider de UI como el manager de notif locales se suscriben. Patrón pub-sub limpio.

---

## 15. Checklist de QA

### Funcional
- [ ] Cold start sin internet → app abre con cache (eventos previos), muestra "sin internet" 1x.
- [ ] Cold start con internet, primera apertura → descarga, splash, eventos visibles.
- [ ] Cold start ya sincronizado hoy → abre directo sin sync.
- [ ] App en foreground a las 00:30 → NO sincroniza (ventana).
- [ ] App en foreground a las 02:00 (día nuevo) → SÍ sincroniza.
- [ ] Toggle favorito → UI inmediato, persiste tras kill app.
- [ ] Cambio de tema → 1000+ eventos repintan en <100ms.
- [ ] Filtro por categoría + búsqueda + fecha simultáneo → resultados correctos.

### Sync
- [ ] Sync con error a mitad → no corrupción, próximo intento corre OK.
- [ ] 2 triggers de sync simultáneos → solo 1 se ejecuta (`_isSyncing` flag).
- [ ] Después del sync, cache se re-hidrata (no muestra datos viejos).
- [ ] `onSyncComplete` emite a todos los listeners.
- [ ] Si misma `batchVersion` → emite `noNewData`, no muestra "X nuevos".

### Performance
- [ ] Hidratación de 1000 eventos: <2s.
- [ ] Filter en memoria 1000 eventos: <50ms.
- [ ] Scroll en lista de 1000 cards: 60 fps.
- [ ] Thumbnails de 50 eventos en paralelo: <8s.

### Build
- [ ] Release Android 9 (API 28) descarga de Firestore (probar en device físico viejo).
- [ ] `proguard-rules.pro` con keep de `com.google.firebase.firestore.**`.
- [ ] `google-services.json` en build pero NO commiteado.
- [ ] iOS: `GoogleService-Info.plist` agregado al target Runner.

### Edge cases
- [ ] Usuario abre app después de 30 días → descarga `clamp(daysMissed, 1, 10)` lotes.
- [ ] Reinstall → `first_install_done` no existe → corre flow de primera instalación.
- [ ] Cleanup borra duplicados sin tocar favoritos.
- [ ] Cambio manual de hora del device → sync respeta `lastSync` con timestamp ISO.

---

## 16. Referencias de código

### Repo1 (`repo1_QueHacemos`, 128 commits) — historia de iteraciones
Útil para entender **qué se intentó y falló**. Commits clave:
- `fd9610a` instalación WorkManager → `7eae1d7` abandono.
- `44306a5` ventana 1 AM → `2a3fb9f` fix.
- `4dc5405`/`ffef7ab`/`eaab8da` recovery iteraciones.
- `2051d3e`/`a10e985`/`d132931`/`0705e33` fixes API 28 minification.

### Repo4 (`repo4_QueHacemosClean`, 30 commits) — versión en producción
Estado limpio post-aprendizaje. Archivos clave:
- `lib/src/sync/sync_service.dart` — orquestación (líneas 31-133)
- `lib/src/sync/firestore_client.dart` — `shouldSync` (76-104), `downloadDailyBatches` (18-58)
- `lib/src/cache/event_cache_service.dart` — singleton + filter (entire)
- `lib/src/services/daily_task_manager.dart` — recovery on-resume (1-120)
- `lib/src/data/database/database_helper.dart` — schema events (44-66) + indexes (141-149)
- `lib/src/data/repositories/event_repository.dart` — `cleanOldEvents` (92), `removeDuplicatesByCodes` (120)
- `lib/main.dart` — bootstrap (Firebase init + tz + post-frame DailyTaskManager)

### Manuales relacionados
- `.context/manual_notificaciones_locales.md` — locales programadas (acoplado: post-sync re-schedule).
- `.context/manual_fcm_notifications.md` — FCM (acoplado: silent push como trigger de sync).

---

## 17. TL;DR

1. **Modelo Firestore**: documentos-lote con `metadata + eventos[]` array, NO 1 doc por evento.
2. **Schema SQLite**: `code TEXT UNIQUE` como clave de negocio, no usar `id` autoincrement para referencias.
3. **`shouldSync()`**: respeta ventana de upload del backend (ej. 00-01 AM).
4. **SyncService**: orquesta download → cleanup → process (con dedupe + clean por lote) → updateTimestamp → emit stream.
5. **EventCacheService**: lazy load, precálculo (colores, formatos, grupos por fecha), filter en memoria.
6. **NO WorkManager**: usar `DailyTaskManager` con `checkOnAppOpen` + connectivity check + retry timer 20 min.
7. **Optimistic UI + debounce 300ms** para toggles frecuentes.
8. **Thumbnails paralelos** con max 10 concurrentes + skip de eventos viejos.
9. **Cleanup dual**: 3 días para no-favoritos, 7 días para favoritos.
10. **`internet_connection_checker_plus`**, NO `connectivity_plus`.
11. **ProGuard**: `-keep com.google.firebase.firestore.**` + `-keepattributes` o release falla en Android 9 silently.
12. **Stream `onSyncComplete`** broadcast es la columna vertebral de la coordinación post-sync (UI, notif, deep links).

