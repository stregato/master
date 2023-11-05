import 'dart:typed_data';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:snowflake_dart/snowflake_dart.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class AddPerson extends StatefulWidget {
  const AddPerson({super.key});

  @override
  State<AddPerson> createState() => _AddPersonState();
}

class _AddPersonState extends State<AddPerson> {
  late Safe _safe;
  late Safe _lounge;

  _addPerson(BuildContext context, Identity identity) async {
    await _safe.setUsers(
        {identity.id: permissionRead + permissionWrite + permissionAdmin},
        SetUsersOptions());
    if (!mounted) return;

    var d = decodeAccess(_safe.currentUser, _safe.access);
    var access = encodeAccess(identity.id, d.safeName, d.creatorId, d.urls,
        aesKey: d.aesKey);

    var task = _lounge.putBytes(
        "chat",
        '${Snowflake(nodeId: 0).generate()}',
        Uint8List.fromList([]),
        PutOptions(
          contentType: "application/x-behemoth-invite",
          private: identity.id,
          meta: {
            'access': access,
            'name': _safe.prettyName,
            'sender': _safe.currentUser,
          },
        ));
    await progressDialog(context, "adding ${identity.nick}", task,
        successMessage: "added ${identity.nick}",
        errorMessage: "failed to add ${identity.nick}");
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    _safe = args['safe'] as Safe;
    _lounge = args['lounge'] as Safe;

    var ids2 = _safe.getUsersSync().keys;
    var ids =
        _lounge.getUsersSync().keys.where((id) => !ids2.contains(id)).toList();

    return PlatformScaffold(
      //resizeToAvoidBottomInset: false, //TODO: add again
      appBar: PlatformAppBar(
        title: Text("Add to ${_safe.prettyName}"),
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
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _addPerson(context, identity);
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
