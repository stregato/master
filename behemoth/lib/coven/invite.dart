import 'package:behemoth/common/complete_identity.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/qrcode_scan_button.dart';
import 'package:behemoth/common/share_data.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Invite extends StatefulWidget {
  const Invite({super.key});

  @override
  State<Invite> createState() => _InviteState();
}

class _InviteState extends State<Invite> {
  String? _errorText;
  String _nick = "";
  String _id = "";
  bool _makeAdmin = false;
  bool _personal = false;
  String? _url;
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
          _personal = true;
        });
        break;
    }
  }

  void _add(BuildContext context) async {
    var permission = reader + standard;
    if (_makeAdmin) {
      permission += admin;
    }

    var task = _safe!.setUsers({_id: permission}, SetUsersOptions());

    await progressDialog(context, "Adding $_nick", task,
        successMessage: "Added $_nick to ${_safe!.name}",
        errorMessage: "Failed to add $_nick to ${_safe!.name}");
  }

  String _getAccessLink() {
    if (_coven == null || (_personal && _id.isEmpty)) {
      return "";
    }

    var identity = _coven!.identity;
    var d = decodeAccess(identity, _safe!.access);
    var access =
        encodeAccess(_id, _safe!.name, d.creatorId, d.urls, aesKey: d.aesKey);
    return "https://behemoth.rocks/a/$access";
  }

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    var identities = getAllIdentities();

    _coven ??= args['coven'];
    _safe ??= _coven?.safe;
    _url ??= args['url'];

    if (_url != null) {
      _processUrl(_url!);
    }
    var accessLink = _getAccessLink();

    if (_safe == null || _selection.isNotEmpty) {
      var covens = Profile.current.covens.values;
      _selection = covens.map((coven) {
        return Card(
          child: PlatformListTile(
            trailing:
                _coven?.name == coven.name ? const Icon(Icons.check) : null,
            title: PlatformText(coven.name),
            onTap: () async {
              var safe = await coven.open();
              setState(() {
                _safe = safe;
                _coven = coven;
              });
            },
          ),
        );
      }).toList();
    }

    var chooseCoven = Column(
      children: [
        const Text("Select the coven you want to invite to"),
        const SizedBox(height: 20),
        ListView(
          shrinkWrap: true,
          children: _selection,
        ),
        const SizedBox(height: 20),
      ],
    );

    var choosePersonal = Row(
      children: [
        Checkbox(
          value: _personal,
          onChanged: (value) {
            setState(() {
              _personal = value!;
              if (_personal == false) {
                _idController.text = "";
                _id = "";
                _nick = "";
              }
            });
          },
        ),
        const Text("Personal invite"),
      ],
    );

    var choosePeer = Column(
      children: [
        const Text(
          "Choose from a known peers or insert the link of the peer you want to invite",
          style: TextStyle(
            fontSize: 16,
            //fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        AutocompleteIdentity(
          identities: identities,
          onSelect: (identity) {
            setState(() {
              _idController.text =
                  "https://behemoth.rocks/i/${identity.id}/${identity.nick}";
            });
          },
        ),
        Row(
          children: [
            Expanded(
              child: PlatformTextFormField(
                maxLines: 4,
                controller: _idController,
                material: (_, __) => MaterialTextFormFieldData(
                  decoration: InputDecoration(
                    labelText: 'Or enter the link',
                    errorText: _errorText,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                cupertino: (_, __) => CupertinoTextFormFieldData(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  placeholder: 'Enter the link',
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ),
            QRCodeScannerButton(onDetect: (values, bytes) {
              _idController.text = values.first;
            }),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _makeAdmin,
              onChanged: _id.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _makeAdmin = value!;
                      });
                    },
            ),
            const Text("Make admin"),
          ],
        )
      ],
    );

    var addButton = Column(children: [
      Container(
        constraints: const BoxConstraints(minWidth: 200),
        child: PlatformElevatedButton(
          onPressed: () => _add(context),
          child: Text("Add ${_nick.isEmpty ? _id : _nick} to ${_safe?.name}"),
        ),
      ),
      const SizedBox(height: 20),
    ]);

    var nextHour = DateTime.now();
    nextHour = DateTime(
        nextHour.year, nextHour.month, nextHour.day, nextHour.hour, 59);
    var link = Column(
      children: [
        Text(_nick.isNotEmpty
            ? "Share the below link with $_nick"
            : "Below an anonymous link valid until ${nextHour.hour}:${nextHour.minute}"),
        ShareData("Access link", accessLink),
        //CopyField("Mobile", "https://behemoth.rocks/a/$_access"),
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_safe != null ? "Invite to ${_safe!.name}" : "Invite"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Column(
              children: [
                if (_selection.isNotEmpty) chooseCoven,
                choosePersonal,
                const SizedBox(height: 20),
                if (_personal) choosePeer,
                if (_id.isNotEmpty && _safe != null) addButton,
                if (accessLink.isNotEmpty) link
              ],
            ),
          ),
        ),
      ),
//      bottomNavigationBar: MainNavigationBar(safeName),
    );
  }
}
