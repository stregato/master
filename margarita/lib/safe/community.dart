import 'dart:async';
import 'dart:isolate';

import 'package:basic_utils/basic_utils.dart';
import 'package:margarita/common/profile.dart';
import 'package:flutter/material.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/common/news_navigation_bar.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';

var appsIcons = {
  "chat": Icons.chat,
  "private": Icons.question_answer,
  "library": Icons.folder,
  "invite": Icons.token,
};

const welcomeSpace = 'welcome';

class CommunityView extends StatefulWidget {
  const CommunityView({Key? key}) : super(key: key);

  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  late Community _community;
  List<String> _waitingUsers = [];
  Permission _myPermission = 0;
  Timer? _timer;
  DateTime lastWaitingUsersUpdate = DateTime(0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 5), _waitingRoom);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _waitingRoom(Timer _) {
    var profile = Profile.current();
    var access = _community.spaces['welcome']!;
    openSafe(profile.identity, access, OpenOptions());

    var users = getUsers("${_community.name}/welcome");
    _myPermission = users[profile.identity.id] ?? 0;
    _waitingUsers = users.entries
        .where((e) => e.value == permissionWait)
        .map((e) => e.key)
        .toList();
    setState(() {
      _waitingUsers = _waitingUsers;
    });
  }

  static Future<Safe> _open(Identity identity, String access) {
    return Isolate.run<Safe>(() {
      return openSafe(identity, access, OpenOptions());
    });
  }

  @override
  Widget build(BuildContext context) {
    _community = ModalRoute.of(context)!.settings.arguments as Community;
    var profile = Profile.current();
    var identity = profile.identity;

    var zonesWidgets = _community.spaces.entries.map((e) {
      var safeName = "${_community.name}/${e.key}";
      var h = "${e.key}@${_community.name}";
      var title = openSaves.containsKey(safeName)
          ? Text("🔓 ${StringUtils.capitalize(e.key)}")
          : Text("🔒 ${StringUtils.capitalize(e.key)}");

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
              title: title,
              onTap: () async {
                var s = await progressDialog(
                    context, "Connecting to $h...", _open(identity, e.value),
                    errorMessage: "cannot connect to $h");
                if (s != null && context.mounted) {
                  openSaves[safeName] = DateTime.now();
                  Navigator.pushNamed(context, "/community/space",
                          arguments: safeName)
                      .then((value) {
                    setState(() {});
                  });
                }
              }),
        ),
      );
    }).toList();

    var amAdmin = _myPermission & permissionAdmin == permissionAdmin;
    for (var id in _waitingUsers) {
      var identity = getIdentity(id);
      if (identity.nick.isEmpty) {
        continue;
      }
      var safeName = "${_community.name}/welcome";
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
          title: Text(_community.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (String result) {
                switch (result) {
                  case 'addspace':
                    Navigator.pushNamed(context, "/community/createSpace",
                            arguments: _community)
                        .then((value) => setState(() {}));
                    break;
                  case 'invite':
                    Navigator.pushNamed(context, "/invite",
                        arguments: _community);
                    break;
                  case 'settings':
                    Navigator.pushNamed(context, "/community/settings",
                            arguments: _community)
                        .then((value) => setState(() {}));
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'addspace',
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
            children: zonesWidgets,
          ),
        ),
        bottomNavigationBar: NewsNavigationBar(
          onTap: (idx) {
            switch (idx) {
              case 0:
                Navigator.pushNamed(context, '/community/onetoone',
                    arguments: _community);
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.voice_chat), label: "121"),
          ],
        ));
  }
}
