import 'package:behemoth/common/profile.dart';
import 'package:flutter/material.dart';

class Federate extends StatefulWidget {
  final Coven coven;
  const Federate(this.coven, {super.key});

  @override
  State<Federate> createState() => _FederateState();
}

class _FederateState extends State<Federate> {
  late Coven _coven;

  @override
  Widget build(BuildContext context) {
    _coven = widget.coven;
    var p = Profile.current;

    var covens = <Widget>[];
    for (var c in Profile.current.covens.keys) {
      if (c == _coven.name) continue;

      var federated = _coven.federated.contains(c);
      covens.add(ListTile(
        title: Text(c),
        trailing: federated ? const Icon(Icons.check) : const Icon(Icons.add),
        onTap: () {
          setState(() {
            if (federated) {
              _coven.federated.remove(c);
            } else {
              _coven.federated.add(c);
            }
            p.update(_coven);
          });
        },
      ));
    }

    return ListView(
      shrinkWrap: true,
      children: covens,
    );
  }
}
