import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/profile.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Privates extends StatefulWidget {
  const Privates({Key? key}) : super(key: key);

  @override
  State<Privates> createState() => _PrivatesState();
}

class _PrivatesState extends State<Privates> {
  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    var coven = args['coven'] as Coven;
    var items = coven.safe
        .getUsersSync()
        .entries
        .where(
            (e) => e.key != coven.safe.currentUser.id && e.value & reader > 0)
        .map((e) {
      var id = e.key;
      var identity = getCachedIdentity(id);
      var nick = identity.nick.isNotEmpty ? identity.nick : id;
      return ListTile(
        title: Text(nick),
        onTap: () {
          // Navigate to a new page when an item is tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlatformScaffold(
                appBar: PlatformAppBar(title: Text("🕵 with $nick")),
                body: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Chat(coven, "lounge", id)),
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
