import 'dart:async';

import 'package:basic_utils/basic_utils.dart';
import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

var appsIcons = {
  "chat": Icons.chat,
  "private": Icons.question_answer,
  "content": Icons.folder,
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
  Safe? _lounge;

  @override
  void initState() {
    super.initState();
    _timer =
        Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _waitingRoom() {
    if (_lounge == null ||
        DateTime.now().difference(lastWaitingUsersUpdate).inMinutes < 5) {
      return;
    }
    var profile = Profile.current();

    var users = _lounge!.getUsersSync();
    _myPermission = users[profile.identity.id] ?? 0;
    _waitingUsers = users.entries
        .where((e) => e.value == permissionWait)
        .map((e) => e.key)
        .toList();
    _waitingUsers = _waitingUsers;
    lastWaitingUsersUpdate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    _coven = ModalRoute.of(context)!.settings.arguments as Coven;
    var privates = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            ListTile(
                title: const Text("🕵 Privates"),
                onTap: () {
                  Navigator.pushNamed(context, "/coven/onetoone",
                          arguments: _lounge)
                      .then((value) {
                    setState(() {});
                  });
                }),
          ],
        ),
      ),
    );
    var zonesWidgets = _coven.rooms.keys.map((room) {
      var safeName = "${_coven.name}/$room";
      var title = Coven.safes.containsKey(safeName)
          ? Text("🔓 ${StringUtils.capitalize(room)}")
          : Text("🔒 ${StringUtils.capitalize(room)}");

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              ListTile(
                  title: title,
                  onTap: () async {
                    Navigator.pushNamed(context, "/coven/room", arguments: {
                      "future": _coven.getSafe(room),
                      "name": Safe.pretty(safeName),
                    }).then((value) {
                      setState(() {});
                    });
                  }),
            ],
          ),
        ),
      );
    }).toList();

    _waitingRoom();
    var amAdmin = _myPermission & permissionAdmin == permissionAdmin;
    for (var id in _waitingUsers) {
      var identity = getIdentity(id);
      if (identity.nick.isEmpty) {
        continue;
      }
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
              PlatformElevatedButton(
                onPressed: amAdmin
                    ? () {
                        _lounge!.setUsers(
                            {id: accessPermission}, SetUsersOptions());
                        _waitingUsers.remove(id);
                        setState(() {
                          _waitingUsers = _waitingUsers;
                        });
                      }
                    : null,
                child: const Text('Approve'),
              ),
              PlatformElevatedButton(
                onPressed: amAdmin
                    ? () {
                        _lounge!.setUsers({id: 0}, SetUsersOptions());
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

    return PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text(_coven.name),
          trailingActions: [
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
        body: FutureBuilder<Safe>(
            future: _coven.getLounge(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("${snapshot.error}"));
              }
              if (!snapshot.hasData) {
                return CatProgressIndicator("Connecting to ${_coven.name}...");
              }

              _lounge = snapshot.data as Safe;
              return Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(
                  children: [
                    privates,
                    ...zonesWidgets,
                  ],
                ),
              );
            }),
        bottomNavBar: PlatformNavBar(
          itemChanged: (idx) {
            switch (idx) {
              case 1:
                Navigator.pushNamed(context, '/coven/create',
                    arguments: _coven);
                break;
              case 2:
                Navigator.pushNamed(context, "/invite", arguments: _lounge);
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
