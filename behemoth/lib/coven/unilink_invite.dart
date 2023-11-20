import 'dart:io';

import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class UnilinkInvite extends StatefulWidget {
  const UnilinkInvite({super.key});

  @override
  State<UnilinkInvite> createState() => _UnilinkInviteState();
}

class _UnilinkInviteState extends State<UnilinkInvite> {
  String _access = "";

  reencodeAccess(String access, Identity identity, String id) {
    var d = decodeAccess(identity, access);
    return encodeAccess(id, d.safeName, d.creatorId, d.urls, aesKey: d.aesKey);
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>;
    var id = args["id"] ?? "";
    var nick = args["nick"];

    var current = Profile.current();
    var desktopLink = 'mg://a/$_access';
    var mobileLink = 'https://behemoth.rocks/a/$_access';

    Widget shareButton;
    if (Platform.isAndroid || Platform.isIOS) {
      shareButton = ElevatedButton.icon(
          icon: const Icon(Icons.share),
          label: const Text("Share the Link"),
          onPressed: () {
            final box = context.findRenderObject() as RenderBox?;
            Share.share(mobileLink,
                subject: "Hi, this is access for ${nick ?? '?'}",
                sharePositionOrigin:
                    box!.localToGlobal(Offset.zero) & box.size);
          });
    } else {
      shareButton = ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text("Copy to the clipboard"),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: desktopLink)).then((_) {
              showPlatformSnackbar(context, "Link copied to clipboard",
                  backgroundColor: Colors.green);
            });
          });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Invite ${nick ?? '?'} to community"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: [
              if (_access.isEmpty)
                Column(
                  children: [
                    const Text("Choose the community"),
                    const SizedBox(height: 20),
                    ListView(
                      shrinkWrap: true,
                      children: current.covens.entries
                          .map(
                            (e) => Card(
                              child: ListTile(
                                  title: Text(e.key),
                                  onTap: () {
                                    setState(() {
                                      _access = reencodeAccess(
                                          e.value.rooms["lounge"]!,
                                          current.identity,
                                          id);
                                    });
                                  }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    QrImageView(
                      data: mobileLink,
                      version: QrVersions.auto,
                      size: 320,
                      gapless: false,
                    ),
                    const SizedBox(height: 20),
                    Text(desktopLink,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                            fontSize: 12)),
                    const SizedBox(height: 20),
                    shareButton,
                  ],
                ),
            ],
          ),
        ),
      ),
//      bottomNavigationBar: MainNavigationBar(safeName),
    );
  }
}
