import 'dart:async';

import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/coven/create_coven.dart';
import 'package:behemoth/coven/join.dart';
import 'package:behemoth/settings/reset.dart';
import 'package:behemoth/settings/setup.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

var started = false;

class _HomeState extends State<Home> {
  static StreamSubscription<Uri?>? linkSub;
  Uri? _unilink;
  bool _connecting = false;
  bool _hasProfile = false;
  int _selectedIndex = 0;

  // ignore: unused_field

  @override
  void initState() {
    super.initState();

    if (!started) {
      try {
        start("$applicationFolder/woland.db", applicationFolder);
        started = true;
      } catch (e) {
        return;
      }
    }

    if (!Profile.hasProfile()) {
      return;
    }
    _hasProfile = true;

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
    var segments = _unilink!.pathSegments;
    switch (segments[0]) {
      case "i":
        if (segments.length == 3) {
          var url = _unilink.toString();
          Future.delayed(
              const Duration(milliseconds: 100),
              () => Navigator.pushNamed(context, "/invite", arguments: {
                    "url": url,
                  }));
        }
        break;
      case "a":
        if (segments.length == 2) {
          var url = _unilink.toString();
          Future.delayed(
              const Duration(milliseconds: 100),
              () => Navigator.pushNamed(
                    context,
                    "/join",
                    arguments: url,
                  ));
        }
      case "p":
        if (segments.length == 2) {
          Navigator.pushNamed(context, "/settings/import_id",
              arguments: _unilink);
        }
        break;
    }

    setState(() {
      _unilink = null;
    });
  }

  void _backToList() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  connectAll(BuildContext context) async {
    setState(() {
      _connecting = true;
    });

    List<Coven> covens = Profile.current.covens.values.toList();
    for (var coven in covens) {
      try {
        await coven.open();
      } catch (e) {
        if (!mounted) return;
        showPlatformSnackbar(context, "Failed to connect to ${coven.name}",
            backgroundColor: Colors.red);
      }
    }
    setState(() {
      _connecting = false;
    });
  }

  Widget getNewbiePage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            "Welcome to Behemoth",
            style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: Colors.yellow),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset("assets/images/icons8-behemoth.png"),
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            "Behemoth is a secure, decentralized, collaborative application. "
            "It is based on storages where data is encrypted and shared between "
            "users.",
            style: TextStyle(fontSize: 16.0, color: Colors.grey),
            maxLines: 5,
            textAlign:
                TextAlign.justify, // Set the maximum number of lines to 3
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            "Create a  coven or join an existing one",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16.0, color: Colors.green),
          ),
          const SizedBox(
            height: 18,
          ),
          const Icon(Icons.arrow_downward, color: Colors.green, size: 60),
        ],
      ),
    );
  }

  Widget getMyCovens() {
    var profile = Profile.current;
//    var widgets = getNotificationsWidgets();
    var widgets = <Card>[];
    widgets.addAll(profile.covens.values.map(
      (coven) {
        return Card(
          child: PlatformListTile(
            title: PlatformText(coven.name),
            trailing: Coven.opened.containsKey(coven.name)
                ? const Icon(Icons.link)
                : _connecting
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.lock),
            onTap: () async {
//              NewsIcon.onChange = null;
              Navigator.of(context).popUntil((route) => route.isFirst);
              await Navigator.pushNamed(context, "/coven/room", arguments: {
                "coven": coven,
                "room": "lounge",
              });
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {});
                }
              });
            },
//
          ),
        );
      },
    ).toList());

    var noCovens = profile.covens.values.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: noCovens
          ? getNewbiePage()
          : Column(
              children: [
                ListView(
                  shrinkWrap: true,
                  children: widgets,
                ),
                if (profile.covens.values.isNotEmpty)
                  SizedBox(
                    width: double
                        .infinity, // This will make the container fill the width of the Column
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: PlatformElevatedButton(
                        onPressed: () => connectAll(context),
                        child: const Text("Connect all"),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!started) {
      return const Reset();
    }
    if (!_hasProfile) {
      return const Setup();
    }
    var profile = Profile.current;
    Widget body;

    switch (_selectedIndex) {
      case 0:
        body = getMyCovens();
      case 1:
        body = Join(onComplete: _backToList);
      case 2:
        body = CreateCoven(onComplete: _backToList);
      default:
        body = const Text("Unknown screen");
    }

    _processUnilink(context);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: // Your content here
            Row(children: [
          const SizedBox(width: 8), // Add some spacing between icon and text
          Text(
            "Hi ${profile.identity.nick}",
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        // trailingActions: [
        // PlatformIconButton(
        //     onPressed: () async {
        //       NewsIcon.onChange = null;
        //       Navigator.of(context).popUntil((route) => route.isFirst);
        //       await Navigator.pushNamed(context, "/settings");
        //       setState(() {});
        //     },
        //     icon: const Icon(Icons.settings)),
        // ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: body,
        ),
      ),
      bottomNavBar: PlatformNavBar(
        currentIndex: _selectedIndex,
        itemChanged: (idx) async {
          setState(() {
            _selectedIndex = idx;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'My Covens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Join',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Create',
          ),
        ],
      ),
    );
  }
}
