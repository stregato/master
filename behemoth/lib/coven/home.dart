import 'dart:async';

import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static StreamSubscription<Uri?>? linkSub;
  Uri? _unilink;
  bool _connecting = false;

  // ignore: unused_field

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

  List<Card> getNotificationsWidgets() {
    var entries = NewsIcon.notifications.entries.toList();
    entries.sort((a, b) => a.key.name.compareTo(b.key.name));
    return entries.map(
      (e) {
        var safe = e.key;
        Safe lounge;
        Future<Safe> future() async {
          return safe;
        }

        if (safe.name.endsWith("/lounge")) {
          lounge = safe;
        } else {
          var parts = covenAndRoom(safe.name);
          lounge = Coven.safes["${parts[0]}/lounge"]!;
        }

        var count = e.value;
        return Card(
          child: PlatformListTile(
            title: PlatformText("${safe.prettyName} ($count)"),
            trailing: const Icon(Icons.notifications),
            onTap: () async {
              NewsIcon.notifications.remove(safe);
              Navigator.of(context).popUntil((route) => route.isFirst);
              await Navigator.pushNamed(context, "/coven/room", arguments: {
                "name": safe.name,
                "future": future(),
                "lounge": lounge,
              });
              setState(() {});
            },
          ),
        );
      },
    ).toList();
  }

  connectAll() async {
    setState(() {
      _connecting = true;
    });

    List<Coven> covens = Profile.current().covens.values.toList();
    for (var coven in covens) {
      try {
        await coven.getLounge();
      } catch (e) {
        //ignore
      }
    }
    setState(() {
      _connecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _processUnilink(context);
    NewsIcon.onChange = (_) {
      setState(() {});
    };

    if (!Profile.hasProfile()) {
      return PlatformScaffold(
        appBar: PlatformAppBar(title: const Text("Loading")),
      );
    }

    var profile = Profile.current();
    var widgets = getNotificationsWidgets();
    widgets.addAll(profile.covens.values.map(
      (coven) {
        return Card(
          child: PlatformListTile(
            title: PlatformText(coven.name),
            trailing: Coven.safes.keys.contains("${coven.name}/lounge")
                ? const Icon(Icons.link)
                : _connecting
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.lock),
            onTap: () async {
              NewsIcon.onChange = null;
              Navigator.of(context).popUntil((route) => route.isFirst);
              await Navigator.pushNamed(context, "/coven", arguments: coven);
              setState(() {});
            },
//
          ),
        );
      },
    ).toList());

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: // Your content here
            Row(children: [
          const Icon(Icons.home), // Add the desired icon
          const SizedBox(width: 8), // Add some spacing between icon and text
          Text(
            "Hi ${profile.identity.nick}",
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        trailingActions: [
          PlatformIconButton(
              onPressed: () async {
                NewsIcon.onChange = null;
                Navigator.of(context).popUntil((route) => route.isFirst);
                await Navigator.pushNamed(context, "/settings");
                setState(() {});
              },
              icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListView(
                shrinkWrap: true,
                children: widgets,
              ),
              SizedBox(
                width: double
                    .infinity, // This will make the container fill the width of the Column
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: PlatformElevatedButton(
                    onPressed: connectAll,
                    child: const Text("Connect all"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavBar: PlatformNavBar(
        itemChanged: (idx) async {
          setState(() {});
          switch (idx) {
            case 1:
              NewsIcon.onChange = null;
              Navigator.of(context).popUntil((route) => route.isFirst);
              await Navigator.pushNamed(context, "/join");
              setState(() {});
              if (!mounted) return;
              break;
            case 2:
              NewsIcon.onChange = null;
              Navigator.of(context).popUntil((route) => route.isFirst);
              await Navigator.pushNamed(context, "/create");
              setState(() {});
              if (!mounted) return;
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
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
