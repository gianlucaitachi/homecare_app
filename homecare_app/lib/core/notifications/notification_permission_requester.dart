import 'package:permission_handler/permission_handler.dart';

abstract class NotificationPermissionRequester {
  Future<bool> hasPermission();

  Future<bool> requestPermission();
}

class PermissionHandlerNotificationRequester
    implements NotificationPermissionRequester {
  @override
  Future<bool> hasPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
