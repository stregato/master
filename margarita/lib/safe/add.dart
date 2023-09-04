import 'dart:io';
import 'dart:isolate';

import 'package:margarita/common/pop.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland_def.dart';

import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Add extends StatefulWidget {
  const Add({super.key});

  @override
  State<Add> createState() => _AddState();
}

class _AddState extends State<Add> {
  final _formKey = GlobalKey<FormState>();

  String? _token;
  late String _title;
  String? _validateMessage;
  bool _validToken = false;

  void _updateToken(Profile profile, String? value) {
    _token = value;
    try {
      var decodedToken = decodeAccess(profile.identity, _token!);
      _validateMessage = "Access to ${decodedToken.safeName}";
      _validToken = true;
      _title = "Join ${decodedToken.safeName}";
    } catch (e) {
      _validateMessage = "invalid token: $e";
      _validToken = false;
      _title = "Add a Portal";
    }
  }

  static testOpen(String token) {
    Isolate.run(
        () => openSafe(Profile.current().identity, token, OpenOptions()));
  }

  @override
  Widget build(BuildContext context) {
    _token ??= ModalRoute.of(context)?.settings.arguments as String?;
    var profile = Profile.current();
    _updateToken(profile, _token);

    var currentUserId = profile.identity.id;

    Widget shareButton;
    if (Platform.isAndroid || Platform.isIOS) {
      shareButton = ElevatedButton.icon(
          icon: const Icon(Icons.share),
          label: const Text("Share the URL"),
          onPressed: () {
            final box = context.findRenderObject() as RenderBox?;
            Share.share('woland://p/$currentUserId/${profile.identity.nick}',
                subject:
                    "Hi, this is ${profile.identity.nick} and my public key URL",
                sharePositionOrigin:
                    box!.localToGlobal(Offset.zero) & box.size);
          });
    } else {
      shareButton = ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text("Copy to the clipboard"),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: currentUserId)).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Id copied to clipboard")));
            });
          });
    }

    var shareIdSection = <Widget>[
      const Text(
          "Below is your id in qrcode (mobile device) and URL (desktop). "
          " Share with your peer to get a portal qrcode or URL. "
          " Scan the qrcode or enter the URL to add the portal."),
      const SizedBox(height: 20),
      QrImageView(
        data:
            'https://margarita.zone/p/$currentUserId/${profile.identity.nick}',
        version: QrVersions.auto,
        size: 320,
        gapless: false,
      ),
      const SizedBox(height: 20),
      Text('mg://p/$currentUserId/${profile.identity.nick}',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          )),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          shareButton,
          ElevatedButton(
              child: const Text("Continue"),
              onPressed: () {
                Share.share(currentUserId,
                    subject: "This is my id. Please send me a portal token!");
              }),
        ],
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_title),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          children: [
            if (!_validToken) ...shareIdSection,
            const SizedBox(height: 20),
            Builder(
              builder: (context) => Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: _token,
                      maxLines: 6,
                      decoration:
                          const InputDecoration(labelText: 'Portal URL'),
                      validator: (value) => _validateMessage,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (val) =>
                          setState(() => _updateToken(profile, val)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 16.0),
                      child: ElevatedButton(
                        onPressed: _validToken
                            ? () async {
                                var config = await progressDialog(
                                    context,
                                    "testing the connection, please wait",
                                    testOpen(_token!),
                                    errorMessage: "wow, something went wrong");
                                if (config != null && context.mounted) {
                                  snackGood(
                                      context, "Portal added successfully");
                                }
                              }
                            : null,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
