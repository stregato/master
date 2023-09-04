import 'dart:isolate';

import 'package:margarita/common/complete_identity.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/safe/community.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:flutter/material.dart';

class CreateSpace extends StatefulWidget {
  const CreateSpace({super.key});

  @override
  State<CreateSpace> createState() => _CreateSpaceState();
}

// const urlHint = "Enter a supported URL and click +";
// const validSchemas = ["s3", "sftp", "file"];
// const availableApps = ["chat", "library", "gallery"];

class CreateZoneViewArgs {
  String safeName;
  CreateZoneViewArgs(this.safeName);
}

class _CreateSpaceState extends State<CreateSpace> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  final List<Identity> _users = [];

  bool _validConfig() {
    return name.isNotEmpty && _users.isNotEmpty;
  }

  _createSpace(
      Community community, String name, Map<String, Permission> users) {
    return Isolate.run<Profile>(() {
      var p = Profile.current();
      var currentId = p.identity;
      var token = community.spaces[welcomeSpace];
      var decodedToken = decodeAccess(currentId, token!);
      token = encodeAccess(currentId.id, "${community.name}/$name",
          currentId.id, decodedToken.aesKey, decodedToken.urls);

      createSafe(currentId, token, CreateOptions());
      community.spaces[name] = token;
      p.communities[community.name] = community;
      p.save();
      return p;
    });
  }

  @override
  Widget build(BuildContext context) {
    var community = ModalRoute.of(context)!.settings.arguments as Community;
    var identities = getIdentities("${community.name}/$welcomeSpace");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Space"),
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
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    return null;
                  },
                  onChanged: (val) => setState(() => name = val),
                ),
                const Text(
                  "Users",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                AutocompleteIdentity(
                  identities: identities
                      .where((element) => _users.contains(element) == false)
                      .toList(),
                  onSelect: (identity) {
                    setState(() {
                      _users.add(identity);
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
                const Text(
                  "Services",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
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
                                _createSpace(community, name, {
                                  for (var e in _users) e.id: permissionRead
                                }),
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
