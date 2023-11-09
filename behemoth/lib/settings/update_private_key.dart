import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/qrcode_scan_button.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/types.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class UpdatePrivateKey extends StatefulWidget {
  const UpdatePrivateKey({super.key});

  @override
  State<UpdatePrivateKey> createState() => _UpdatePrivateKeyState();
}

class _UpdatePrivateKeyState extends State<UpdatePrivateKey> {
  final _privateKeyController = TextEditingController();
  int _counter = 5;
  Identity? _identity;
  late Identity _current;

  _UpdatePrivateKeyState() {
    _privateKeyController.addListener(() {
      var identity = _parsePrivateIdUrl(_privateKeyController.text);
      if (identity != _identity) {
        setState(() {
          _identity = identity;
        });
      }
    });
  }

  void _updateIdentity() {
    if (_counter > 0) {
      setState(() {
        _counter--;
      });
      showPlatformSnackbar(context,
          'Warning, by changing your identity you lose access to your covens. Click again to proceed',
          backgroundColor: Colors.orange);
    } else {
      var profile = Profile();
      profile.identity = _identity!;
      profile.identity.avatar = _current.avatar;
      profile.identity.email = _current.email;
      profile.save();
      Navigator.pushReplacementNamed(context, "/");

      showPlatformSnackbar(context, 'Identity updated',
          backgroundColor: Colors.green);
      // Assuming this widget is part of a navigation stack, pop the current screen
      Navigator.of(context).pop();
    }
  }

  Identity? _parsePrivateIdUrl(String text) {
    try {
      var uri = Uri.parse(text);
      if (uri.scheme != 'https' ||
          uri.host != 'behemoth.rocks' ||
          !uri.path.startsWith('/p/')) return null;
      var key = uri.path.substring('/p/'.length);

      return newIdentityFromId(_current.nick, key);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _current = ModalRoute.of(context)!.settings.arguments as Identity;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Update Private Key'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                const Text(
                  'When you update your private key, you will lose access to your covens. Be careful!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
                Row(
                  children: [
                    Expanded(
                      child: PlatformTextFormField(
                        material: (context, platform) =>
                            MaterialTextFormFieldData(
                          decoration: const InputDecoration(
                            labelText: 'Enter your new private key',
                          ),
                        ),
                        cupertino: (context, platform) =>
                            CupertinoTextFormFieldData(
                          placeholder: 'Enter your new private key',
                        ),
                        controller: _privateKeyController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                      ),
                    ),
                    QRCodeScannerButton(
                      onDetect: (codes, image) {
                        _privateKeyController.text = codes.first;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _identity != null ? _updateIdentity : null,
                  child: Text('Update ($_counter)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _privateKeyController.dispose();
    super.dispose();
  }
}
