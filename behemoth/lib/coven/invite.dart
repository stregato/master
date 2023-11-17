import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/qrcode_scan_button.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/copy_field.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

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
  String? _url;
  bool _anonymousInvite = false;
  List<Widget> _selection = <Widget>[];

  final TextEditingController _idController = TextEditingController();
  Safe? _safe;
  Coven? _coven;

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
    var args = url.startsWith("https://behemoth.rocks/i/")
        ? url.substring("https://behemoth.rocks/i/".length).split("/")
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
    if (_safe == null) {
      return;
    }

    var profile = Profile.current();
    await _safe!.setUsers(
        {_id: permissionRead + permissionWrite + permissionAdmin},
        SetUsersOptions());
    var d = decodeAccess(profile.identity, _safe!.access);
    setState(() {
      _access =
          encodeAccess(_id, _safe!.name, d.creatorId, d.urls, aesKey: d.aesKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;

    _safe ??= args['safe'];
    _url ??= args['url'];
    if (_url != null) {
      _processUrl(_url!);
    }

    if (_safe == null || _selection.isNotEmpty) {
      var covens = Profile.current().covens.values;
      _selection = covens.map((coven) {
        return Card(
          child: PlatformListTile(
            trailing:
                _coven?.name == coven.name ? const Icon(Icons.check) : null,
            title: PlatformText(coven.name),
            onTap: () async {
              var safe = await coven.getLounge();
              setState(() {
                _safe = safe;
                _coven = coven;
              });
            },
          ),
        );
      }).toList();
    }

    // var lastSlash = _safe.name.lastIndexOf("/");
    // _roomName = _safe.name.substring(lastSlash + 1);
    // _covenName = _safe.name.substring(0, lastSlash);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title:
            Text(_safe != null ? "Invite to ${_safe!.prettyName}" : "Invite"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: [
              if (_selection.isNotEmpty)
                Column(
                  children: [
                    const Text("Select the coven you want to invite to"),
                    const SizedBox(height: 20),
                    ListView(
                      shrinkWrap: true,
                      children: _selection,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              const Text(
                "Scan the QR code or insert the link of the peer you want to invite",
                style: TextStyle(
                  fontSize: 16,
                  //fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _url == null
                        ? PlatformTextFormField(
                            maxLines: 4,
                            controller: _idController,
                            material: (_, __) => MaterialTextFormFieldData(
                              decoration: InputDecoration(
                                labelText: 'Enter the link',
                                errorText: _errorText,
                              ),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                            ),
                            cupertino: (_, __) => CupertinoTextFormFieldData(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              placeholder: 'Enter the link',
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          )
                        : Text(_url!),
                  ),
                  QRCodeScannerButton(onDetect: (values, bytes) {
                    _idController.text = values.first;
                  }),
                ],
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
              if (_id.isNotEmpty && _access.isEmpty && _safe != null)
                Container(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: PlatformElevatedButton(
                    onPressed: _add,
                    child: Text(
                        "Add ${_nick.isEmpty ? _id : _nick} to ${_safe?.prettyName}"),
                  ),
                ),
              if (_access.isNotEmpty)
                Column(
                  children: [
                    const Text("Share one of the below links with the peer"),
                    const SizedBox(height: 40),
                    CopyField("Mobile", "https://behemoth.rocks/a/$_access"),
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
