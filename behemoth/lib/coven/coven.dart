import 'dart:async';

import 'package:basic_utils/basic_utils.dart';
import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

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
  List<Header> _invites = [];

  @override
  void initState() {
    super.initState();
    // _timer =
    //     Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Widget> getInvites(BuildContext context) {
    var widgets = <Widget>[];
    for (var h in _invites) {
      var access = h.attributes.extra['access'] as String;
      var name = h.attributes.extra['name'] as String;
      var sender = Identity.fromJson(h.attributes.extra['sender']);

      widgets.add(Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.mail),
                const SizedBox(width: 10),
                PlatformText("Invite to $name by ${sender.nick}"),
                const Spacer(),
                PlatformElevatedButton(
                  onPressed: () {
                    progressDialog(context, "Joining $name", Coven.join(access),
                        successMessage: "Joined $name",
                        errorMessage: "Failed to join $name");
                  },
                  child: PlatformText('Join'),
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  _checkInvites() async {
    if (_lounge == null) {
      return;
    }
    var headers = await _lounge!.listFiles(
        "chat",
        ListOptions(
          privateId: _coven.identity.id,
          contentType: "application/x-behemoth-invite",
        ));

    var invites = <Header>[];
    var diff = false;
    for (var h in headers) {
      var name = h.attributes.extra['name'] as String;
      var access = h.attributes.extra['access'] as String;
      if (!_coven.rooms.containsKey(name)) {
        invites.add(h);
        diff |= _invites
            .where((h) => h.attributes.extra['access'] == access)
            .isNotEmpty;
      }
    }

    if (diff || invites.length != _invites.length) {
      setState(() {
        _invites = invites;
      });
    }
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

    var settingsIcon = PlatformIconButton(
        onPressed: () async {
          await Navigator.pushNamed(context, "/coven/settings",
              arguments: _coven);
          setState(() {});
        },
        icon: const Icon(Icons.settings));

    var privates = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            ListTile(
                title: PlatformText("🕵 Privates"),
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
          ? PlatformText("🔓 ${StringUtils.capitalize(room)}")
          : PlatformText("🔒 ${StringUtils.capitalize(room)}");

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              PlatformListTile(
                  title: title,
                  onTap: () async {
                    Navigator.pushNamed(context, "/coven/room", arguments: {
                      "future": _coven.getSafe(room),
                      "name": Safe.pretty(safeName),
                      "lounge": _lounge,
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
    _checkInvites();
    var amAdmin = _myPermission & permissionAdmin == permissionAdmin;
    for (var id in _waitingUsers) {
      var identity = getIdentity(id);
      if (identity.nick.isEmpty) {
        continue;
      }
      var accessPermission = permissionRead + permissionWrite + permissionAdmin;
      zonesWidgets.add(Card(
        child: ListTile(
          title: PlatformText("😴 ${identity.nick} waiting"),
          subtitle: PlatformText(
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
                child: PlatformText('Approve'),
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
                child: PlatformText('Reject'),
              ),
            ],
          ),
        ),
      ));
    }

    return PlatformScaffold(
        appBar: PlatformAppBar(
          title: PlatformText(_coven.name),
          trailingActions: [
            const NewsIcon(),
            const SizedBox(width: 10),
            settingsIcon,
          ],
        ),
        body: FutureBuilder<Safe>(
            future: _coven.getLounge(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: PlatformText("${snapshot.error}"));
              }
              if (!snapshot.hasData) {
                return CatProgressIndicator("Connecting to ${_coven.name}...");
              }

              if (_lounge == null) {
                _lounge = snapshot.data as Safe;
                Future.delayed(Duration.zero, () {
                  setState(() {
                    _lounge = snapshot.data as Safe;
                  });
                });
              }

              return Padding(
                padding: const EdgeInsets.all(2.0),
                child: ListView(
                  children: [
                    ...getInvites(context),
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
                Navigator.pushNamed(context, "/invite",
                    arguments: {"safe": _lounge});
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list), label: "Rooms"),
            BottomNavigationBarItem(
                icon: Icon(Icons.add), label: "Create Room"),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_add), label: "Invite"),
          ],
        ));
  }
}
