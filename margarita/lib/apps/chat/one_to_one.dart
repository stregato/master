import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/chat.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/woland/woland.dart';

class OneToOne extends StatefulWidget {
  const OneToOne({Key? key}) : super(key: key);

  @override
  State<OneToOne> createState() => _OneToOneState();
}

class _OneToOneState extends State<OneToOne> {
  @override
  Widget build(BuildContext context) {
    var community = ModalRoute.of(context)!.settings.arguments as Community;
    var safeName = "${community.name}/welcome";
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
                appBar: AppBar(title: Text("🗨 with $nick")),
                body: Chat(safeName, id),
              ),
            ),
          );
        },
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("One to One Chat"),
      ),
      body: ListView(
        children: items,
      ),
    );
  }
}
