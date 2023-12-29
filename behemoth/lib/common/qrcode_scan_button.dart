import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef QRCodeDetectCallback = void Function(Barcode code);

class QRCodeScannerButton extends StatelessWidget {
  final Function(List<String>, Uint8List) onDetect;

  const QRCodeScannerButton({super.key, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    // Check if the platform is iOS, Android, or macOS
    if (isMobile || isApple) {
      // Show a button for supported platforms
      return IconButton(
        icon: const Icon(Icons.qr_code),
        onPressed: () => _scanQRCode(context),
      );
    } else {
      // Return an empty container for unsupported platforms
      return Container();
    }
  }

  void _scanQRCode(BuildContext context) async {
    // Push a new route that will handle the QR code scanning
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => QRScannerScreen(onDetect: onDetect)));
  }
}

class QRScannerScreen extends StatelessWidget {
  final Function(List<String>, Uint8List) onDetect;
  final MobileScannerController controller = MobileScannerController();

  QRScannerScreen({super.key, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            var values = barcodes
                .map((e) => e.rawValue)
                .where((e) => e != null)
                .cast<String>()
                .toList();

            if (values.isEmpty) {
              showPlatformSnackbar(context, 'Failed to scan Barcode',
                  backgroundColor: Colors.red);
            } else {
              onDetect(values, capture.image!);
            }
            Navigator.of(context).pop();
          }),
    );
  }
}
