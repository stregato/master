import 'dart:typed_data';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/complete_identity.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class CreateRoom extends StatefulWidget {
  const CreateRoom({super.key});

  @override
  State<CreateRoom> createState() => _CreateRoomState();
}

class CreateRoomViewArgs {
  String safeName;
  CreateRoomViewArgs(this.safeName);
}

class _CreateRoomState extends State<CreateRoom> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  final List<Identity> _users = [];
  List<String> _rooms = [];
  late Safe _safe;

  bool _validConfig() {
    return name.isNotEmpty;
  }

  String? _validateName(String? name) {
    return _rooms.contains(name) ? "room already exists" : null;
  }

  Future<List<String>> _getRooms() async {
    var rooms = <String>[];
    var ls = _safe.listFiles("rooms/.list", ListOptions());
    for (var e in ls) {
      rooms.add(e.name);
    }
    return rooms;
  }

  _createRoom(Coven coven, String name, List<String> users) async {
    await _safe.putBytes("rooms/.list", name, Uint8List(0), PutOptions());
    coven.rooms.add(name);

    var p = Profile.current;
    p.covens[coven.name] = coven;
    p.save();

    for (var user in users) {
      _safe.putBytes("rooms/.invites/$user", name, Uint8List(0), PutOptions());
    }
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    var coven = args["coven"] as Coven;
    _safe = coven.safe;
    var identities = _safe
        .getUsersSync()
        .entries
        .where((e) => e.key != coven.identity.id && e.value >= reader)
        .map((e) => getCachedIdentity(e.key))
        .toList();

    var body = Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlatformTextFormField(
            validator: _validateName,
            material: (_, __) => MaterialTextFormFieldData(
              decoration: const InputDecoration(labelText: 'Name'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            cupertino: (_, __) => CupertinoTextFormFieldData(
              placeholder: 'Name',
            ),
            initialValue: name,
            onChanged: (val) => setState(() => name = val),
          ),
          const SizedBox(
            height: 20,
          ),
          PlatformText(
            "People",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          AutocompleteIdentity(
            identities:
                identities.where((i) => _users.contains(i) == false).toList(),
            onSelect: (identity) {
              setState(() {
                if (_users.contains(identity) == false) {
                  _users.add(identity);
                }
              });
            },
          ),
          ListView.builder(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            itemCount: _users.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.share),
              trailing: PlatformIconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _users.removeAt(index);
                    });
                  }),
              title: Text(_users[index].nick),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: PlatformElevatedButton(
              onPressed: _validConfig()
                  ? () async {
                      await progressDialog(
                          context,
                          "opening portal, please wait",
                          _createRoom(
                              coven, name, _users.map((i) => i.id).toList()),
                          successMessage:
                              "Congrats! You successfully created $name",
                          errorMessage: "Creation failed");
                      if (!mounted) return;
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Create room in ${coven.name}"),
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: FutureBuilder<List<String>>(
            future: _getRooms(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                _rooms = snapshot.data!;
                return body;
              }
              return const CatProgressIndicator("loading rooms");
            },
          ),
        ),
      ),
    );
  }
}
