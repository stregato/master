import 'package:flutter/material.dart';

import 'package:behemoth/woland/woland.dart';

var currentPanelIdx = <String, int>{};

class People extends StatefulWidget {
  final String safeName;
  const People(this.safeName, {Key? key}) : super(key: key);

  @override
  State<People> createState() => _PeopleState();
}

class _PeopleState extends State<People> {
  @override
  Widget build(BuildContext context) {
    var safeName = widget.safeName;

    var users = getUsers(safeName);
    var items = users.entries.map((e) {
      var identity = getIdentity(e.key);
      var nick = identity.nick;

      return ListTile(
        leading: Image.memory(identity.avatar, width: 32, height: 32),
        title: Text(nick),
        subtitle: Text("${e.key.substring(0, 16)}..."),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            setState(() {
              users.remove(e.key);
            });
          },
        ),
      );
    }).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          children: [
            const SizedBox(height: 20.0),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center horizontally
              children: [
                Expanded(
                  child: safeName.endsWith("/lounge")
                      ? ElevatedButton(
                          child: const Text("Invite"),
                          onPressed: () {
                            Navigator.pushNamed(context, "/invite",
                                arguments: safeName);
                          })
                      : ElevatedButton(
                          child: const Text("Add"),
                          onPressed: () {
                            Navigator.pushNamed(context, "/coven/add_person",
                                arguments: safeName);
                          }),
                )
              ],
            ),
            const SizedBox(height: 20.0),
            ListView(
              shrinkWrap: true,
              children: items,
            ),
          ],
        ),
      ),
    );
  }
}
