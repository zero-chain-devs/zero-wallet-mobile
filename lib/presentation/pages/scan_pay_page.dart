import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import 'send_payment_page.dart';

class ScanPayPage extends StatefulWidget {
  const ScanPayPage({super.key});

  @override
  State<ScanPayPage> createState() => _ScanPayPageState();
}

class _ScanPayPageState extends State<ScanPayPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan to Pay')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final raw = capture.barcodes.first.rawValue?.trim();
              if (raw == null || raw.isEmpty) return;

              final address = _extractAddress(raw);
              if (address == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unsupported QR content, please scan an address',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              _handled = true;
              final amount = _extractAmount(raw);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SendPaymentPage(
                    initialTo: address,
                    initialAmount: amount,
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(14),
              child: const Text(
                'Scan recipient QR (supports 0x... / ethereum: / value)',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractAddress(String raw) {
    final direct = raw;
    if (_isAddress(direct)) {
      return direct;
    }

    if (raw.startsWith('ethereum:')) {
      final payload = raw.substring('ethereum:'.length);
      final qIndex = payload.indexOf('?');
      final address = (qIndex >= 0 ? payload.substring(0, qIndex) : payload)
          .trim();
      if (_isAddress(address)) {
        return address;
      }
    }

    return null;
  }

  String? _extractAmount(String raw) {
    if (!raw.startsWith('ethereum:')) {
      return null;
    }

    final payload = raw.substring('ethereum:'.length);
    final qIndex = payload.indexOf('?');
    if (qIndex < 0 || qIndex >= payload.length - 1) {
      return null;
    }

    final query = payload.substring(qIndex + 1);
    final params = Uri.splitQueryString(query);
    final value = params['value'];
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return _normalizeAmountValue(value.trim());
  }

  String? _normalizeAmountValue(String rawValue) {
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(rawValue)) {
      return rawValue;
    }

    return null;
  }

  bool _isAddress(String value) {
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value);
  }
}
