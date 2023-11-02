import 'package:behemoth/common/copy_field.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Add extends StatefulWidget {
  const Add({super.key});

  @override
  State<Add> createState() => _AddState();
}

class _AddState extends State<Add> {
  String? _errorText;
  String _name = "";
  String _access = "";
  List<String> accessPrefixes = ['https://behemoth.space/a/', 'mg://a/'];
  final TextEditingController _linkController = TextEditingController();

  _AddState() {
    _linkController.addListener(() async {
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
      try {
        var d = decodeAccess(Profile.current().identity, _access);
        setState(() {
          _errorText = null;
          _name = Safe.pretty(d.safeName);
        });
      } catch (e) {
        setState(() {
          _errorText =
              name.isEmpty ? "invalid link" : "cannot access $name: $e";
          _name = name;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var profile = Profile.current();

    var currentUserId = profile.identity.id;
    var desktopLink = 'bm://i/$currentUserId/${profile.identity.nick}';
    var mobileLink =
        'https://behemoth.space/i/$currentUserId/${profile.identity.nick}';

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
      PlatformTextField(
        material: (context, platform) => MaterialTextFieldData(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Access Link',
            errorText: _errorText,
          ),
        ),
        controller: _linkController,
      ),
      const SizedBox(height: 20),
      PlatformElevatedButton(
        onPressed: (_name.isNotEmpty && _errorText == null)
            ? () async {
                var task = Coven.join(_access);
                await progressDialog(context, "Joining $_name", task,
                    successMessage: "Joined $_name",
                    errorMessage: "Failed to join $_name");
                if (!mounted) return;
                Navigator.pop(context);
              }
            : null,
        child: Text("Join $_name"),
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
