import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/profile.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Privates extends StatefulWidget {
  const Privates({Key? key}) : super(key: key);

  @override
  State<Privates> createState() => _PrivatesState();

  static openChat(BuildContext context, Coven coven, String id) {
    var identity = getCachedIdentity(id);
    var nick = identity.nick.isNotEmpty ? identity.nick : id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlatformScaffold(
          appBar: PlatformAppBar(
            leading: const Icon(Icons.vpn_key),
            title: Text(nick),
          ),
          body: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Chat(coven, "privates", id)),
          bottomNavBar: PlatformNavBar(
              currentIndex: 0,
              itemChanged: (index) {
                Navigator.pop(context);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.arrow_back),
                  label: "Back",
                ),
              ]),
        ),
      ),
    );
  }
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
          Privates.openChat(context, coven, id);
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
