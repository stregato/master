import 'dart:isolate';

import 'package:behemoth/common/complete_identity.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/coven/coven.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/woland_def.dart';
import 'package:flutter/material.dart';

class CreateRoom extends StatefulWidget {
  const CreateRoom({super.key});

  @override
  State<CreateRoom> createState() => _CreateRoomState();
}

// const urlHint = "Enter a supported URL and click +";
// const validSchemas = ["s3", "sftp", "file"];
// const availableApps = ["chat", "library", "gallery"];

class CreateRoomViewArgs {
  String safeName;
  CreateRoomViewArgs(this.safeName);
}

class _CreateRoomState extends State<CreateRoom> {
  final _formKey = GlobalKey<FormState>();
  bool _duo = false;

  String name = "";
  final List<Identity> _users = [];

  bool _validConfig() {
    return name.isNotEmpty && _users.isNotEmpty;
  }

  _createRoom(Coven coven, String name, Map<String, Permission> users) {
    var p = Profile.current();
    var currentId = p.identity;
    var token = coven.rooms[welcomeSpace]!;
    var decodedToken = decodeAccess(currentId, token);
    if (_duo) {
      var ids = [currentId.id, _users[0].id];
      ids.sort();
      name = "${ids[0]}.${ids[1]}";
    }
    var safeName = "${coven.name}/$name";
    token = encodeAccess(currentId.id, safeName, currentId.id,
        decodedToken.aesKey, decodedToken.urls);

    return Isolate.run<void>(() {
      createSafe(currentId, token, CreateOptions());
      coven.rooms[name] = token;
      p.covens[coven.name] = coven;
      p.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    var coven = ModalRoute.of(context)!.settings.arguments as Coven;
    var loungeAccess = coven.rooms[welcomeSpace]!;
    openSafe(Profile.current().identity, loungeAccess, OpenOptions());
    var identities = getIdentities("${coven.name}/$welcomeSpace");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Room"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Builder(
          builder: (context) => Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row(
                //   children: [
                //     const Text("1 to 1"),
                //     const Spacer(),
                //     Switch(
                //         value: _duo,
                //         onChanged: (val) {
                //           setState(() {
                //             _duo = val;
                //           });
                //         }),
                //   ],
                // ),
                if (!_duo)
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged:
                        _duo ? null : (val) => setState(() => name = val),
                  ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  "People",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                AutocompleteIdentity(
                  identities: identities
                      .where((element) => _users.contains(element) == false)
                      .toList(),
                  onSelect: (identity) {
                    setState(() {
                      if (_duo) {
                        _users.clear();
                        setState(() {
                          name = "1-to-1 with ${identity.nick}";
                        });
                      }
                      if (_users.contains(identity) == false) {
                        _users.add(identity);
                      }
                    });
                  },
                ),
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.share),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _users.removeAt(index);
                          });
                        }),
                    title: Text(_users[index].nick),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _validConfig()
                        ? () async {
                            await progressDialog(
                                context,
                                "opening portal, please wait",
                                _createRoom(coven, name, {
                                  for (var e in _users) e.id: permissionRead
                                }).then(() => Navigator.pop(context)),
                                successMessage:
                                    "Congrats! You successfully created $name",
                                errorMessage: "Creation failed");
                          }
                        : null,
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
