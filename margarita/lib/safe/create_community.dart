import 'dart:isolate';

import 'package:margarita/common/profile.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/safe/addstorage.dart';
import 'package:margarita/safe/community.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:flutter/material.dart';

class CreateCommunity extends StatefulWidget {
  const CreateCommunity({super.key});

  @override
  State<CreateCommunity> createState() => _CreateCommunityState();
}

const urlHint = "Enter a supported URL and click +";
const validSchemas = ["s3", "sftp", "file"];

class _CreateCommunityState extends State<CreateCommunity> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  List<String> urls = [];

  bool _validConfig() {
    return name.isNotEmpty && urls.isNotEmpty;
  }

  _createCommunity(String name, List<String> urls) {
    return Isolate.run<Profile>(() {
      var p = Profile.current();
      var token = encodeAccess(
          p.identity.id, "$name/$welcomeSpace", p.identity.id, "", urls);
      createSafe(p.identity, token, CreateOptions());
      p.communities[name] = Community(name, {welcomeSpace: token});
      p.save();
      return p;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Community"),
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
                                _createCommunity(name, urls),
                                successMessage:
                                    "Congrats! You successfully created $name",
                                errorMessage: "Creation failed");
                            // ignore: use_build_context_synchronously
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
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
