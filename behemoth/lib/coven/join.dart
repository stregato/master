import 'dart:math';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/qrcode_scan_button.dart';
import 'package:behemoth/woland/types.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Join extends StatefulWidget {
  const Join({super.key});

  @override
  State<Join> createState() => _JoinState();
}

class _JoinState extends State<Join> {
  String? _errorText;
  DecodedToken? _decodedToken;
  String _access = "";
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
    _access = "";
    if (link.isEmpty) {
      return;
    }
    var f = accessPrefixes
        .map((p) => link.startsWith(p) ? link.substring(p.length) : "")
        .where((e) => e.isNotEmpty);
    if (f.isEmpty) {
      setState(() {
        _errorText = "invalid access link";
      });
      return;
    }

    _access = f.first;

    try {
      _decodedToken = null;
      _decodedToken = decodeAccess(Profile.current.identity, _access);
      setState(() {
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _errorText = "invalid or expired link: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var profile = Profile.current;
    var link = ModalRoute.of(context)!.settings.arguments as String?;
    if (link != null) {
      parseLink(link);
    }

    var currentUserId = profile.identity.id;
    // var mobileLink =
    //     'https://behemoth.rocks/i/$currentUserId/${profile.identity.nick}';

    var shareIdSection = <Widget>[
      if (link == null)
        Column(
          children: [
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
            // const Text("Below is your id if link. "
            //     " Share with your peer to get an invite. "),
            // const SizedBox(height: 20),
            // CopyField("Identity link", mobileLink),
            // const SizedBox(height: 40),
            const Text(
                "Once you get a link, paste it below and click on 'Join' to join the community"),
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
      if (_decodedToken != null)
        PlatformElevatedButton(
          onPressed: (_decodedToken != null && _errorText == null)
              ? () async {
                  var name = _decodedToken!.safeName;
                  var access = encodeAccess(
                      currentUserId,
                      _decodedToken!.safeName,
                      _decodedToken!.creatorId,
                      _decodedToken!.urls);
                  var task = Coven.join(access, _secretController.text);
                  await progressDialog(context, "Joining $name", task,
                      successMessage: "Added $name");
                  if (!mounted) return;
                  Navigator.pop(context);
                }
              : null,
          child: Text("Join ${_decodedToken!.safeName}"),
        )
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Join"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: shareIdSection,
          ),
        ),
      ),
    );
  }
}
