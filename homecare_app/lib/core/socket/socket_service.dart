import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SocketService {
  IO.Socket? socket;
  final FlutterSecureStorage secureStorage;
  SocketService(this.secureStorage);

  Future<void> connect(String baseUrl) async {
    final token = await secureStorage.read(key: 'access_token');
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'extraHeaders': {'Authorization': 'Bearer $token'},
      'autoConnect': false,
    });
    socket!.on('connect', (_) => print('socket connected'));
    socket!.on('disconnect', (_) => print('socket disconnected'));
    socket!.on('task:updated', (data) {
      // handle
    });
    socket!.connect();
  }

  void joinRoom(String familyId) {
    socket?.emit('joinRoom', {'familyId': familyId});
  }

  void dispose() {
    socket?.dispose();
  }
}
