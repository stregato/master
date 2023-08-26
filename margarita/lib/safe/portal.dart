import 'package:basic_utils/basic_utils.dart';
import 'package:margarita/safe/create_zone.dart';
import 'package:margarita/safe/zone.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';

import '../navigation/bar.dart';

var appsIcons = {
  "chat": Icons.chat,
  "private": Icons.question_answer,
  "library": Icons.folder,
  "invite": Icons.token,
};

class PortalViewArgs {
  String portalName;
  PortalViewArgs(this.portalName);
}

class PortalView extends StatefulWidget {
  const PortalView({Key? key}) : super(key: key);

  @override
  State<PortalView> createState() => _PortalViewState();
}

class _PortalViewState extends State<PortalView> {
  late PortalViewArgs _args;

  List<String> _zones = [];

  @override
  Widget build(BuildContext context) {
    _args = ModalRoute.of(context)!.settings.arguments as PortalViewArgs;

    _zones = listZones(_args.portalName);
    var zonesWidgets = _zones.fold(<Widget>[], (res, zoneName) {
      res.addAll([
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    "/portal/zone",
                    arguments: ZoneViewArgs(_args.portalName, zoneName),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                        // Aligns the Icon and Text to the center of the Row
                        children: [
                          const Icon(Icons
                              .arrow_circle_right), // An Icon widget with the icon corresponding to the zoneName
                          const SizedBox(
                              width:
                                  10), // Empty space with a width of 10 pixels between the Icon and Text
                          Text(StringUtils.capitalize(
                              zoneName)), // A Text widget displaying the capitalized zoneName
                        ]),
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
        title: Text(_args.portalName),
        actions: [
          ElevatedButton(
            child: const Text("Add Zone"),
            onPressed: () {
              Navigator.pushNamed(context, "/portal/createZone",
                      arguments: CreateZoneViewArgs(_args.portalName))
                  .then((value) => setState(() {
                        _zones = listZones(_args.portalName);
                      }));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: zonesWidgets,
        ),
      ),
      bottomNavigationBar: MainNavigationBar(_args.portalName),
    );
  }
}
