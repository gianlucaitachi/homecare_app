import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TaskQrScannerSheet extends StatefulWidget {
  const TaskQrScannerSheet({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<TaskQrScannerSheet> createState() => _TaskQrScannerSheetState();
}

class _TaskQrScannerSheetState extends State<TaskQrScannerSheet> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Scan task QR code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: 320,
            child: MobileScanner(
              onDetect: (capture) {
                if (_handled) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue;
                  if (value != null && value.isNotEmpty) {
                    _handled = true;
                    widget.onDetected(value);
                    if (mounted) Navigator.of(context).pop();
                    break;
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
