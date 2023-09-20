import 'dart:async';

import 'package:margarita/common/common.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/common/news_navigation_bar.dart';
import 'package:flutter/material.dart';
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
  // ignore: unused_field
  bool _refresh = false;

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
      return Scaffold(
        appBar: AppBar(title: const Text("Loading")),
      );
    }

    var profile = Profile.current();
    var widgets = profile.communities.values.map(
      (community) {
        return Card(
          child: ListTile(
            title: Text(community.name),
            onTap: () => Navigator.pushNamed(context, "/community",
                arguments: community),
          ),
        );
      },
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: // Your content here
            const Row(children: [
          Icon(Icons.group), // Add the desired icon
          SizedBox(width: 8), // Add some spacing between icon and text
          Text(
            "My Communities",
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              switch (result) {
                case 'join':
                  Navigator.pushNamed(context, "/join")
                      .then((value) => setState(() {
                            _refresh = true;
                          }));
                  break;
                case 'create':
                  Navigator.pushNamed(context, "/create")
                      .then((value) => setState(() {
                            _refresh = true;
                          }));
                  break;
                case 'settings':
                  Navigator.pushNamed(context, "/settings")
                      .then((value) => setState(() {
                            _refresh = true;
                          }));
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'join',
                child: Text('Join Community'),
              ),
              const PopupMenuItem<String>(
                value: 'create',
                child: Text('Create Community'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: widgets,
      ),
      bottomNavigationBar: const NewsNavigationBar(
        items: [],
      ),
    );
  }
}
