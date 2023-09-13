import 'dart:ffi';
import 'dart:isolate';

import 'package:basic_utils/basic_utils.dart';
import 'package:margarita/common/profile.dart';
import 'package:flutter/material.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/navigation/bar.dart';
import 'package:margarita/navigation/news.dart';
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

    //  _spaces = ;
    var zonesWidgets = _community.spaces.entries.map((e) {
      var safeName = "${_community.name}/${e.key}";
      var h = "${e.key}@${_community.name}";
      var title = openSaves.containsKey(safeName)
          ? Text("🔓 ${StringUtils.capitalize(e.key)}")
          : Text("🔒 ${StringUtils.capitalize(e.key)}");

      return Card(
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
                  openSaves[safeName] = DateTime.now();
                  setState(() {});
                });
              }
            }),
      );
    }).toList();

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
                Navigator.of(context).popUntil((route) => route.isFirst);
                break;
              case 1:
                Navigator.pushNamed(context, '/community/onetoone',
                    arguments: _community);
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.voice_chat), label: "121"),
          ],
        ));
  }
}
