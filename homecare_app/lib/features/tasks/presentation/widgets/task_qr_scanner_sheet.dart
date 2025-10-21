import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef TaskQrDetectedCallback = Future<void> Function(String payload);

class TaskQrScannerSheetController {
  void _attach(_TaskQrScannerSheetState state) {
    _state = state;
  }

  void _detach(_TaskQrScannerSheetState state) {
    if (_state == state) {
      _state = null;
    }
  }

  void reset() {
    _state?._resetHandled();
  }

  _TaskQrScannerSheetState? _state;
}

class TaskQrScannerSheet extends StatefulWidget {
  const TaskQrScannerSheet({
    super.key,
    required this.onDetected,
    this.controller,
  });

  final TaskQrDetectedCallback onDetected;
  final TaskQrScannerSheetController? controller;

  @override
  State<TaskQrScannerSheet> createState() => _TaskQrScannerSheetState();
}

class _TaskQrScannerSheetState extends State<TaskQrScannerSheet> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant TaskQrScannerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void _resetHandled() {
    if (!mounted) return;
    if (!_handled) return;
    setState(() {
      _handled = false;
    });
  }

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
                    setState(() {
                      _handled = true;
                    });
                    unawaited(widget.onDetected(value));
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
