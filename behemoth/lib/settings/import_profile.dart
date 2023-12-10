import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/types.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class ImportProfile extends StatefulWidget {
  const ImportProfile({super.key});

  @override
  State<ImportProfile> createState() => _ImportProfileState();
}

class _ImportProfileState extends State<ImportProfile> {
  final _privateKeyController = TextEditingController();
  int _counter = 5;
  Identity? _identity;
  late Identity _current;

  _ImportProfileState() {
    _privateKeyController.addListener(() {
      var identity = _parsePrivateIdUrl(_privateKeyController.text);
      if (identity != _identity) {
        setState(() {
          _identity = identity;
        });
      }
    });
  }

  // void _updateIdentity() {
  //   if (_counter > 0) {
  //     setState(() {
  //       _counter--;
  //     });
  //     showPlatformSnackbar(context,
  //         'Warning, by changing your identity you lose access to your covens. Click again to proceed',
  //         backgroundColor: Colors.orange);
  //   } else {
  //     var profile = Profile();
  //     profile.identity = _identity!;
  //     profile.identity.avatar = _current.avatar;
  //     profile.identity.email = _current.email;
  //     profile.save();
  //     Navigator.pushReplacementNamed(context, "/");

  //     showPlatformSnackbar(context, 'Identity updated',
  //         backgroundColor: Colors.green);
  //     // Assuming this widget is part of a navigation stack, pop the current screen
  //     Navigator.of(context).pop();
  //   }
  // }

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
    var profile = ModalRoute.of(context)!.settings.arguments as Profile;

    var covens = profile.covens.keys.map((c) {
      return Card(
        child: PlatformListTile(
          title: PlatformText(c),
        ),
      );
    }).toList();

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Import Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                const Text(
                  'When you import a profile, all your covens will be replaced!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          PlatformTextFormField(
                            material: (context, platform) =>
                                MaterialTextFormFieldData(
                              decoration: const InputDecoration(
                                labelText: 'Nick',
                              ),
                            ),
                            cupertino: (context, platform) =>
                                CupertinoTextFormFieldData(
                              placeholder: 'Nick',
                            ),
                            initialValue: profile.identity.nick,
                            readOnly: true,
                          ),
                          PlatformTextFormField(
                            material: (context, platform) =>
                                MaterialTextFormFieldData(
                              decoration: const InputDecoration(
                                labelText: 'Id',
                              ),
                            ),
                            cupertino: (context, platform) =>
                                CupertinoTextFormFieldData(
                              placeholder: 'Id',
                            ),
                            initialValue: profile.identity.id,
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      child: Image.memory(
                        profile.identity.avatar,
                        width: 128,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PlatformText("Covens"),
                ListView(
                  shrinkWrap: true,
                  children: covens,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_counter > 0) {
                      setState(() {
                        _counter--;
                      });
                      showPlatformSnackbar(context,
                          'Warning, by changing your profile you lose access to your covens. Click again to proceed',
                          backgroundColor: Colors.orange);
                    } else {
                      profile.save();
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Import ($_counter)'),
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
