import 'package:behemoth/common/profile.dart';
import 'package:flutter/material.dart';

class AddStore extends StatefulWidget {
  final Coven coven;
  const AddStore(this.coven, {super.key});

  @override
  State<AddStore> createState() => _AddStoreState();
}

class _AddStoreState extends State<AddStore> {
  late Coven _coven;

  @override
  Widget build(BuildContext context) {
    _coven = widget.coven;

    var stores = <Widget>[];
    for (var sc in _coven.safe.storeConfigs) {
      stores.add(ListTile(
        title: Text(
          sc.url,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    return ListView(
      shrinkWrap: true,
      children: stores,
    );
  }
}
