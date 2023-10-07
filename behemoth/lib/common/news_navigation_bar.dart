//import 'package:behemoth/woland/woland.dart' as w;
//import 'package:behemoth/woland/woland_def.dart' as w;
import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/woland_def.dart';
//import 'package:behemoth/portal/pool.dart';
//import 'package:basic_utils/basic_utils.dart';

var openSaves = <String, DateTime>{};

class NewsNavigationBar extends StatefulWidget {
  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int>? onTap;

  const NewsNavigationBar(
      {Key? key, required this.items, this.onTap, this.currentIndex = 0})
      : super(key: key);

  @override
  State<NewsNavigationBar> createState() => _NewsNavigationBarState();
}

class _NewsNavigationBarState extends State<NewsNavigationBar> {
  late int _currentIndex;
  Timer? _timer;
  DateTime _nextRefresh = DateTime(0);

  static Map<String, int> _news = {};

  _NewsNavigationBarState() {
    _currentIndex = 0;
  }
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), _refresh);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _refresh(Timer timer) async {
    if (mounted && DateTime.now().isAfter(_nextRefresh)) {
      var news = await Isolate.run<Map<String, int>>(
          () => checkNotifications(openSaves, Profile.current()));
      var diff = news.length - _news.length;
      diff = 1 + diff * diff;
      setState(() {
        _news = news;
        _nextRefresh =
            DateTime.now().add(Duration(seconds: max((120 / diff).ceil(), 10)));
      });
    }
  }

  void showNotifications(Map<String, int> news) {
    var entries = news.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    var notificationsList = entries.map(
      (e) {
        var sn = e.key;
        var community = sn.substring(0, sn.lastIndexOf("/"));
        var space = sn.substring(sn.lastIndexOf("/") + 1);
        var safeName = "$community/$space";
        var count = e.value;
        return Card(
          child: ListTile(
            title: Text("$space@$community ($count)"),
            onTap: () {
              _news.remove(safeName);
              Navigator.pop(context);
              Navigator.pushNamed(context, "/coven/room", arguments: safeName);
            },
          ),
        );
      },
    ).toList();

    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return Padding(
              padding: const EdgeInsets.all(1.0),
              child: Column(children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment
                        .center, // Center the icon and text horizontally
                    children: <Widget>[
                      Icon(Icons.home), // Add the Home icon
                      SizedBox(
                          width:
                              8), // Add some spacing between the icon and text
                      Text("Back to Home"),
                    ],
                  ),
                ),
                ListView(
                  shrinkWrap: true,
                  children: notificationsList,
                )
              ]));
        });
  }

  static Map<String, DateTime> failedSafes = {};

  static Map<String, int> checkNotifications(
      Map<String, DateTime> openSaves, Profile profile) {
    var news = <String, int>{};
    for (var c in profile.covens.values) {
      for (var e in c.rooms.entries) {
        var safeName = "${c.name}/${e.key}";
        var access = e.value;
        if (failedSafes.containsKey(safeName) &&
            (!openSaves.containsKey(safeName) ||
                openSaves[safeName]!.isBefore(failedSafes[safeName]!))) {
          continue;
        }
        try {
          openSafe(profile.identity, access, OpenOptions());
          var lastOpen = openSaves[safeName] ??
              DateTime.now().add(-const Duration(days: 1));
          var files =
              listFiles(safeName, "chat", ListOptions(knownSince: lastOpen));
          if (files.isNotEmpty) {
            news[safeName] = files.length;
          }
          files.where((e) => e.name.endsWith(".i")).forEach((element) {});
        } catch (e) {
          failedSafes[safeName] = DateTime.now();
          continue;
        }
      }
    }
    return news;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (idx) {
        setState(() {
          _currentIndex = idx;
        });
        if (idx == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (idx <= widget.items.length) {
          widget.onTap?.call(idx - 1);
        } else if (idx == widget.items.length + 1) {
          showNotifications(_news);
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        ...widget.items,
        BottomNavigationBarItem(
            icon: Icon(_news.isEmpty
                ? Icons.notifications_none
                : Icons.notifications_active),
            label: _news.isEmpty ? "No News" : "News (${_news.length})")
      ],
    );
  }
}
