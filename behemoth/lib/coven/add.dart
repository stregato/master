import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/federate.dart';
import 'package:behemoth/coven/invite_to_coven.dart';
import 'package:behemoth/coven/invite_to_room.dart';
import 'package:behemoth/room/create_room.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';

class Add extends StatelessWidget {
  const Add({super.key});

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    var coven = args['coven'] as Coven;
    var isAdmin = coven.safe.permission & admin > 0;

    var tabAddToCoven =
        const Tab(icon: Icon(Icons.auto_awesome), text: "Invite");
    var tabAddRoom =
        const Tab(icon: Icon(Icons.meeting_room), text: "New Room");
    var tabAddToRoom = const Tab(icon: Icon(Icons.person_add), text: "To Room");
    var tabFederate =
        const Tab(icon: Icon(Icons.wifi_tethering), text: "Federate");

    var length = isAdmin ? 4 : 3;

    return DefaultTabController(
      length: length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add in ${coven.name}'),
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              TabBar(
                tabs: [
                  if (isAdmin) tabAddToCoven,
                  tabAddRoom,
                  tabAddToRoom,
                  tabFederate,
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: TabBarView(
                    children: [
                      if (isAdmin) InviteToCoven(coven: coven),
                      CreateRoom(coven),
                      InviteToRoom(coven),
                      Federate(coven),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
