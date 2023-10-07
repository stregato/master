import 'package:flutter/material.dart';
import 'package:behemoth/apps/chat/chat.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';

class Privates extends StatefulWidget {
  const Privates({Key? key}) : super(key: key);

  @override
  State<Privates> createState() => _PrivatesState();
}

class _PrivatesState extends State<Privates> {
  @override
  Widget build(BuildContext context) {
    var safeName = ModalRoute.of(context)!.settings.arguments as String;
    var users = getUsers(safeName);
    var items = users.keys
//        .where((id) => id != profile.identity.id)
        .map((id) {
      var identity = getCachedIdentity(id);
      var nick = identity.nick.isNotEmpty ? identity.nick : id;
      return ListTile(
        title: Text(nick),
        onTap: () {
          // Navigate to a new page when an item is tapped
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: Text("🕵 with $nick")),
                  body: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Column(children: [Chat(safeName, id)]),
                  ),
                ),
              ));
        },
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Privates"),
      ),
      body: ListView(
        children: items,
      ),
    );
  }
}
