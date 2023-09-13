import 'package:flutter/material.dart';
import 'package:margarita/common/copy_field.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';

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
  late Community _community;

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
    var args = url.startsWith("https://margarita.zone/i/")
        ? url.substring("https://margarita.zone/i/".length).split("/")
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

  _add() {
    var d =
        decodeAccess(Profile.current().identity, _community.spaces['welcome']!);
    if (_id.isNotEmpty) {
      setUsers(
          d.safeName,
          {_id: permissionRead + permissionWrite + permissionAdmin},
          SetUsersOptions());
    }
    setState(() {
      _access = encodeAccess(_id, d.safeName, d.creatorId, d.aesKey, d.urls);
    });
  }

  @override
  Widget build(BuildContext context) {
    _community = ModalRoute.of(context)!.settings.arguments as Community;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Invite to ${_community.name}"),
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
                maxLines: 2,
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
              if (_anonymousInvite || _id.isNotEmpty && _access.isEmpty)
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
                    CopyField("Mobile", "https://margarita.zone/a/$_access"),
                    const SizedBox(height: 40),
                    CopyField("Desktop", "mg://a/$_access"),
                  ],
                ),

              // MobileScanner(
              //   // fit: BoxFit.contain,
              //   onDetect: (capture) {
              //     final List<Barcode> barcodes = capture.barcodes;
              //     final Uint8List? image = capture.image;
              //     for (final barcode in barcodes) {
              //       debugPrint('Barcode found! ${barcode.rawValue}');
              //     }
              //   },
              // ),
            ],
          ),
        ),
      ),
//      bottomNavigationBar: MainNavigationBar(safeName),
    );
  }
}
