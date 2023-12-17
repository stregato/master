import 'dart:convert';
import 'dart:math';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/qrcode_scan_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Join extends StatefulWidget {
  final void Function()? onComplete;
  const Join({this.onComplete, super.key});

  @override
  State<Join> createState() => _JoinState();

  static List<String>? parseInvite(String link) {
    var url = Uri.tryParse(link);
    if (url == null) {
      return null;
    }
    var path = url.path;
    var parts = path.split('/');
    if (parts.length != 5 || parts[1] != "a") {
      return null;
    }

    try {
      var url = utf8.decode(base64Decode(parts[4].replaceAll("_", "/")));
      return [parts[2], parts[3], url];
    } catch (e) {
      return null;
    }
  }
}

class _JoinState extends State<Join> {
  String? _errorText;
  String _name = "";
  String _creatorId = "";
  String _url = "";
  List<String> accessPrefixes = ['https://behemoth.rocks/a/', 'mg://a/'];
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  _JoinState() {
    var initialSecret = Random().nextInt(1000).toString().padLeft(4, '0');
    _secretController.text = initialSecret;

    _linkController.addListener(() async {
      parseLink(_linkController.text.trim());
    });
  }

  void parseLink(String link) {
    _url = "";
    var parts = Join.parseInvite(link);
    if (parts == null) {
      setState(() {
        _errorText = "invalid access link";
      });
      return;
    }
    setState(() {
      _name = parts[0];
      _creatorId = parts[1];
      _url = parts[2];
      _errorText = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    var link = ModalRoute.of(context)!.settings.arguments as String?;
    if (link != null) {
      parseLink(link);
    }

    var shareIdSection = <Widget>[
      if (link == null)
        Column(
          children: [
            PlatformText(
                "In order to join an existing coven, an admin must provide you with a link. "
                "Contact the admin to get a link."),
            const SizedBox(height: 20),
            PlatformTextField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              material: (context, platform) => MaterialTextFieldData(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Secret',
                  helperText:
                      "This is a number that helps the admin recognize you.",
                  errorText: _errorText,
                ),
              ),
              cupertino: (context, platform) => CupertinoTextFieldData(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 0,
                      color: CupertinoColors.inactiveGray,
                    ),
                  ),
                ),
              ),
              controller: _secretController,
            ),
            const SizedBox(height: 20),
          ],
        ),
      Row(children: [
        Expanded(
          child: link == null
              ? PlatformTextField(
                  material: (context, platform) => MaterialTextFieldData(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Access Link',
                      errorText: _errorText,
                    ),
                  ),
                  controller: _linkController,
                )
              : Text(link),
        ),
        if (link == null)
          QRCodeScannerButton(onDetect: (values, bytes) {
            _linkController.text = values.first;
          })
      ]),
      const SizedBox(height: 20),
      if (_url.isNotEmpty)
        Row(
          children: [
            Expanded(
              child: PlatformElevatedButton(
                onPressed: () async {
                  var task = Coven.join(
                      _name, _creatorId, _url, _secretController.text);
                  await progressDialog(context, "Joining $_name", task,
                      successMessage: "Added $_name");
                  widget.onComplete?.call();
                },
                child: Text("Join $_name"),
              ),
            ),
          ],
        ),
    ];

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          children: shareIdSection,
        ),
      ),
    );
  }
}
