import 'dart:typed_data';

import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path/path.dart';

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
  bool _invite = false;
  late Safe _safe;

  @override
  void initState() {
    super.initState();
    _safe = widget.coven.safe;
    Future.delayed(const Duration(milliseconds: 100), () {
      var id = widget.coven.identity.id;
      _safe.syncUsers().then((value) => setState(() {}));
      _safe.syncBucket("rooms/.invites/$id", SyncOptions());
    });
  }

  List<Widget> _getInitiates() {
    var cards = <Widget>[];
    var initiates = _safe.getInitiatesSync();

    for (var entry in initiates.entries) {
      var id = entry.key;
      var secret = entry.value;
      var accessPermission = reader + standard + admin;

      var identity = getCachedIdentity(id);
      cards.add(Card(
        child: PlatformListTile(
          title: Row(
            children: [
              Column(
                children: [
                  PlatformText("😴 ${identity.nick} waiting"),
                  PlatformText("secret: $secret",
                      style: const TextStyle(
                        fontSize: 12,
                      )),
                ],
              ),
              const Spacer(),
              PlatformElevatedButton(
                onPressed: () {
                  _safe.setUsers({id: accessPermission}, SetUsersOptions());
                  _safe.syncUsers().then((value) => setState(() {}));
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
                  _safe.setUsers({id: 0}, SetUsersOptions());
                  _safe.syncUsers().then((value) => setState(() {}));
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
    return cards;
  }

  List<Widget> _getActions(BuildContext context) {
    return [
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

  List<Widget> _getRooms(BuildContext context) {
    var coven = widget.coven;
    var cards = <Widget>[];

    var id = _safe.currentUser.id;
    var ls = _safe.listFiles("rooms/.invites/$id",
        ListOptions(orderBy: "modTime", reverseOrder: true));

    var rooms = coven.rooms.toList();
    var invites = <String, Header>{};

    for (var l in ls) {
      if (!rooms.contains(l.name)) {
        rooms.insert(0, l.name);
        invites[l.name] = l;
      } else {
        _safe.deleteFile("rooms/.invites/$id", l.fileId);
      }
    }

    for (var room in rooms) {
      if (room == widget.room) {
        continue;
      }

      Widget? trailing;
      if (room != welcomeSpace) {
        trailing = PlatformIconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            Future<void> task() async {
              coven.rooms.remove(room);
              Profile.current.update(coven);
              if (invites.containsKey(room)) {
                _safe.deleteFile(
                  "rooms/.invites/$id",
                  invites[room]!.fileId,
                );
              }
            }

            await progressDialog<void>(
              context,
              "deleting room, please wait",
              task(),
              successMessage: "You left $room",
              errorMessage: "Removal failed",
            );
            if (!mounted) return;
            setState(() {});
          },
        );
      }

      String subtitle = coven.name;
      Widget? leading;
      if (invites.containsKey(room)) {
        var identity = getCachedIdentity(invites[room]!.creator);
        leading = Image.memory(identity.avatar, width: 32, height: 32);
        // leading = const Icon(Icons.new_releases);
        subtitle = "Invite from ${identity.nick}";
      }

      cards.add(
        Card(
          child: PlatformListTile(
            title: Text(room),
            subtitle: Text(subtitle),
            leading: leading,
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

  Widget _getSettings(BuildContext context) {
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

  Widget _getPrivates(BuildContext context) {
    var cards = <Widget>[];
    var coven = widget.coven;
    var users = _safe.getUsersSync();

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
                      child: Chat(coven, "lounge", id)),
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

  Widget _sendInvites(BuildContext context) {
    var cards = <Widget>[];
    var room = widget.room;
    var users = _safe.getUsersSync();

    cards.add(Card(
      child: PlatformListTile(
        leading: const Icon(Icons.arrow_back),
        title: const Text("Back to rooms"),
        onTap: () => setState(() {
          _invite = false;
        }),
      ),
    ));

    for (var id in users.keys) {
      if (id == widget.coven.identity.id) {
        continue;
      }

      var identity = getCachedIdentity(id);
      if (identity.nick == "") {
        continue;
      }

      cards.add(Card(
        child: PlatformListTile(
          title: Text(identity.nick),
          subtitle: Text(id),
          onTap: () async {
            await _safe.putBytes(
                "rooms/.invites/$id", room, Uint8List(0), PutOptions());
            if (!mounted) return;
            showPlatformSnackbar(context, "Invite sent to ${identity.nick}");
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
    Widget body;
    if (_private) {
      body = _getPrivates(context);
    } else if (_invite) {
      body = _sendInvites(context);
    } else {
      body = RefreshIndicator(
        child: ListView(
          children: [
            ..._getInitiates(),
            _getPrivate(),
            ..._getActions(context),
            ..._getRooms(context),
            _getSettings(context),
          ],
        ),
        onRefresh: () async {
          await _safe.syncUsers();
          if (!mounted) return;
          setState(() {});
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: body,
    );
  }
}
