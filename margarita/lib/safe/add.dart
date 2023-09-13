import 'dart:isolate';

import 'package:margarita/common/copy_field.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland_def.dart';

class Add extends StatefulWidget {
  const Add({super.key});

  @override
  State<Add> createState() => _AddState();
}

class _AddState extends State<Add> {
  String? _errorText;
  String _name = "";
  String _space = "";
  String _access = "";
  List<String> accessPrefixes = ['https://margarita.zone/a/', 'mg://a/'];
  final TextEditingController _linkController = TextEditingController();

  _AddState() {
    _linkController.addListener(() {
      var profile = Profile.current();
      var link = _linkController.text.trim();
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
      var name = "";
      var space = "";
      try {
        var d = decodeAccess(profile.identity, _access);
        name = d.safeName.substring(0, d.safeName.lastIndexOf('/'));
        space = d.safeName.substring(name.length + 1);

        testOpen(_access);
        setState(() {
          _errorText = null;
          _name = name;
          _space = space;
        });
      } catch (e) {
        setState(() {
          _errorText =
              name.isEmpty ? "invalid link" : "cannot access $name: $e";
          _name = name;
          _space = space;
        });
      }
    });
  }

  static testOpen(String access) {
    Isolate.run(
        () => openSafe(Profile.current().identity, access, OpenOptions()));
  }

  @override
  Widget build(BuildContext context) {
    var profile = Profile.current();

    var currentUserId = profile.identity.id;
    var desktopLink = 'mg://i/$currentUserId/${profile.identity.nick}';
    var mobileLink =
        'https://margarita.zone/i/$currentUserId/${profile.identity.nick}';

    var shareIdSection = <Widget>[
      const Text(
          "Below is your id in qrcode (mobile device) and Link (desktop). "
          " Share with your peer to get an invite. "),
      const SizedBox(height: 20),
      CopyField("Mobile", mobileLink),
      const SizedBox(height: 20),
      CopyField("Desktop", desktopLink),
      const SizedBox(height: 40),
      const Text(
          "Once you get a link, paste it below and click on 'Join' to join the community"),
      const SizedBox(height: 20),
      TextField(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: 'Access Link',
          errorText: _errorText,
        ),
        controller: _linkController,
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: (_name.isNotEmpty && _errorText == null)
            ? () {
                var p = Profile.current();
                var c = p.communities
                    .putIfAbsent(_name, () => Community(_name, {}));
                c.spaces[_space] = _access;
                p.save();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: Colors.green,
                    content: Text("Joined $_name")));
              }
            : null,
        child: Text("Join $_space@$_name"),
      )
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Join"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          children: shareIdSection,
        ),
      ),
    );
  }
}
