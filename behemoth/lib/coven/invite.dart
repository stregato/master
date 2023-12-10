import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/federate.dart';
import 'package:behemoth/coven/invite_to_coven.dart';
import 'package:behemoth/coven/invite_to_room.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';

class Invite extends StatelessWidget {
  const Invite({super.key});

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    var coven = args['coven'] as Coven;
    var isAdmin = coven.safe.permission & admin > 0;

    var tabAddToCoven =
        const Tab(icon: Icon(Icons.auto_awesome), text: "Add to Coven");
    var tabAddToRoom =
        const Tab(icon: Icon(Icons.meeting_room), text: "Add to Room");
    var tabFederate =
        const Tab(icon: Icon(Icons.wifi_tethering), text: "Federate");

    var length = isAdmin ? 3 : 2;

    return DefaultTabController(
      length: length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add in ${coven.name}'),
        ),
        body: Column(
          children: <Widget>[
            TabBar(
              tabs: [
                if (isAdmin) tabAddToCoven,
                tabAddToRoom,
                tabFederate,
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (isAdmin) InviteToCoven(coven: coven),
                  InviteToRoom(coven),
                  Federate(coven),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
