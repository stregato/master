import 'dart:isolate';

import 'package:margarita/common/complete_identity.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:flutter/material.dart';

class CreateZoneView extends StatefulWidget {
  const CreateZoneView({super.key});

  @override
  State<CreateZoneView> createState() => _CreateZoneViewState();
}

const urlHint = "Enter a supported URL and click +";
const validSchemas = ["s3", "sftp", "file"];
const availableApps = ["chat", "library", "gallery"];

class CreateZoneViewArgs {
  String portalName;
  CreateZoneViewArgs(this.portalName);
}

class _CreateZoneViewState extends State<CreateZoneView> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  final List<Identity> _users = [];

  bool _validConfig() {
    return name.isNotEmpty && _users.isNotEmpty;
  }

  _createZone(
      String portalName, String zoneName, Map<String, Permission> users) {
    Isolate.run(() {
      createZone(portalName, zoneName, users);
    });
  }

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as CreateZoneViewArgs;
    var identities = getIdentities(args.portalName);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Zone"),
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
                                _createZone(args.portalName, name, {
                                  for (var e in _users) e.id: permissionUser
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
