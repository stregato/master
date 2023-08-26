import 'dart:async';
import 'dart:isolate';

import 'package:margarita/common/common.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/navigation/bar.dart';
import 'package:margarita/safe/portal.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static StreamSubscription<Uri?>? linkSub;
  Uri? _unilink;

  @override
  void initState() {
    super.initState();
    if (!isDesktop && linkSub == null) {
      try {
        getInitialUri().then((uri) {
          _unilink = uri;
          linkSub = uriLinkStream.listen((uri) => setState(() {
                _unilink = uri;
              }));
        });
      } on PlatformException {
        //platform does not support
      }
    }
  }

  void _processUnilink(BuildContext context) {
    if (_unilink == null) {
      return;
    }

    setState(() {
      var segments = _unilink!.pathSegments;
      switch (segments[0]) {
        case "invite":
          if (segments.length == 2) {
            var token = Uri.decodeComponent(segments[1]);
            Future.delayed(
                const Duration(milliseconds: 100),
                () => Navigator.pushNamed(context, "/addPortal/import",
                    arguments: token));
          }
          break;
        case "id":
          break;
      }
      _unilink = null;
    });
  }

  Future<Object?> open(
      BuildContext context, Profile currentProfile, String portalName,
      [bool mounted = true]) async {
    var token = currentProfile.portals[portalName]!;
    var p = await progressDialog(context, "Connecting to $portalName...",
        Isolate.run(() {
      return openPortal(currentProfile.identity, token, OpenOptions());
    }), errorMessage: "cannot connect to $portalName");
    if (p != null && context.mounted) {
      return Navigator.pushNamed(context, "/portal",
          arguments: PortalViewArgs(portalName));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _processUnilink(context);

    var widgets = currentProfile.portals.keys.map(
      (name) {
        return Card(
          child: ListTile(
            title: Text(name),
            onTap: () => open(context, currentProfile, name).then((value) {
              setState(() {});
            }),
          ),
        );
      },
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Portals"),
        actions: [
          ElevatedButton(
            child: const Text("Add"),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal")
                  .then((value) => {setState(() {})});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: widgets,
      ),
      bottomNavigationBar: const MainNavigationBar(null),
    );
  }
}
