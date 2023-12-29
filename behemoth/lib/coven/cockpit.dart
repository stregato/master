import 'dart:async';
import 'dart:typed_data';

import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

const loungeRoom = 'lounge';

class RoomState {
  String covenName;
  String roomName;
  String privateId;
  DateTime lastAccess;
  DateTime lastMessageModTime;
  int unread;

  RoomState(this.covenName, this.roomName, this.lastAccess,
      this.lastMessageModTime, this.unread,
      {this.privateId = ""});
}

class Cockpit extends StatefulWidget {
  final Coven coven;
  final String room;
  final Function(int)? updateUnread;
  const Cockpit(this.coven, this.room, {this.updateUnread, super.key});

  static List<RoomState> state = [];

  @override
  State<Cockpit> createState() => _CockpitState();

  static void openCoven(Coven c) {
    for (var r in c.rooms) {
      updateRoom(c, r, false);
    }
    sortState();
  }

  static void closeCoven(Coven c) {
    for (var rs in state) {
      if (rs.covenName == c.name) {
        state.remove(rs);
      }
    }
  }

  static bool updateRoom(Coven c, String r, bool sort) {
    var headers = c.safe.listFiles(
        "$r/chat",
        ListOptions(
            limit: 6,
            reverseOrder: true,
            orderBy: "modTime",
            noPrivate: true,
            onlyChanges: true));
    var lastModTime = headers.firstOrNull?.modTime ?? DateTime(1970);
    var lastAccess = DateTime(1970);
    var unread = 0;
    for (var h in headers) {
      if (h.modTime.isAfter(lastAccess)) {
        unread++;
      }
    }
    for (var rs in state) {
      if (rs.covenName == c.name && rs.roomName == r) {
        if (rs.lastMessageModTime == lastModTime &&
            rs.lastAccess == lastAccess &&
            rs.unread == unread) {
          return false;
        }
        rs.lastAccess = lastAccess;
        rs.lastMessageModTime = lastModTime;
        rs.unread = unread;

        if (sort) {
          state.sort(
              (a, b) => b.lastMessageModTime.compareTo(a.lastMessageModTime));
        }
        return true;
      }
    }

    state.add(RoomState(c.name, r, lastAccess, lastModTime, unread));
    if (sort) {
      sortState();
    }
    return true;
  }

  static void visitRoom(Coven c, String r, {String privateId = ""}) {
    for (var rs in state) {
      if (rs.covenName == c.name &&
          rs.roomName == r &&
          rs.privateId == privateId) {
        rs.lastAccess = DateTime.now();
        rs.unread = 0;
        sortState();
        return;
      }
    }
  }

  static void sortState() {
    state.sort((a, b) {
      var cmp = b.lastAccess.compareTo(a.lastAccess);
      if (cmp != 0) {
        return cmp;
      }
      return b.lastMessageModTime.compareTo(a.lastMessageModTime);
    });
  }

  static void updatePrivateId(Coven c, Header h) {
    for (var rs in state) {
      if (rs.covenName == c.name && rs.privateId == h.creator) {
        rs.lastAccess = h.modTime;
        rs.lastMessageModTime = h.modTime;
        if (rs.lastMessageModTime.isAfter(rs.lastAccess)) {
          rs.unread++;
        }
        return;
      }
    }

    state.add(RoomState(c.name, "privates", h.modTime, h.modTime, 1,
        privateId: h.creator));
  }

  static int updatePrivate(Coven c) {
    var headers = c.safe.listFiles("rooms/privates/chat",
        ListOptions(limit: 64, reverseOrder: true, orderBy: "modTime"));
    var privateIds = <String>{};
    var changes = 0;
    for (var h in headers) {
      if (h.privateId == c.identity.id && !privateIds.contains(h.creator)) {
        privateIds.add(h.creator);
        updatePrivateId(c, h);
        changes++;
      }
    }
    return changes;
  }

  static Future<int> sync() async {
    var changes = 0;
    for (var c in Coven.opened.values) {
      changes += updatePrivate(c);
      for (var r in c.rooms) {
        try {
          updateRoom(c, r, true);
          //  changes += ch; //TODO: take it back
        } catch (e) {
          //ignore
        }
      }
    }
    return changes;
  }
}

class _CockpitState extends State<Cockpit> {
  bool _private = false;
  bool _invite = false;
  late Safe _safe;
  Timer? _timer;
  bool _onlyCoven = false;

  @override
  void initState() {
    super.initState();
    _safe = widget.coven.safe;
    _syncState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      _syncState();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  openPrivate(BuildContext context, Coven coven, Identity identity) {
    var nick = identity.nick.isNotEmpty ? identity.nick : identity.id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlatformScaffold(
          appBar: PlatformAppBar(
            backgroundColor: Colors.red[300],
            leading: IconButton(
              icon: const Icon(Icons.vpn_key),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(nick),
          ),
          body: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Chat(coven, "privates", identity.id)),
          bottomNavBar: PlatformNavBar(
              currentIndex: 1,
              itemChanged: (index) {
                if (index == 0) {
                  Navigator.pop(context);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.arrow_back),
                  label: "Back",
                ),
                BottomNavigationBarItem(
                    icon: Icon(Icons.vpn_key), label: "Private"),
                BottomNavigationBarItem(
                    icon: Icon(Icons.delete), label: "Wipe"),
              ]),
        ),
      ),
    );
  }

  _syncState() async {
    var changes = await Cockpit.sync();
    if (changes > 0) {
      setState(() {});
    }

    var unread = 0;
    for (var rs in Cockpit.state) {
      unread += rs.unread;
    }

    widget.updateUnread?.call(unread);
  }

  List<Widget> _getRooms(BuildContext context) {
    var cards = <Widget>[];

    for (var rs in Cockpit.state) {
      var covenName = rs.covenName;
      var roomName = rs.roomName;
      var privateId = rs.privateId;
      var unread = rs.unread;
      Widget? trailing;

      if (_onlyCoven && covenName != widget.coven.name) {
        continue;
      }

      if (unread > 5) {
        trailing = const Text("5+");
      } else if (unread > 0) {
        trailing = Text("$unread");
      }

      var current = covenName == widget.coven.name && roomName == widget.room;
      var nick = privateId.isEmpty ? "" : getCachedIdentity(privateId).nick;
      var title = privateId.isEmpty ? roomName : nick;

      cards.add(
        Card(
          color: current ? Colors.blueGrey : null,
          child: ListTile(
            title: Text(title),
            subtitle: Text(covenName),
            leading: privateId.isNotEmpty ? const Icon(Icons.vpn_key) : null,
            trailing: trailing,
            onTap: () async {
              if (privateId.isNotEmpty) {
                await openPrivate(
                    context, widget.coven, getCachedIdentity(privateId));
                setState(() {});
              } else {
                await Navigator.pushReplacementNamed(context, "/coven/room",
                    arguments: {
                      "room": roomName,
                      "coven": Coven.opened[covenName],
                    });
              }
            },
          ),
        ),
      );
    }
    return cards;
  }

  List<Widget> _getInitiates() {
    var cards = <Widget>[];
    var initiates = _safe.getInitiatesSync();

    initiates.sort((a, b) => b.identity.nick.compareTo(a.identity.nick));
    for (var initiate in initiates) {
      var accessPermission = reader + standard + admin;

      var secret = initiate.secret;
      var identity = initiate.identity;
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
                onPressed: () async {
                  _safe.setUsers(
                      {identity.id: accessPermission}, SetUsersOptions());
                  await _safe.syncUsers();
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
                onPressed: () async {
                  _safe.setUsers({identity.id: 0}, SetUsersOptions());
                  await _safe.syncUsers();
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
            openPrivate(context, coven, identity);
            setState(() {
              _private = false;
            });
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
        leading: const Icon(Icons.vpn_key, color: Colors.yellow),
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
      body = Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Only ${widget.coven.name}"),
              Switch(
                value: _onlyCoven,
                onChanged: (val) => setState(() {
                  _onlyCoven = val;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              child: ListView(
                children: [
                  ..._getInitiates(),
                  _getPrivate(),
                  ..._getRooms(context),
                  _getSettings(context),
                ],
              ),
              onRefresh: () async {
                await _safe.syncUsers();
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: body,
    );
  }
}
