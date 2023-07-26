import 'package:basic_utils/basic_utils.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland_def.dart';

import '../navigation/bar.dart';

var appsIcons = {
  "chat": Icons.chat,
  "private": Icons.question_answer,
  "library": Icons.folder,
  "invite": Icons.token,
};

class PortalView extends StatelessWidget {
  const PortalView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final portal = ModalRoute.of(context)!.settings.arguments as Portal;

    var zones = listZones(portal.name);
    var zonesWidgets = zones.fold(<Widget>[], (res, e) {
      res.addAll([
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, "/portal/$e", arguments: portal);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(height: 20),
                    Icon(appsIcons[e]),
                    const SizedBox(height: 10),
                    Text(StringUtils.capitalize(e)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ]);
      return res;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(portal.name),
        actions: [
          ElevatedButton(
            child: const Text("Add Zone"),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: zonesWidgets,
        ),
      ),
      bottomNavigationBar: MainNavigationBar(portal.name),
    );
  }
}
