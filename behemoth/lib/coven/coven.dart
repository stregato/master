import 'dart:async';
import 'dart:isolate';

import 'package:basic_utils/basic_utils.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/common/profile.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/woland_def.dart';

var appsIcons = {
  "chat": Icons.chat,
  "private": Icons.question_answer,
  "library": Icons.folder,
  "invite": Icons.token,
};

const welcomeSpace = 'lounge';

class CovenWidget extends StatefulWidget {
  const CovenWidget({Key? key}) : super(key: key);

  @override
  State<CovenWidget> createState() => _CovenWidgetState();
}

class _CovenWidgetState extends State<CovenWidget> {
  late Coven _coven;
  List<String> _waitingUsers = [];
  Permission _myPermission = 0;
  Timer? _timer;
  DateTime lastWaitingUsersUpdate = DateTime(0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), _waitingRoom);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _waitingRoom(Timer _) {
    if (DateTime.now().difference(lastWaitingUsersUpdate).inMinutes < 5) {
      return;
    }
    var profile = Profile.current();
    var access = _coven.rooms['lounge']!;
    openSafe(profile.identity, access, OpenOptions());

    var users = getUsers("${_coven.name}/lounge");
    _myPermission = users[profile.identity.id] ?? 0;
    _waitingUsers = users.entries
        .where((e) => e.value == permissionWait)
        .map((e) => e.key)
        .toList();
    setState(() {
      _waitingUsers = _waitingUsers;
      lastWaitingUsersUpdate = DateTime.now();
    });
  }

  static Future<Safe> _open(Identity identity, String access) {
    return Isolate.run<Safe>(() {
      return openSafe(identity, access, OpenOptions());
    });
  }

  @override
  Widget build(BuildContext context) {
    _coven = ModalRoute.of(context)!.settings.arguments as Coven;
    var profile = Profile.current();
    var identity = profile.identity;

    var privates = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            ListTile(
                title: const Text("🕵 Privates"),
                onTap: () async {
                  var safeName = "${_coven.name}/lounge";
                  var s = await progressDialog(
                      context,
                      "Connecting to Privates",
                      _open(identity, _coven.rooms['lounge']!),
                      errorMessage: "cannot connect to Privates");
                  if (s != null && context.mounted) {
                    openSaves[safeName] = DateTime.now();
                    Navigator.pushNamed(context, "/coven/onetoone",
                            arguments: safeName)
                        .then((value) {
                      setState(() {});
                    });
                  }
                }),
          ],
        ),
      ),
    );
    var zonesWidgets = _coven.rooms.entries.map((e) {
      var safeName = "${_coven.name}/${e.key}";
      var h = "${e.key}@${_coven.name}";
      var title = openSaves.containsKey(safeName)
          ? Text("🔓 ${StringUtils.capitalize(e.key)}")
          : Text("🔒 ${StringUtils.capitalize(e.key)}");

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              ListTile(
                  title: title,
                  onTap: () async {
                    var s = await progressDialog(context, "Connecting to $h...",
                        _open(identity, e.value),
                        errorMessage: "cannot connect to $h");
                    if (s != null && context.mounted) {
                      openSaves[safeName] = DateTime.now();
                      Navigator.pushNamed(context, "/coven/room",
                              arguments: safeName)
                          .then((value) {
                        setState(() {});
                      });
                    }
                  }),
            ],
          ),
        ),
      );
    }).toList();

    var amAdmin = _myPermission & permissionAdmin == permissionAdmin;
    for (var id in _waitingUsers) {
      var identity = getIdentity(id);
      if (identity.nick.isEmpty) {
        continue;
      }
      var safeName = "${_coven.name}/lounge";
      var accessPermission = permissionRead + permissionWrite + permissionAdmin;
      zonesWidgets.add(Card(
        child: ListTile(
          title: Text("😴 ${identity.nick} waiting"),
          subtitle: Text(
            "\n${identity.id}",
            style: const TextStyle(fontSize: 12),
          ),
          trailing: ButtonBar(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ElevatedButton(
                onPressed: amAdmin
                    ? () {
                        setUsers(safeName, {id: accessPermission},
                            SetUsersOptions());
                        _waitingUsers.remove(id);
                        setState(() {
                          _waitingUsers = _waitingUsers;
                        });
                      }
                    : null,
                child: const Text('Approve'),
              ),
              ElevatedButton(
                onPressed: amAdmin
                    ? () {
                        setUsers(safeName, {id: 0}, SetUsersOptions());
                        _waitingUsers.remove(id);
                        setState(() {
                          _waitingUsers = _waitingUsers;
                        });
                      }
                    : null,
                child: const Text('Reject'),
              ),
            ],
          ),
        ),
      ));
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(_coven.name),
          actions: [
            const NewsIcon(),
            PopupMenuButton<String>(
              onSelected: (String result) {
                switch (result) {
                  case 'create':
                    Navigator.pushNamed(context, "/coven/create",
                            arguments: _coven)
                        .then((value) => setState(() {}));
                    break;
                  case 'invite':
                    Navigator.pushNamed(context, "/invite",
                        arguments: "${_coven.name}/lounge");
                    break;
                  case 'settings':
                    Navigator.pushNamed(context, "/coven/settings",
                            arguments: _coven)
                        .then((value) => setState(() {}));
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'create',
                  child: Text('Add Space'),
                ),
                const PopupMenuItem<String>(
                  value: 'invite',
                  child: Text('Invite'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Column(
            children: [
              privates,
              ...zonesWidgets,
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          onTap: (idx) {
            switch (idx) {
              case 1:
                Navigator.pushNamed(context, '/coven/create',
                    arguments: _coven);
                break;
              case 2:
                Navigator.pushNamed(context, "/invite",
                    arguments: "${_coven.name}/lounge");
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list), label: "Rooms"),
            BottomNavigationBarItem(icon: Icon(Icons.add), label: "Add Room"),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_add), label: "Invite"),
          ],
        ));
  }
}
