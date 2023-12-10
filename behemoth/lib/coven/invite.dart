import 'package:behemoth/coven/invite_to_coven.dart';
import 'package:behemoth/coven/invite_to_room.dart';
import 'package:flutter/material.dart';

class Invite extends StatelessWidget {
  const Invite({super.key});

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    var coven = args['coven'];

    var tabAddToCoven =
        const Tab(icon: Icon(Icons.auto_awesome), text: "Add to Coven");
    var tabAddToRoom =
        const Tab(icon: Icon(Icons.meeting_room), text: "Add to Room");

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add person in ${coven.name}'),
        ),
        body: Column(
          children: <Widget>[
            TabBar(
              tabs: [
                tabAddToCoven,
                tabAddToRoom,
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  InviteToCoven(coven: coven),
                  InviteToRoom(coven),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
