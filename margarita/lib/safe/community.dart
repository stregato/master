import 'package:basic_utils/basic_utils.dart';
import 'package:margarita/common/profile.dart';
import 'package:flutter/material.dart';

import '../navigation/bar.dart';

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

  List<String> _spaces = [];

  @override
  Widget build(BuildContext context) {
    _community = ModalRoute.of(context)!.settings.arguments as Community;

    _spaces = _community.spaces.keys.toList();
    var zonesWidgets = _spaces
        .map(
          (name) => Card(
            child: ListTile(
              title: Text(StringUtils.capitalize(name)),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  "/community/space",
                  arguments: "${_community.name}/$name",
                );
              },
            ),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_community.name),
        actions: [
          ElevatedButton(
            child: const Text("Add Space"),
            onPressed: () {
              Navigator.pushNamed(context, "/community/createSpace",
                      arguments: _community)
                  .then((value) => setState(() {
//                        _zones = listZones(_args.safeName);
                      }));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          children: zonesWidgets,
        ),
      ),
      bottomNavigationBar: MainNavigationBar(_community.name),
    );
  }
}
