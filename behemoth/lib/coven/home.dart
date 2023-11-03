import 'dart:async';

import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/common/profile.dart';
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
  late Timer _timer;

  // ignore: unused_field
  bool _refresh = false;

  @override
  void initState() {
    super.initState();
    _timer =
        Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));
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

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
            Future.delayed(const Duration(milliseconds: 100),
                () => Navigator.pushNamed(context, "/token", arguments: token));
          }
          break;
        case "id":
          break;
      }
      _unilink = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _processUnilink(context);
    _refresh = false;

    if (!Profile.hasProfile()) {
      return PlatformScaffold(
        appBar: PlatformAppBar(title: const Text("Loading")),
      );
    }

    var profile = Profile.current();
    var widgets = profile.covens.values.map(
      (community) {
        return Card(
          child: PlatformListTile(
            title: PlatformText(community.name),
            onTap: () =>
                Navigator.pushNamed(context, "/coven", arguments: community),
          ),
        );
      },
    ).toList();

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
          const NewsIcon(),
          const SizedBox(width: 10),
          PlatformIconButton(
              onPressed: () {
                Navigator.pushNamed(context, "/settings")
                    .then((value) => setState(() {
                          _refresh = true;
                        }));
              },
              icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: widgets,
        ),
      ),
      bottomNavBar: PlatformNavBar(
        itemChanged: (idx) {
          setState(() {});
          switch (idx) {
            case 1:
              Navigator.pushNamed(context, "/join")
                  .then((value) => setState(() {
                        _refresh = true;
                      }));
              break;
            case 2:
              Navigator.pushNamed(context, "/create")
                  .then((value) => setState(() {
                        _refresh = true;
                      }));
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
