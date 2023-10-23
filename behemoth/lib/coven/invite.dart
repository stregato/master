import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/copy_field.dart';

class Invite extends StatefulWidget {
  const Invite({super.key});

  @override
  State<Invite> createState() => _InviteState();
}

class _InviteState extends State<Invite> {
  String? _errorText;
  String _access = "";
  String _nick = "";
  String _id = "";
  bool _anonymousInvite = false;

  final TextEditingController _idController = TextEditingController();
  late Safe _safe;
  late String _covenName;
  late String _roomName;

  _InviteState() {
    _idController.addListener(() {
      if (_idController.text.isNotEmpty) {
        _processUrl(_idController.text);
      } else if (_errorText != null) {
        setState(() {
          _errorText = null;
        });
      }
    });
  }

  _processUrl(String url) {
    var args = url.startsWith("https://behemoth.cool/i/")
        ? url.substring("https://behemoth.cool/i/".length).split("/")
        : url.startsWith("mg://i/")
            ? url.substring("mg://i/".length).split("/")
            : [];

    switch (args.length) {
      case 0:
        setState(() {
          _errorText = "invalid id link";
        });
        break;
      case 1:
        setState(() {
          _errorText = "missing nick in link";
        });
        break;
      case 2:
        setState(() {
          _id = args[0];
          _nick = args[1];
        });
        break;
    }
  }

  _add() async {
    var profile = Profile.current();
    await _safe.setUsers(
        {_id: permissionRead + permissionWrite + permissionAdmin},
        SetUsersOptions());
    var d = decodeAccess(profile.identity, _safe.access);
    setState(() {
      _access =
          encodeAccess(_id, _safe.name, d.creatorId, d.urls, aesKey: d.aesKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    _safe = ModalRoute.of(context)!.settings.arguments as Safe;
    var lastSlash = _safe.name.lastIndexOf("/");
    _roomName = _safe.name.substring(lastSlash + 1);
    _covenName = _safe.name.substring(0, lastSlash);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Invite to $_roomName@$_covenName"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: [
              const Text(
                "Scan the QR code or insert the link of the peer you want to invite",
                style: TextStyle(
                  fontSize: 16,
                  //fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                maxLines: 4,
                controller: _idController,
                decoration: InputDecoration(
                  labelText: 'Enter the link',
                  errorText: _errorText,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: const Text('Anonymous Invite'),
                value: _anonymousInvite,
                onChanged: (bool? value) {
                  setState(() {
                    _anonymousInvite = value!;
                    _id = "";
                    _nick = "";
                  });
                },
              ),
              const SizedBox(height: 40),
              if (_id.isNotEmpty && _access.isEmpty)
                Container(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: ElevatedButton(
                    onPressed: _add,
                    child: Text("Add ${_nick.isEmpty ? _id : _nick}"),
                  ),
                ),
              if (_access.isNotEmpty)
                Column(
                  children: [
                    const Text("Share one of the below links with the peer"),
                    const SizedBox(height: 40),
                    CopyField("Mobile", "https://behemoth.cool/a/$_access"),
                    const SizedBox(height: 40),
                    CopyField("Desktop", "mg://a/$_access"),
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
