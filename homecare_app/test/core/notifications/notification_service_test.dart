import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:homecare_app/core/notifications/notification_permission_requester.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/core/notifications/scheduled_notification.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class _MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockHiveInterface extends Mock implements HiveInterface {}

class _MockNotificationPermissionRequester extends Mock
    implements NotificationPermissionRequester {}

class _MockScheduledNotificationBox extends Mock
    implements Box<ScheduledNotification> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFlutterLocalNotificationsPlugin plugin;
  late _MockHiveInterface hive;
  late _MockNotificationPermissionRequester permissionRequester;
  late _MockScheduledNotificationBox box;
  late NotificationService service;

  setUpAll(() {
    tz.initializeTimeZones();
    registerFallbackValue(
      const NotificationDetails(
        android: AndroidNotificationDetails('fallback', 'Fallback'),
        iOS: DarwinNotificationDetails(),
      ),
    );
    registerFallbackValue(tz.TZDateTime.from(DateTime.now(), tz.local));
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  });

  setUp(() {
    plugin = _MockFlutterLocalNotificationsPlugin();
    hive = _MockHiveInterface();
    permissionRequester = _MockNotificationPermissionRequester();
    box = _MockScheduledNotificationBox();

    when(() => hive.isAdapterRegistered(any())).thenReturn(true);
    when(() => hive.openBox<ScheduledNotification>(any()))
        .thenAnswer((_) async => box);
    when(() => plugin.initialize(any())).thenAnswer((_) async => true);
    when(() => plugin.cancel(any(), tag: any(named: 'tag')))
        .thenAnswer((_) async {});
    when(() => plugin.cancel(any())).thenAnswer((_) async {});
    when(() => plugin.cancelAll()).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    when(() => permissionRequester.hasPermission())
        .thenAnswer((_) async => true);
    when(() => permissionRequester.requestPermission())
        .thenAnswer((_) async => true);
    when(() => box.keys).thenReturn(<String>[]);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    when(() => box.delete(any())).thenAnswer((_) async {});
    when(() => box.get(any())).thenReturn(null);

    service = NotificationService(
      flutterLocalNotificationsPlugin: plugin,
      hive: hive,
      permissionRequester: permissionRequester,
    );
  });

  test('schedules and persists a notification for future due dates', () async {
    final dueDate = DateTime.now().add(const Duration(hours: 2));

    await service.scheduleTaskReminder(
      taskId: 'task-1',
      title: 'Clean kitchen',
      body: 'Task "Clean kitchen" is due soon.',
      dueDate: dueDate,
    );

    verify(() => plugin.cancel(any())).called(1);
    verify(
      () => plugin.zonedSchedule(
        any(),
        'Clean kitchen',
        'Task "Clean kitchen" is due soon.',
        any(),
        any(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task-1',
      ),
    ).called(1);
    verify(() => box.put('task-1', any<ScheduledNotification>())).called(1);
  });

  test('cancels reminders when the due date is in the past', () async {
    final pastDate = DateTime.now().subtract(const Duration(minutes: 5));

    await service.scheduleTaskReminder(
      taskId: 'task-2',
      title: 'Past task',
      body: 'Task "Past task" is due soon.',
      dueDate: pastDate,
    );

    verifyNever(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          payload: any(named: 'payload'),
        ));
    verify(() => plugin.cancel(any())).called(greaterThanOrEqualTo(1));
    verify(() => box.delete('task-2')).called(1);
    verifyNever(() => box.put(any(), any()));
  });

  test('restores persisted notifications when initializing', () async {
    final futureDueDate = DateTime.now().add(const Duration(hours: 3));
    final pastDueDate = DateTime.now().subtract(const Duration(hours: 1));

    when(() => box.keys).thenReturn(['future', 'past']);
    when(() => box.get('future')).thenReturn(
      ScheduledNotification(
        taskId: 'future',
        notificationId: 10,
        scheduledDate: futureDueDate,
        title: 'Laundry',
        body: 'Task "Laundry" is due soon.',
      ),
    );
    when(() => box.get('past')).thenReturn(
      ScheduledNotification(
        taskId: 'past',
        notificationId: 11,
        scheduledDate: pastDueDate,
        title: 'Old task',
        body: 'Task "Old task" is due soon.',
      ),
    );

    await service.initialize();

    verify(
      () => plugin.zonedSchedule(
        10,
        'Laundry',
        'Task "Laundry" is due soon.',
        any(),
        any(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'future',
      ),
    ).called(1);
    verify(() => box.delete('past')).called(1);
  });
}
