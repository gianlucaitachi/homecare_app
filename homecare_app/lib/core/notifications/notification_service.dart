import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:hive/hive.dart';
import 'package:homecare_app/core/notifications/notification_permission_requester.dart';
import 'package:homecare_app/core/notifications/scheduled_notification.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin,
    HiveInterface? hive,
    NotificationPermissionRequester? permissionRequester,
    Future<String> Function()? getLocalTimezone,
  })  : _plugin =
            flutterLocalNotificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _hive = hive ?? Hive,
        _permissionRequester =
            permissionRequester ?? PermissionHandlerNotificationRequester(),
        _getLocalTimezone =
            getLocalTimezone ?? FlutterNativeTimezone.getLocalTimezone;

  static const String _boxName = 'scheduled_notifications';
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'task_reminders',
    'Task Reminders',
    channelDescription: 'Reminders for upcoming task due dates',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );
  static const DarwinNotificationDetails _darwinDetails =
      DarwinNotificationDetails(presentSound: true);

  final FlutterLocalNotificationsPlugin _plugin;
  final HiveInterface _hive;
  final NotificationPermissionRequester _permissionRequester;
  final Future<String> Function() _getLocalTimezone;

  Box<ScheduledNotification>? _box;
  bool _initialized = false;
  bool _timeZonesInitialized = false;
  bool _localLocationSet = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _ensureTimeZonesInitialized();
    await _ensureLocalLocationSet();

    if (!_hive.isAdapterRegistered(scheduledNotificationTypeId)) {
      _hive.registerAdapter(ScheduledNotificationAdapter());
    }

    _box ??= await _hive.openBox<ScheduledNotification>(_boxName);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initializationSettings);
    await _ensurePermissionsGranted();
    await _restoreScheduledNotifications();

    _initialized = true;
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    await _ensureInitialized();

    if (!await _ensurePermissionsGranted()) {
      await cancelTaskReminder(taskId);
      return;
    }

    if (dueDate.isBefore(DateTime.now())) {
      await cancelTaskReminder(taskId);
      return;
    }

    final notificationId = _notificationIdFor(taskId);
    await _plugin.cancel(notificationId);

    await _scheduleNotification(
      taskId: taskId,
      notificationId: notificationId,
      title: title,
      body: body,
      dueDate: dueDate,
      persist: true,
    );
  }

  Future<void> updateTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    await scheduleTaskReminder(
      taskId: taskId,
      title: title,
      body: body,
      dueDate: dueDate,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _ensureInitialized();
    final storedNotification = _box?.get(taskId);
    final notificationId =
        storedNotification?.notificationId ?? _notificationIdFor(taskId);

    await _plugin.cancel(notificationId);
    await _box?.delete(taskId);
  }

  Future<void> cancelAllReminders() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
    await _box?.clear();
  }

  Future<void> _scheduleNotification({
    required String taskId,
    required int notificationId,
    required String title,
    required String body,
    required DateTime dueDate,
    required bool persist,
  }) async {
    await _ensureLocalLocationSet();
    final scheduledDate = tz.TZDateTime.from(dueDate, tz.local);

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: _androidDetails,
        iOS: _darwinDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: taskId,
    );

    if (persist) {
      await _box?.put(
        taskId,
        ScheduledNotification(
          taskId: taskId,
          notificationId: notificationId,
          scheduledDate: dueDate,
          title: title,
          body: body,
        ),
      );
    }
  }

  Future<void> _restoreScheduledNotifications() async {
    final box = _box;
    if (box == null) {
      return;
    }

    final now = DateTime.now();
    final keys = box.keys.cast<String>().toList(growable: false);

    for (final key in keys) {
      final stored = box.get(key);
      if (stored == null) {
        continue;
      }

      if (stored.scheduledDate.isBefore(now)) {
        await box.delete(key);
        continue;
      }

      await _scheduleNotification(
        taskId: stored.taskId,
        notificationId: stored.notificationId,
        title: stored.title,
        body: stored.body,
        dueDate: stored.scheduledDate,
        persist: false,
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _ensureTimeZonesInitialized() async {
    if (_timeZonesInitialized) {
      return;
    }

    tz.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  Future<void> _ensureLocalLocationSet() async {
    if (_localLocationSet) {
      return;
    }

    await _ensureTimeZonesInitialized();
    final timeZoneName = await _getLocalTimezone();
    final location = tz.getLocation(timeZoneName);
    tz.setLocalLocation(location);
    _localLocationSet = true;
  }

  Future<bool> _ensurePermissionsGranted() async {
    if (await _permissionRequester.hasPermission()) {
      return true;
    }

    return _permissionRequester.requestPermission();
  }

  int _notificationIdFor(String taskId) => taskId.hashCode & 0x7fffffff;
}
