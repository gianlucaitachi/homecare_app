import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:uuid/uuid.dart';

class TaskQrService {
  TaskQrService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  ({String payload, String imageDataUri}) generate(String taskId) {
    final nonce = _uuid.v4();
    final payload = jsonEncode({
      'taskId': taskId,
      'nonce': nonce,
      'type': 'task',
    });

    final qrCode = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );

    final moduleCount = qrCode.moduleCount;
    final pixelSize = 8;
    final size = moduleCount * pixelSize;
    final image = img.Image(width: size, height: size);

    // White background
    img.fill(image, img.getColor(255, 255, 255));

    for (var x = 0; x < moduleCount; x++) {
      for (var y = 0; y < moduleCount; y++) {
        final isDark = qrCode.isDark(y, x);
        final color = isDark ? img.getColor(0, 0, 0) : img.getColor(255, 255, 255);
        if (isDark) {
          for (var dx = 0; dx < pixelSize; dx++) {
            for (var dy = 0; dy < pixelSize; dy++) {
              image.setPixel(x * pixelSize + dx, y * pixelSize + dy, color);
            }
          }
        }
      }
    }

    final pngBytes = img.encodePng(image);
    final base64Data = base64Encode(pngBytes);
    return (payload: payload, imageDataUri: 'data:image/png;base64,$base64Data');
  }
}
