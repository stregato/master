import 'dart:typed_data';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:snowflake_dart/snowflake_dart.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class InvitoToRoom extends StatefulWidget {
  const InvitoToRoom({super.key});

  @override
  State<InvitoToRoom> createState() => _InvitoToRoomState();
}

class _InvitoToRoomState extends State<InvitoToRoom> {
  late Coven _coven;
  late Safe _safe;
  late String _room;

  _invitePerson(BuildContext context, Identity identity) {
    var id = identity.id;
    _safe.putBytes("rooms/.invites/$id", _room, Uint8List(0), PutOptions());
    showPlatformSnackbar(context, "Invite sent to ${identity.nick}");
  }

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    _coven = args['coven'] as Coven;
    _safe = _coven.safe;
    _room = args['room'] as String;

    var ids = _safe
        .getUsersSync()
        .keys
        .where((id) => id != _coven.identity.id)
        .toList();

    return PlatformScaffold(
      //resizeToAvoidBottomInset: false, //TODO: add again
      appBar: PlatformAppBar(
        title: Text("Send invite for $_room@${_safe.name}"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              ListView(
                shrinkWrap: true,
                children: ids.map((id) {
                  var identity = getCachedIdentity(id);
                  var nick = identity.nick;

                  return ListTile(
                    leading:
                        Image.memory(identity.avatar, width: 32, height: 32),
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
          ),
        ),
      ),
    );
  }
}
