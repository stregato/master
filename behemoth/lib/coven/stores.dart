import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/add_store.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Stores extends StatefulWidget {
  final Coven coven;
  const Stores(this.coven, {super.key});

  @override
  State<Stores> createState() => _StoresState();
}

class _StoresState extends State<Stores> {
  late Coven _coven;

  @override
  Widget build(BuildContext context) {
    _coven = widget.coven;

    var stores = <Widget>[];

    var storeConfigs = _coven.safe.storeConfigs.toList();
    storeConfigs.sort((a, b) => a.primary ? -1 : 1);

    for (var sc in storeConfigs) {
      String title;
      String nick = getCachedIdentity(sc.creatorid).nick;
      if (sc.name.isNotEmpty) {
        title = "${sc.name} by $nick";
      } else {
        title = "${sc.url.substring(0, 8)}... by $nick";
      }

      var subtitle = sc.primary ? "primary" : "secondary";

      stores.add(Card(
          child: ListTile(
        title: Text(
          title,
        ),
        subtitle: Text(subtitle),
      )));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "This is the list of stores for the coven ${_coven.name}",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          "Add your own store and help supporting more users with better performance",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        ListView(
          shrinkWrap: true,
          children: stores,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PlatformElevatedButton(
                child: const Text("Add store"),
                onPressed: () async {
                  var sc = await Navigator.push<StoreConfig?>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddStore(),
                    ),
                  );
                  if (sc != null) {
                    sc.primary = false;
                    setState(() {
                      _coven.safe.storeConfigs.add(sc);
                      _coven.safe.addStore(sc);
                    });
                  }
                },
              ),
            )
          ],
        ),
      ],
    );
  }
}
