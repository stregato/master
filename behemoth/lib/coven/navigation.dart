import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

const welcomeSpace = 'lounge';

class Navigation extends StatefulWidget {
  final Coven coven;
  final String room;
  const Navigation(this.coven, this.room, {Key? key}) : super(key: key);

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  bool _private = false;

  @override
  void initState() {
    super.initState();
    widget.coven.getLoungeSync()!.syncUsers().then((value) => setState(() {}));
  }

  List<Widget> _getWaiters() {
    var cards = <Widget>[];
    var lounge = widget.coven.getLoungeSync()!;
    var users = lounge.getUsersSync();
    var currentId = widget.coven.identity.id;

    if (users[currentId]! & permissionAdmin == 0) {
      return cards;
    }

    for (var entry in users.entries) {
      var id = entry.key;
      var permission = entry.value;
      var accessPermission = permissionRead + permissionWrite + permissionAdmin;

      if (permission == permissionWait) {
        var identity = getCachedIdentity(id);
        cards.add(Card(
          child: PlatformListTile(
            title: Row(
              children: [
                PlatformText("😴 ${identity.nick} waiting"),
                const Spacer(),
                PlatformElevatedButton(
                  onPressed: () {
                    lounge.setUsers({id: accessPermission}, SetUsersOptions());
                    setState(() {});
                  },
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(2),
                    ),
                  ),
                  child: PlatformText(
                    'Approve',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                PlatformElevatedButton(
                  onPressed: () {
                    lounge.setUsers({id: 0}, SetUsersOptions());
                    setState(() {});
                  },
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(2),
                    ),
                  ),
                  child: PlatformText(
                    'Reject',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ));
      }
    }
    return cards;
  }

  List<Widget> _getActions() {
    return [
      if (widget.room != "lounge")
        Card(
          child: PlatformListTile(
            leading: const Icon(Icons.person_add),
            title: const Text("Add a person"),
            subtitle: Text(
                "Add an initiated in ${widget.coven.name} to the room ${widget.room}"),
            onTap: () async {
              await Navigator.pushNamed(context, "/invite", arguments: {
                "safe": widget.coven.getLoungeSync()!,
              });
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ),
      Card(
        child: PlatformListTile(
          leading: const Icon(Icons.add),
          title: const Text("New room"),
          onTap: () async {
            await Navigator.pushNamed(context, '/coven/create',
                arguments: {"coven": widget.coven});
            setState(() {});
          },
        ),
      ),
    ];
  }

  List<Widget> _getRooms() {
    var coven = widget.coven;
    var cards = <Widget>[];

    for (var room in coven.rooms.keys) {
      if (room == widget.room) {
        continue;
      }

      var safeName = "${coven.name}/$room";
      var trailing = Coven.safes.containsKey(safeName)
          ? const Icon(Icons.lock_open)
          : const Icon(Icons.lock);

      cards.add(
        Card(
          child: PlatformListTile(
            title: Text(room),
            subtitle: Text(coven.name),
            trailing: trailing,
            onTap: () async {
              await Navigator.pushReplacementNamed(context, "/coven/room",
                  arguments: {
                    "room": room,
                    "coven": widget.coven,
                  });
            },
          ),
        ),
      );
    }
    return cards;
  }

  Widget _getSettings() {
    return Card(
      child: PlatformListTile(
        leading: const Icon(Icons.settings),
        title: const Text("Settings"),
        onTap: () async {
          await Navigator.pushNamed(context, "/coven/settings", arguments: {
            "coven": widget.coven,
          });
        },
      ),
    );
  }

  Widget _getPrivates() {
    var cards = <Widget>[];
    var coven = widget.coven;
    var lounge = coven.getLoungeSync();
    var users = lounge!.getUsersSync();

    cards.add(Card(
      child: PlatformListTile(
        leading: const Icon(Icons.arrow_back),
        title: const Text("Back to rooms"),
        onTap: () => setState(() {
          _private = false;
        }),
      ),
    ));

    for (var id in users.keys) {
      if (id == coven.identity.id) {
        continue;
      }
      var identity = getCachedIdentity(id);
      if (identity.nick == "") {
        continue;
      }

      cards.add(Card(
        child: PlatformListTile(
          title: Text(identity.nick),
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlatformScaffold(
                  appBar: PlatformAppBar(
                    title: Text("🕵 with ${identity.nick}"),
                    backgroundColor: Colors.red.shade200,
                  ),
                  backgroundColor: Colors.red.shade300,
                  body: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Chat(lounge, id)),
                ),
              ),
            );
          },
        ),
      ));
    }
    return ListView(
      children: cards,
    );
  }

  Widget _getPrivate() {
    return Card(
      child: PlatformListTile(
        leading: const Icon(Icons.vpn_key),
        title: const Text("Private"),
        subtitle: const Text("Talk with people in private"),
        onTap: () => setState(() {
          _private = true;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: _private
          ? _getPrivates()
          : ListView(
              children: [
                ..._getWaiters(),
                _getPrivate(),
                ..._getActions(),
                ..._getRooms(),
                _getSettings(),
              ],
            ),
    );
  }
}
