import 'package:hive/hive.dart';

const int scheduledNotificationTypeId = 1;

@HiveType(typeId: scheduledNotificationTypeId)
class ScheduledNotification extends HiveObject {
  ScheduledNotification({
    required this.taskId,
    required this.notificationId,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });

  @HiveField(0)
  final String taskId;

  @HiveField(1)
  final int notificationId;

  @HiveField(2)
  final DateTime scheduledDate;

  @HiveField(3)
  final String title;

  @HiveField(4)
  final String body;
}

class ScheduledNotificationAdapter extends TypeAdapter<ScheduledNotification> {
  @override
  final int typeId = scheduledNotificationTypeId;

  @override
  ScheduledNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledNotification(
      taskId: fields[0] as String,
      notificationId: fields[1] as int,
      scheduledDate: fields[2] as DateTime,
      title: fields[3] as String,
      body: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledNotification obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.notificationId)
      ..writeByte(2)
      ..write(obj.scheduledDate)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.body);
  }
}
