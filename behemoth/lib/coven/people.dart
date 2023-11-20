import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';

import 'package:behemoth/woland/woland.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

var currentPanelIdx = <String, int>{};

class People extends StatefulWidget {
  final Safe safe;
  final Safe lounge;
  const People(this.safe, this.lounge, {Key? key}) : super(key: key);

  @override
  State<People> createState() => _PeopleState();
}

class _PeopleState extends State<People> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var safe = widget.safe;

    var users = safe.getUsersSync();
    var items =
        users.entries.where((e) => e.value & permissionRead > 0).map((e) {
      var identity = getCachedIdentity(e.key);
      var nick = identity.nick;

      return ListTile(
        leading: Image.memory(identity.avatar, width: 32, height: 32),
        title: Text(nick),
        subtitle: Text("${e.key.substring(0, 16)}..."),
        trailing: PlatformIconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            setState(() {
              users.remove(e.key);
            });
          },
        ),
      );
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          children: [
            const SizedBox(height: 20.0),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center horizontally
              children: [
                Expanded(
                  child: safe == widget.lounge
                      ? PlatformElevatedButton(
                          child: const Text("Invite"),
                          onPressed: () {
                            Navigator.pushNamed(context, "/invite",
                                arguments: safe);
                          })
                      : PlatformElevatedButton(
                          child: const Text("Add"),
                          onPressed: () {
                            Navigator.pushNamed(context, "/coven/add_person",
                                arguments: {
                                  "safe": safe,
                                  "lounge": widget.lounge
                                });
                          }),
                )
              ],
            ),
            const SizedBox(height: 20.0),
            ListView(
              shrinkWrap: true,
              children: items,
            ),
          ],
        ),
      ),
    );
  }
}
