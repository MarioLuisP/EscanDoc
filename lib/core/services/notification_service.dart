import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_prompt_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Navigator key para deep linking al tocar una notificación.
  /// Debe asignarse desde main.dart antes de initialize().
  static GlobalKey<NavigatorState>? navigatorKey;

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'vencimientos',
      'Vencimientos de documentos',
      channelDescription: 'Avisos de documentos próximos a vencer',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFF7ED321),
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Inicializa el plugin (registra canales y callbacks).
  /// Debe llamarse desde un PostFrameCallback — necesita Activity activa en Android.
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      const androidSettings =
          AndroidInitializationSettings('ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final success = await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('[Notif] initialize() retornó: $success');
      if (success != false) {
        _initialized = true;
        debugPrint('[Notif] _initialized = true');
        return true;
      }
      debugPrint('[Notif] initialize() falló → _initialized sigue false');
      return false;
    } catch (e) {
      debugPrint('[Notif] ERROR initialize: $e');
      return false;
    }
  }

  static bool get isInitialized => _initialized;

  /// Retorna true si el permiso de notificaciones está concedido.
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    }
    if (Platform.isIOS) {
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      // En iOS requestPermissions() devuelve el estado actual sin mostrar
      // dialog si el permiso ya fue decidido (onboarding lo pide en initialize).
      final granted = await ios?.requestPermissions(
        alert: true, badge: true, sound: true,
      );
      return granted ?? true;
    }
    return true;
  }

  /// Retorna true si las alarmas exactas están permitidas.
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  /// Pide permiso de notificaciones sin redirigir a ajustes de alarmas exactas.
  static Future<void> requestNotificationPermissionOnly() async {
    if (!_initialized) return;
    try {
      if (Platform.isAndroid) {
        final android = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final ios = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('[Notif] ERROR requestNotificationPermissionOnly: $e');
    }
  }

  /// Redirige a Ajustes del sistema para habilitar alarmas exactas.
  static Future<void> requestExactAlarmPermission() async {
    if (!_initialized || !Platform.isAndroid) return;
    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[Notif] ERROR requestExactAlarmPermission: $e');
    }
  }

  /// Pide permiso de notificaciones al sistema operativo.
  /// Llamar DESPUÉS de initialize(), desde dentro del widget tree.
  static Future<void> requestPermission() async {
    debugPrint('[Notif] requestPermission() — _initialized: $_initialized');
    if (!_initialized) return;
    try {
      if (Platform.isAndroid) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        // Android 12+ requiere permiso explícito para alarmas exactas.
        // Sin esto, zonedSchedule lanza SecurityException silenciosa.
        await android?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('[NotificationService] Error al pedir permiso: $e');
    }
  }

  /// Retorna el documentId si la app fue lanzada desde un tap en notificación
  /// (cold start). Llamar después de initialize() en main.dart.
  static Future<int?> getNotificationLaunchDocumentId() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return _parseDocumentId(details?.notificationResponse?.payload);
    }
    return null;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final docId = _parseDocumentId(response.payload);
    if (docId == null) return;

    final navigator = navigatorKey?.currentState;
    navigator?.pushNamed('/document/detail', arguments: docId);
  }

  static int? _parseDocumentId(String? payload) {
    if (payload == null || !payload.startsWith('expiry_reminder:')) return null;
    return int.tryParse(payload.split(':').last);
  }

  /// Programa 3 notificaciones para el documento:
  /// - 7 días antes a las 9:00 AM  (id * 10)
  /// - 1 día antes a las 9:00 AM   (id * 10 + 1)
  /// - El día del vencimiento 9 AM (id * 10 + 2)
  static Future<void> scheduleExpiryNotifications(
    int documentId,
    String documentTitle,
    DateTime expiryDate,
  ) async {
    if (!_initialized) return;
    if (!await NotificationPromptService.isEnabled()) return;

    await cancelExpiryNotifications(documentId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final shortName = _extractShortName(documentTitle);
    final payload = 'expiry_reminder:$documentId';

    Future<void> schedule(int id, DateTime date, String bodyKey) async {
      final scheduled = DateTime(date.year, date.month, date.day, 9, 0);
      if (date.isBefore(today) || !scheduled.isAfter(now)) return;
      try {
        await _notifications.zonedSchedule(
          id: id,
          title: shortName,
          body: bodyKey.tr(),
          scheduledDate: _toTZDateTime(scheduled),
          notificationDetails: _notifDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[Notif] Error schedulando id=$id: $e');
      }
    }

    await schedule(documentId * 10,     expiryDay.subtract(const Duration(days: 7)), 'notif_body_7days');
    await schedule(documentId * 10 + 1, expiryDay.subtract(const Duration(days: 1)), 'notif_body_tomorrow');
    await schedule(documentId * 10 + 2, expiryDay,                                   'notif_body_today');
  }

  static String _extractShortName(String title) {
    const skip = {
      'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
      'de', 'del', 'al', 'en', 'con', 'por', 'para', 'a', 'e', 'y',
      'mi', 'tu', 'su', 'mis', 'tus', 'sus',
      'the', 'an', 'of', 'in', 'on', 'at', 'to', 'for', 'with',
    };

    bool isNumeric(String s) => RegExp(r'^\d+$').hasMatch(s);

    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final meaningful = words.where((w) => !skip.contains(w.toLowerCase())).toList();

    if (meaningful.isEmpty) return title.length > 10 ? title.substring(0, 10) : title;

    final hasWord = meaningful.any((w) => !isNumeric(w));
    if (!hasWord) {
      final num = meaningful.first;
      return num.length > 10 ? num.substring(0, 10) : num;
    }

    final result = <String>[];
    for (final w in meaningful) {
      if (result.isEmpty && isNumeric(w)) continue;
      result.add(_capitalize(w));
      if (result.length == 2) break;
    }
    return result.join(' ');
  }

  static String _capitalize(String w) {
    if (w.isEmpty) return w;
    // Acrónimos de hasta 4 letras se conservan en mayúsculas (DNI, VISA, IVA)
    if (w.length <= 4 && w == w.toUpperCase()) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }

  static tz.TZDateTime _toTZDateTime(DateTime localTime) {
    return tz.TZDateTime(
      tz.local,
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
      localTime.second,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancela las 3 notificaciones programadas del documento.
  static Future<void> cancelExpiryNotifications(int documentId) async {
    await _notifications.cancel(id: documentId * 10);
    await _notifications.cancel(id: documentId * 10 + 1);
    await _notifications.cancel(id: documentId * 10 + 2);
  }

  /// 1 notificación programada para "ahora + 10 min" usando construcción
  /// por componentes (año/mes/día/hora/min) — mismo code path que
  /// `scheduleExpiryNotifications`. Sirve para validar entrega con pantalla
  /// bloqueada y entrar en Doze ligero.
  static Future<DateTime?> scheduleTestNotificationIn10Min({String? documentTitle}) async {
    debugPrint('[Notif] scheduleTestNotificationIn10Min() — _initialized: $_initialized');
    if (!_initialized) return null;
    final enabled = await NotificationPromptService.isEnabled();
    if (!enabled) return null;

    final shortName = _extractShortName(documentTitle ?? 'Factura de Aguas Cordobesas');
    final target = DateTime.now().add(const Duration(minutes: 10));
    final scheduled = DateTime(
      target.year, target.month, target.day,
      target.hour, target.minute, target.second,
    );

    try {
      await _notifications.zonedSchedule(
        id: 99996,
        title: shortName,
        body: 'notif_body_today'.tr(),
        scheduledDate: _toTZDateTime(scheduled),
        notificationDetails: _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return scheduled;
    } catch (e) {
      debugPrint('[Notif] Error prueba 10min: $e');
      return null;
    }
  }

  /// 3 notificaciones de prueba en 20/40/60 segundos con el formato real.
  static Future<void> scheduleTestNotification({String? documentTitle}) async {
    debugPrint('[Notif] scheduleTestNotification() — _initialized: $_initialized');
    if (!_initialized) {
      debugPrint('[Notif] ✗ no inicializado, saliendo');
      return;
    }
    final enabled = await NotificationPromptService.isEnabled();
    debugPrint('[Notif] isEnabled: $enabled');
    if (!enabled) {
      debugPrint('[Notif] ✗ notificaciones deshabilitadas, saliendo');
      return;
    }

    final shortName = _extractShortName(documentTitle ?? 'Factura de Aguas Cordobesas');
    final now = DateTime.now();
    final tests = [
      (id: 99997, delay: 20, bodyKey: 'notif_body_7days'),
      (id: 99998, delay: 40, bodyKey: 'notif_body_tomorrow'),
      (id: 99999, delay: 60, bodyKey: 'notif_body_today'),
    ];

    for (final t in tests) {
      try {
        await _notifications.zonedSchedule(
          id: t.id,
          title: shortName,
          body: t.bodyKey.tr(),
          scheduledDate: _toTZDateTime(now.add(Duration(seconds: t.delay))),
          notificationDetails: _notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[Notif] Error prueba id=${t.id}: $e');
      }
    }
  }
}
