import 'package:behemoth/common/complete_identity.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/coven/coven.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class CreateRoom extends StatefulWidget {
  const CreateRoom({super.key});

  @override
  State<CreateRoom> createState() => _CreateRoomState();
}

// const urlHint = "Enter a supported URL and click +";
// const validSchemas = ["s3", "sftp", "file"];
// const availableApps = ["chat", "content", "gallery"];

class CreateRoomViewArgs {
  String safeName;
  CreateRoomViewArgs(this.safeName);
}

class _CreateRoomState extends State<CreateRoom> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  final List<Identity> _users = [];

  bool _validConfig() {
    return name.isNotEmpty;
  }

  _createRoom(Coven coven, String name, Map<String, Permission> users) async {
    var p = Profile.current();
    var currentId = p.identity;
    var token = coven.rooms[welcomeSpace]!;
    var decodedToken = decodeAccess(currentId, token);
    var safeName = "${coven.name}/$name";
    token = encodeAccess(
        currentId.id, safeName, currentId.id, decodedToken.urls,
        aesKey: decodedToken.aesKey);

    await Safe.create(currentId, token, users, CreateOptions());
    coven.rooms[name] = token;
    p.covens[coven.name] = coven;
    p.save();
  }

  @override
  Widget build(BuildContext context) {
    var coven = ModalRoute.of(context)!.settings.arguments as Coven;
    var users = coven.getLoungeSync()!.getUsersSync();
    var identities = users.keys.map((id) => getCachedIdentity(id)).toList();

    return PlatformScaffold(
      appBar: PlatformAppBar(
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
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (val) => setState(() => name = val),
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
                    trailing: PlatformIconButton(
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
                  child: PlatformElevatedButton(
                    onPressed: _validConfig()
                        ? () async {
                            await progressDialog(
                                context,
                                "opening portal, please wait",
                                _createRoom(coven, name, {
                                  for (var e in _users) e.id: permissionRead
                                }),
                                successMessage:
                                    "Congrats! You successfully created $name",
                                errorMessage: "Creation failed");
                            if (!mounted) return;
                            Navigator.pop(context);
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
