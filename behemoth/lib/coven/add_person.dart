import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';

class AddPerson extends StatefulWidget {
  const AddPerson({super.key});

  @override
  State<AddPerson> createState() => _AddPersonState();
}

class _AddPersonState extends State<AddPerson> {
  late Safe _safe;
  late String _covenName;
  late String _roomName;

  _addPerson(Identity identity) async {
    await _safe.setUsers(
        {identity.id: permissionRead + permissionWrite + permissionAdmin},
        SetUsersOptions());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _safe = ModalRoute.of(context)!.settings.arguments as Safe;
    var lastSlash = _safe.name.lastIndexOf("/");

    _covenName = _safe.name.substring(0, lastSlash - 1);
    _roomName = _safe.name.substring(lastSlash + 1);
    var identities2 = getIdentities(_safe.name);
    var identities = getIdentities("$_covenName/lounge")
        .where((e) => !identities2.contains(e));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Add to $_roomName@$_covenName"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            children: [
              Text(
                "Choose a person in $_covenName",
                style: const TextStyle(
                  fontSize: 16,
                  //fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListView(
                shrinkWrap: true,
                children: identities.map((identity) {
                  var nick = identity.nick;

                  return ListTile(
                    leading:
                        Image.memory(identity.avatar, width: 32, height: 32),
                    title: Text(nick),
                    subtitle: Text("${identity.id.substring(0, 16)}..."),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _addPerson(identity);
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
