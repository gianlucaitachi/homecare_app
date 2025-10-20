import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class TaskQrView extends StatelessWidget {
  const TaskQrView({super.key, required this.qrImageBase64});

  final String qrImageBase64;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(qrImageBase64);
    if (bytes == null) {
      return const Text('QR unavailable');
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.memory(
        bytes,
        width: 220,
        height: 220,
        fit: BoxFit.contain,
      ),
    );
  }

  Uint8List? _decode(String data) {
    try {
      final parts = data.split(',');
      final encoded = parts.length > 1 ? parts[1] : parts.first;
      return Uint8List.fromList(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }
}
