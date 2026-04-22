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
      icon: '@drawable/ic_notification',
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
          AndroidInitializationSettings('@drawable/ic_notification');
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

      if (success == true) {
        _initialized = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[NotificationService] Error al inicializar: $e');
      return false;
    }
  }

  /// Pide permiso de notificaciones al sistema operativo.
  /// Llamar DESPUÉS de initialize(), desde dentro del widget tree.
  static Future<void> requestPermission() async {
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

  /// Programa 2 notificaciones para el documento:
  /// - 7 días antes del vencimiento a las 9:00 AM
  /// - El día del vencimiento a las 9:00 AM
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
    final expiryDay =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final sevenDaysBefore = expiryDay.subtract(const Duration(days: 7));
    final payload = 'expiry_reminder:$documentId';

    // Aviso 7 días antes
    if (!sevenDaysBefore.isBefore(today)) {
      final scheduled = DateTime(
          sevenDaysBefore.year, sevenDaysBefore.month, sevenDaysBefore.day, 9, 0);
      if (scheduled.isAfter(now)) {
        try {
          await _notifications.zonedSchedule(
            id: documentId * 10,
            title: 'notif_expiry_soon_title'.tr(),
            body: 'notif_expiry_soon_body'.tr(namedArgs: {'title': documentTitle}),
            scheduledDate: _toTZDateTime(scheduled),
            notificationDetails: _notifDetails,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (e) {
          debugPrint('[NotificationService] Error aviso 7 días: $e');
        }
      }
    }

    // Aviso el día del vencimiento
    if (!expiryDay.isBefore(today)) {
      final scheduled =
          DateTime(expiryDay.year, expiryDay.month, expiryDay.day, 9, 0);
      if (scheduled.isAfter(now)) {
        try {
          await _notifications.zonedSchedule(
            id: documentId * 10 + 1,
            title: 'expiry_today'.tr(),
            body: 'notif_expiry_today_body'.tr(namedArgs: {'title': documentTitle}),
            scheduledDate: _toTZDateTime(scheduled),
            notificationDetails: _notifDetails,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (e) {
          debugPrint('[NotificationService] Error aviso día vencimiento: $e');
        }
      }
    }
  }

  static tz.TZDateTime _toTZDateTime(DateTime localTime) {
    return tz.TZDateTime(
      tz.local,
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancela las notificaciones programadas del documento.
  static Future<void> cancelExpiryNotifications(int documentId) async {
    await _notifications.cancel(id: documentId * 10);
    await _notifications.cancel(id: documentId * 10 + 1);
  }

  /// Notificación de prueba — llega en 2 minutos. Solo para verificar la integración.
  static Future<void> scheduleTestNotification() async {
    if (!_initialized) return;
    if (!await NotificationPromptService.isEnabled()) return;
    final scheduledTime = DateTime.now().add(const Duration(minutes: 2));
    try {
      await _notifications.zonedSchedule(
        id: 99999,
        title: 'notif_test_title'.tr(),
        body: 'notif_test_body'.tr(),
        scheduledDate: _toTZDateTime(scheduledTime),
        notificationDetails: _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error en notificación de prueba: $e');
    }
  }
}
