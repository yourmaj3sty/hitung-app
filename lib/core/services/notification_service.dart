import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_io/io.dart';
import '../utils/currency_formatter.dart';

/// Layanan notifikasi lokal 100% offline (Feature 6 & 7):
/// - Pengingat harian untuk mencatat pengeluaran.
/// - Peringatan batas anggaran saat mencapai 80% dan 100%.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelDailyId = 'daily_reminders';
  static const String _channelDailyName = 'Pengingat Harian';
  static const String _channelBudgetId = 'budget_alerts';
  static const String _channelBudgetName = 'Peringatan Anggaran';

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      // Tanpa ini tz.local = UTC, sehingga pengingat jam 20:00 berbunyi jam 03:00 WIB.
      tz.setLocalLocation(resolveLocalLocation());
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open notification');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Tapped notification handling
        },
      );
    } catch (e) {
      debugPrint('NotificationService init error (expected in tests): $e');
    }

    _initialized = true;
  }

  /// Menentukan lokasi zona waktu perangkat tanpa plugin tambahan:
  /// 1) zona Indonesia berdasarkan offset (WIB/WITA/WIT),
  /// 2) lokasi yang singkatan & offset-nya sama dengan perangkat,
  /// 3) lokasi mana pun dengan offset sama, 4) UTC.
  @visibleForTesting
  static tz.Location resolveLocalLocation({Duration? offset, String? abbreviation, DateTime? now}) {
    final current = now ?? DateTime.now();
    final off = offset ?? current.timeZoneOffset;
    final abbr = abbreviation ?? current.timeZoneName;
    const indonesia = {420: 'Asia/Jakarta', 480: 'Asia/Makassar', 540: 'Asia/Jayapura'};
    final preferred = indonesia[off.inMinutes];
    if (preferred != null) return tz.getLocation(preferred);

    final nowMs = current.toUtc().millisecondsSinceEpoch;
    tz.Location? sameOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final zone = loc.timeZone(nowMs);
      if (zone.offset != off) continue;
      if (zone.abbreviation == abbr) return loc;
      sameOffset ??= loc;
    }
    return sameOffset ?? tz.UTC;
  }

  /// Menjadwalkan ulang pengingat harian bila aktif (dipanggil saat aplikasi dibuka).
  Future<void> rescheduleDailyReminderIfEnabled({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!enabled) return;
    await scheduleDailyReminder(hour: hour, minute: minute);
  }

  /// Meminta izin notifikasi (Android 13+ & iOS)
  Future<bool> requestPermissions() async {
    if (!_initialized) await init();

    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosImplementation =
            _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Menjadwalkan pengingat harian (Feature 6)
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    if (!_initialized) await init();

    try {
      await _plugin.cancel(id: 1001); // ID untuk pengingat harian
    } catch (_) {}

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelDailyId,
      _channelDailyName,
      channelDescription: 'Pengingat harian untuk mencatat pemasukan dan pengeluaran.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.zonedSchedule(
        id: 1001,
        title: 'Sudah catat duit hari ini? ✨',
        body: 'Yuk luangkan 30 detik untuk catat pengeluaran dan pemasukanmu.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(id: 1001);
    } catch (_) {}
  }

  /// Menampilkan peringatan batas anggaran saat mencapai 80% atau 100% (Feature 7)
  Future<void> showBudgetAlert({
    required String categoryOrGlobal,
    required int percentage,
    required int current,
    required int limit,
  }) async {
    if (!_initialized) await init();

    final isOver = percentage >= 100;
    final title = isOver
        ? '⚠️ Anggaran $categoryOrGlobal Mencapai 100%!'
        : '⚡ Peringatan: Anggaran $categoryOrGlobal Sudah 80%';

    final body = isOver
        ? 'Pengeluaran telah mencapai ${CurrencyFormatter.formatRupiah(current)} dari batas ${CurrencyFormatter.formatRupiah(limit)}.'
        : 'Pengeluaran sudah ${CurrencyFormatter.formatRupiah(current)} ($percentage% dari ${CurrencyFormatter.formatRupiah(limit)}).';

    const androidDetails = AndroidNotificationDetails(
      _channelBudgetId,
      _channelBudgetName,
      channelDescription: 'Pemberitahuan saat anggaran bulanan mendekati atau melebihi batas.',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFEF4444),
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    // ID unik berdasarkan nama kategori agar tidak saling menimpa
    final id = 2000 + categoryOrGlobal.hashCode.abs() % 1000;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }

  /// Menampilkan notifikasi instan langsung
  Future<void> showInstantNotification({required String title, required String body}) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'instant_alerts',
      'Pemberitahuan Langsung',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    try {
      await _plugin.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }
}
