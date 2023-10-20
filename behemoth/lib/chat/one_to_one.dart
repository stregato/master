import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/profile.dart';

class Privates extends StatefulWidget {
  const Privates({Key? key}) : super(key: key);

  @override
  State<Privates> createState() => _PrivatesState();
}

class _PrivatesState extends State<Privates> {
  @override
  Widget build(BuildContext context) {
    var safe = ModalRoute.of(context)!.settings.arguments as Safe;
    var items = safe
        .getUsersSync()
        .keys
        .where((id) => id != safe.currentUser.id)
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
                    padding: const EdgeInsets.all(2.0), child: Chat(safe, id)),
              ),
            ),
          );
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
