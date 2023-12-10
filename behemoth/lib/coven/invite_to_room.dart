import 'dart:typed_data';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/coven/navigation.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class InviteToRoom extends StatefulWidget {
  final Coven coven;
  const InviteToRoom(this.coven, {super.key});

  @override
  State<InviteToRoom> createState() => _InviteToRoomState();
}

class _InviteToRoomState extends State<InviteToRoom> {
  late Coven _coven;
  late Safe _safe;
  String? _room;

  _invitePerson(BuildContext context, Identity identity) {
    var id = identity.id;
    _safe.putBytes("rooms/.invites/$id", _room!, Uint8List(0), PutOptions());
    showPlatformSnackbar(context, "Invite sent to ${identity.nick}");
  }

  @override
  Widget build(BuildContext context) {
    _coven = widget.coven;
    _safe = _coven.safe;

    var ids = _safe
        .getUsersSync()
        .keys
        .where((id) => id != _coven.identity.id)
        .toList();

    var rooms = <Widget>[];
    for (var room in _coven.rooms) {
      if (room == loungeRoom) continue;
      rooms.add(ListTile(
        title: Text(room),
        onTap: () {
          setState(() {
            _room = room;
          });
        },
      ));
    }

    var roomsList = Column(
      children: [
        const Text("Choose the room"),
        ListView(
          shrinkWrap: true,
          children: rooms,
        ),
      ],
    );
    var idsList = Column(
      children: [
        const Text("Choose the person"),
        ListView(
          shrinkWrap: true,
          children: ids.map((id) {
            var identity = getCachedIdentity(id);
            var nick = identity.nick;

            return ListTile(
              leading: Image.memory(identity.avatar, width: 32, height: 32),
              title: Text(nick),
              subtitle: Text("${identity.id.substring(0, 16)}..."),
              trailing: PlatformIconButton(
                icon: const Icon(Icons.email),
                onPressed: () {
                  _invitePerson(context, identity);
                },
              ),
            );
          }).toList(),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            if (_room == null) roomsList else idsList,
          ],
        ),
      ),
    );
  }
}
