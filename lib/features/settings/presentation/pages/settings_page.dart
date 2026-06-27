import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/core/services/notification_prompt_service.dart';
import 'package:escandoc/core/services/notification_service.dart';
import 'package:escandoc/core/widgets/notification_permission_dialog.dart';
import 'package:escandoc/features/backup/presentation/providers/backup_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:escandoc/core/widgets/home_bar.dart';

/// Página de configuración — accesible desde el menú ☰ del home.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  bool? _notifEnabled;
  bool _enabling = false;
  bool _waitingForExactAlarms = false;
  bool _waitingForNotifPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_waitingForExactAlarms) {
      _waitingForExactAlarms = false;
      _finalizeEnable();
    } else if (_waitingForNotifPermission) {
      _waitingForNotifPermission = false;
      _resumeAfterNotifSettings();
    }
  }

  Future<void> _loadNotifState() async {
    final savedEnabled = await NotificationPromptService.isEnabled();
    if (savedEnabled) {
      // Verificar que el sistema realmente tiene el permiso concedido.
      // En API 33+ el default "true" de SharedPreferences no garantiza nada.
      final systemEnabled = await NotificationService.areNotificationsEnabled();
      if (!systemEnabled) {
        await NotificationPromptService.setEnabled(false);
        if (mounted) setState(() => _notifEnabled = false);
        return;
      }
    }
    if (mounted) setState(() => _notifEnabled = savedEnabled);
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_enabling) return;
    if (value) {
      await _enableWithFullFlow();
    } else {
      final confirmed = await _confirmDisable();
      if (!confirmed) return;
      await context.read<DocumentsProvider>().disableNotifications();
      final nowEnabled = await NotificationPromptService.isEnabled();
      if (mounted) setState(() => _notifEnabled = nowEnabled);
    }
  }

  Future<void> _enableWithFullFlow() async {
    setState(() => _enabling = true);

    // 1. Inicializar si hace falta
    if (!NotificationService.isInitialized) {
      final ok = await NotificationService.initialize();
      if (!ok) {
        if (mounted) {
          setState(() => _enabling = false);
          _showResultModal(success: false, titleKey: 'notif_error_init_title', bodyKey: 'notif_error_init_body');
        }
        return;
      }
    }

    // 2. Pedir POST_NOTIFICATIONS
    await NotificationService.requestNotificationPermissionOnly();

    // 3. Verificar si fue concedido
    final notifGranted = await NotificationService.areNotificationsEnabled();
    if (!notifGranted) {
      // El dialog del sistema no se muestra si ya fue denegado 2 veces.
      // Abrir Ajustes de la app para que el usuario lo habilite manualmente.
      _waitingForNotifPermission = true;
      if (mounted) setState(() => _enabling = false);
      await openAppSettings();
      return;
    }

    // 4. Verificar alarmas exactas
    final canSchedule = await NotificationService.canScheduleExactAlarms();
    if (!canSchedule) {
      _waitingForExactAlarms = true;
      if (mounted) setState(() => _enabling = false);
      await NotificationService.requestExactAlarmPermission(); // abre Ajustes del sistema
      // continúa en didChangeAppLifecycleState cuando el usuario vuelve
      return;
    }

    if (mounted) setState(() => _enabling = false);
    await _finalizeEnable();
  }

  Future<void> _resumeAfterNotifSettings() async {
    final notifGranted = await NotificationService.areNotificationsEnabled();
    if (!notifGranted) {
      if (mounted) {
        _showResultModal(
          success: false,
          titleKey: 'notif_error_permission_title',
          bodyKey: 'notif_error_permission_body',
        );
      }
      return;
    }
    final canSchedule = await NotificationService.canScheduleExactAlarms();
    if (!canSchedule) {
      _waitingForExactAlarms = true;
      await NotificationService.requestExactAlarmPermission();
      return;
    }
    await _finalizeEnable();
  }

  Future<void> _finalizeEnable() async {
    if (!mounted) return;
    await _promptBatteryOptimization();
    if (!mounted) return;
    setState(() => _enabling = true);
    await context.read<DocumentsProvider>().enableNotifications();
    final canSchedule = await NotificationService.canScheduleExactAlarms();
    final nowEnabled = await NotificationPromptService.isEnabled();
    if (!mounted) return;
    setState(() {
      _notifEnabled = nowEnabled;
      _enabling = false;
    });
    if (canSchedule) {
      _showResultModal(success: true, titleKey: 'notif_enabled_title', bodyKey: 'notif_enabled_body');
    } else {
      _showResultModal(success: false, titleKey: 'notif_error_exact_alarm_title', bodyKey: 'notif_error_exact_alarm_body');
    }
  }

  /// Pide al usuario excluir la app de la optimización de batería del SO.
  /// No bloquea el flujo: si rechaza o no responde, las notificaciones igual
  /// se activan (solo pierde robustez en standby largo).
  Future<void> _promptBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.battery_saver_outlined,
                  size: 48, color: Colors.orange[700]),
              const SizedBox(height: 16),
              Text(
                'notif_battery_optim_title'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'notif_battery_optim_body'.tr(),
                style: const TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StyledButton(
                      label: 'notif_battery_optim_later'.tr(),
                      onTap: () => Navigator.pop(ctx, false),
                      gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                      textColor: const Color(0xFF5A4A30),
                      shadowColor: const Color(0xFF9A8060),
                      border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StyledButton(
                      label: 'notif_battery_optim_configure'.tr(),
                      onTap: () => Navigator.pop(ctx, true),
                      gradientColors: [Colors.orange[400]!, Colors.orange[800]!],
                      textColor: Colors.white,
                      shadowColor: Colors.orange[900]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (proceed == true) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  void _showResultModal({required bool success, required String titleKey, required String bodyKey}) {
    showDialog(
      context: context,
      barrierDismissible: !success,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 48,
                color: success ? const Color(0xFF388E3C) : Colors.orange[700],
              ),
              const SizedBox(height: 16),
              Text(
                titleKey.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                bodyKey.tr(),
                style: const TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              if (!success) ...[
                const SizedBox(height: 24),
                _StyledButton(
                  label: 'ok_button'.tr(),
                  onTap: () => Navigator.pop(ctx),
                  gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                  textColor: const Color(0xFF5A4A30),
                  shadowColor: const Color(0xFF9A8060),
                  border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (success) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      });
    }
  }

  Future<bool> _confirmDisable() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'settings_notif_disable_title'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'settings_notif_disable_body'.tr(),
                style: const TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StyledButton(
                      label: 'cancel_button'.tr(),
                      onTap: () => Navigator.pop(ctx, false),
                      gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                      textColor: const Color(0xFF5A4A30),
                      shadowColor: const Color(0xFF9A8060),
                      border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StyledButton(
                      label: 'settings_notif_disable_confirm'.tr(),
                      onTap: () => Navigator.pop(ctx, true),
                      gradientColors: [Colors.red[400]!, Colors.red[800]!],
                      textColor: Colors.white,
                      shadowColor: Colors.red[900]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _handleBackupExport() async {
    final messenger = ScaffoldMessenger.of(context);
    final zipFile = await context.read<BackupProvider>().export();
    if (!mounted) return;
    if (zipFile == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('backup_export_error'.tr(), style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(zipFile.path, mimeType: 'application/x-escdc')]),
    );
  }

  Future<void> _handleBackupImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['escdc', 'zip'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;
    await _runBackupImport(filePath);
  }

  Future<void> _runBackupImport(String filePath) async {
    final messenger = ScaffoldMessenger.of(context);
    final backupProvider = context.read<BackupProvider>();
    final documentsProvider = context.read<DocumentsProvider>();

    messenger.showSnackBar(SnackBar(
      content: Text('backup_importing'.tr(), style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 60),
    ));

    final docsDir = await getApplicationDocumentsDirectory();
    final count = await backupProvider.importBackup(File(filePath), docsDir.path);
    if (!mounted) return;

    messenger.hideCurrentSnackBar();

    if (backupProvider.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('backup_import_error'.tr(), style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    messenger.showSnackBar(SnackBar(
      content: Text(
        'backup_import_success'.tr(namedArgs: {'count': '$count'}),
        style: const TextStyle(fontSize: 16),
      ),
      backgroundColor: const Color(0xFF2D5016),
      duration: const Duration(seconds: 3),
    ));

    await documentsProvider.loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      bottomNavigationBar: const HomeBar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 26),
            color: Colors.black87,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'settings_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final currentLocale = context.locale.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Idioma
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.language, size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'settings_language'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildLanguageDropdown(context, currentLocale),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Avisos de vencimiento
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings_notif_title'.tr(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      if (_notifEnabled != null)
                        Text(
                          _notifEnabled!
                              ? 'settings_notif_enabled'.tr()
                              : 'settings_notif_disabled'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: _notifEnabled!
                                ? const Color(0xFF388E3C)
                                : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_notifEnabled == null || _enabling)
                  const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Switch(
                    value: _notifEnabled!,
                    activeThumbColor: const Color(0xFF388E3C),
                    activeTrackColor: const Color(0xFF388E3C).withValues(alpha: 0.4),
                    onChanged: _toggleNotifications,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Copia de seguridad — Guardar
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.upload_outlined, size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'backup_export_button'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _handleBackupExport,
                  child: Text(
                    'save_button'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Copia de seguridad — Restaurar
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.download_outlined, size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'backup_import_button'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _handleBackupImport,
                  child: Text(
                    'restore_button'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Botón de prueba provisorio
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.science_outlined,
                    size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'settings_test_notif_title'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final docs = context.read<DocumentsProvider>().documents;
                    final title = docs.isNotEmpty ? docs.first.title : null;
                    await NotificationService.scheduleTestNotification(documentTitle: title);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('settings_test_notif_success'.tr()),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'settings_test_notif_button'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Botón de prueba a 10 minutos (simulación realista)
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.alarm_outlined,
                    size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'settings_test_notif_title'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final docs = context.read<DocumentsProvider>().documents;
                    final title = docs.isNotEmpty ? docs.first.title : null;
                    final scheduled = await NotificationService
                        .scheduleTestNotificationIn10Min(documentTitle: title);
                    if (context.mounted && scheduled != null) {
                      final hh = scheduled.hour.toString().padLeft(2, '0');
                      final mm = scheduled.minute.toString().padLeft(2, '0');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('settings_test_notif_10min_success'
                              .tr(namedArgs: {'time': '$hh:$mm'})),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'settings_test_notif_10min_button'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, 3),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      ),
    );
  }

  Widget _buildLanguageDropdown(BuildContext context, String currentLocale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A8060).withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentLocale,
          isDense: true,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5A4A30),
          ),
          dropdownColor: const Color(0xFFFDFAF4),
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(value: 'es', child: Text('language_es'.tr())),
            DropdownMenuItem(value: 'en', child: Text('language_en'.tr())),
          ],
          onChanged: (code) {
            if (code != null) context.setLocale(Locale(code));
          },
        ),
      ),
    );
  }
}

class _StyledButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color textColor;
  final Color shadowColor;
  final BoxBorder? border;

  const _StyledButton({
    required this.label,
    required this.onTap,
    required this.gradientColors,
    required this.textColor,
    required this.shadowColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(50),
        border: border,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.50),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
