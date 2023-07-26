import 'dart:typed_data';

import 'package:margarita/common/image.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/gen/assets.gen.dart';
import 'package:margarita/navigation/bar.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;

class Setup extends StatefulWidget {
  const Setup({Key? key}) : super(key: key);

  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  Image _avatarImage = Assets.images.icons8Witch.image(width: 96);
  late Uint8List _avatar;
  var nick = TextEditingController();
  var email = TextEditingController();
  bool isSubmitButtonDisabled = true;

  _SetupState() {
    rootBundle
        .load("assets/images/icons8-witch.png")
        .then((value) => _avatar = value.buffer.asUint8List());
    nick.addListener(() {
      setState(() {
        isSubmitButtonDisabled = nick.text.isEmpty;
      });
    });
  }

  _selectAvatar() async {
    XFile? xfile = await pickImage();
    if (xfile == null) return;

    var bytes = await xfile.readAsBytes();
    setState(() {
      _avatarImage = Image.memory(
        bytes,
        width: 96,
      );
      _avatar = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(14)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome"),
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(children: [
                    const Text(
                      'Welcome to Margarita.\nThis is the first time you run Margarita on this device: '
                      'create a profile or import an existing one.',
                      style: TextStyle(fontSize: 18.0),
                      maxLines: 5,
                      textAlign: TextAlign
                          .justify, // Set the maximum number of lines to 3
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Your nick *',
                          hintText: 'The nick you will be known by. Required.'),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: nick,
                    ),
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: 'Your email'),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: email,
                    ),
                  ]),
                ),
                const SizedBox(
                  width: 8,
                ),
                InkWell(
                  onTap: _selectAvatar,
                  child: _avatarImage,
                )
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            ElevatedButton.icon(
                style: buttonStyle,
                label: const Text("Create"),
                icon: const Icon(Icons.save),
                onPressed: isSubmitButtonDisabled
                    ? null
                    : () {
                        currentProfile = Profile();
                        currentProfile.identity = newIdentity(nick.text);
                        currentProfile.identity.avatar = _avatar;
                        currentProfile.identity.email = email.text;
                        setIdentity(currentProfile.identity);
                        profiles.add(currentProfile);

                        setConfig("margarita", "profiles",
                            SIB.fromBytes(writeProfiles(profiles)));
                        Navigator.pushReplacementNamed(context, "/");
                      }),
          ],
        ),
      ),
      bottomNavigationBar: const MainNavigationBar(null),
    );
  }
}
