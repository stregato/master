import 'dart:isolate';

import 'package:margarita/common/profile.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/safe/addstorage.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:flutter/material.dart';

class CreatePortalView extends StatefulWidget {
  const CreatePortalView({super.key});

  @override
  State<CreatePortalView> createState() => _CreatePortalViewState();
}

const urlHint = "Enter a supported URL and click +";
const validSchemas = ["s3", "sftp", "file"];

class _CreatePortalViewState extends State<CreatePortalView> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  List<String> urls = [];

  bool _validConfig() {
    return name.isNotEmpty && urls.isNotEmpty;
  }

  _createPortal(String name, List<String> urls) {
    var ps = profiles;
    var p = currentProfile;
    var token = encodeToken(p.identity.id, name, "", urls);
    return Isolate.run<Portal>(() {
      var portal = openPortal(p.identity, token, OpenOptions());
      p.portals[name] = token;
      setConfig("margarita", "profiles", SIB.fromBytes(writeProfiles(ps)));
      createZone(portal.name, "square", {});
      return portal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Portal"),
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
                const Text(
                    "Enter a name and at least a storage, i.e. sftp or s3"),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    return null;
                  },
                  onChanged: (val) => setState(() => name = val),
                ),
                Row(
                  children: [
                    const Text(
                      "Storages",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (context) => const AddStorage()))
                            .then((value) {
                          if (value is Storage) {
                            setState(() {
                              urls.add(value.url);
                            });
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                    )
                  ],
                ),
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: urls.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.share),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            urls.removeAt(index);
                          });
                        }),
                    title: Text(urls[index]),
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
                                _createPortal(name, urls),
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
