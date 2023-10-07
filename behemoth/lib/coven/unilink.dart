import 'package:flutter/material.dart';

class Unilink extends StatefulWidget {
  const Unilink({super.key});

  @override
  State<Unilink> createState() => _UnilinkState();
}

class _UnilinkState extends State<Unilink> {
  final _urlPrefixes = <String, String>{
    "https://behemoth.cool/i/": "id",
    "mg://i/": "id",
    "https://behemoth.cool/a/": "access",
    "mg://a/": "access",
  };
  final _urlArgs = <String, int>{
    "id": 2,
    "access": 1,
  };

  String? _errorText;

  final TextEditingController _idController = TextEditingController();

  _UnilinkState() {
    _idController.addListener(() {
      if (_idController.text.isNotEmpty) {
        processUrl(_idController.text);
      } else if (_errorText != null) {
        setState(() {
          _errorText = null;
        });
      }
    });
  }

  List<String> parseUrl(String url) {
    for (var e in _urlPrefixes.entries) {
      if (url.startsWith(e.key)) {
        var args = url.substring(e.key.length).split("/");
        if (args.length != _urlArgs[e.value]) {
          return ["err", "invalid ${e.value} url"];
        }
        return [e.value, ...args];
      }
    }
    return ["err", "invalid url"];
  }

  processUrl(String url) {
    var args = parseUrl(url);
    switch (args[0]) {
      case "id":
        Navigator.pushNamed(context, "/unilink/invite", arguments: {
          "id": args[1],
          "nick": args[2],
        });
        break;
      case "access":
        Navigator.pushNamed(context, "/unilink/accept", arguments: {
          "access": args[1],
        });
        break;
      case "err":
        setState(() {
          _errorText = args[1];
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
//    Uint8List? image;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Link"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: [
              const Text(
                "Links are used to connect peers to your community. "
                "Scan a QR code or copy the link in the input below",
                style: TextStyle(
                  fontSize: 16,
                  //fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                maxLines: 2,
                controller: _idController,
                decoration: InputDecoration(
                  labelText: 'Enter the link',
                  errorText: _errorText,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              // MobileScanner(
              //   // fit: BoxFit.contain,
              //   onDetect: (capture) {
              //     final List<Barcode> barcodes = capture.barcodes;
              //     final Uint8List? image = capture.image;
              //     for (final barcode in barcodes) {
              //       debugPrint('Barcode found! ${barcode.rawValue}');
              //     }
              //   },
              // ),
            ],
          ),
        ),
      ),
//      bottomNavigationBar: MainNavigationBar(safeName),
    );
  }
}
