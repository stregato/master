import 'dart:io';

import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareData extends StatelessWidget {
  final String _label;
  final String _value;
  const ShareData(this._label, this._value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget shareButton;
    if (Platform.isAndroid || Platform.isIOS) {
      shareButton = Container(
        constraints:
            const BoxConstraints(minWidth: 200.0), // Set the minimum width here
        child: ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text("Share"),
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              Share.share(_value,
                  sharePositionOrigin:
                      box!.localToGlobal(Offset.zero) & box.size);
            }),
      );
    } else {
      shareButton = ElevatedButton.icon(
        icon: const Icon(Icons.copy),
        label: const Text("Copy"),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: _value)).then((_) {
            showPlatformSnackbar(context, "Link copied to clipboard",
                backgroundColor: Colors.green);
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        PlatformTextField(
          controller: TextEditingController(text: _value),
          readOnly: true,
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: shareButton),
          const SizedBox(width: 10),
          Expanded(
            child: PlatformElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse(
                    'https://mail.google.com/mail/?view=cm&fs=1&to=&su=$_label&body=$_value'));
              },
              child: const Text("Gmail"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PlatformElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse('mailto:?subject=$_label&body=_value'));
              },
              child: const Text("Mail"),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Container(
          color: Colors.white,
          child: QrImageView(
            data: _value,
            version: QrVersions.auto,
            size: 240,
            gapless: false,
          ),
        ),
      ],
    );
  }
}
