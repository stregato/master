import 'dart:async';
import 'dart:math';

import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class NewsIcon extends StatefulWidget {
  const NewsIcon({Key? key}) : super(key: key);

  @override
  State<NewsIcon> createState() => _NewsIconState();
}

class _NewsIconState extends State<NewsIcon> {
  Timer? _timer;
  static DateTime _nextRefresh = DateTime(0);
  static Map<Safe, int> _news = {};

  @override
  void initState() {
    super.initState();
//    _timer = Timer.periodic(const Duration(seconds: 10), _refresh);
    if (_nextRefresh.year == 0) {
      var sib = getConfig("news", "next_refresh");
      if (!sib.missing) {
        _nextRefresh = DateTime.fromMillisecondsSinceEpoch(sib.i);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _refresh() async {
    if (mounted && DateTime.now().isAfter(_nextRefresh)) {
      var news = await checkNotifications();
      var diff = news.length - _news.length;
      diff = 1 + diff * diff;
      setState(() {
        _news = news;
        _nextRefresh =
            DateTime.now().add(Duration(seconds: max((120 / diff).ceil(), 10)));
        setConfig("news", "next_refresh",
            SIB.fromInt(_nextRefresh.millisecondsSinceEpoch));
      });
    }
  }

  void showNotifications(Map<Safe, int> news) {
    var entries = news.entries.toList();
    entries.sort((a, b) => a.key.name.compareTo(b.key.name));
    var notificationsList = entries.map(
      (e) {
        var safe = e.key;
        var count = e.value;
        return Card(
          child: ListTile(
            title: Text("${safe.prettyName} ($count)"),
            onTap: () {
              _news.remove(safe);
              Navigator.pop(context);
              Navigator.pushNamed(context, "/coven/room",
                  arguments: {"name": safe.name, "future": () async => safe});
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
                PlatformElevatedButton(
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

  static Future<Map<Safe, int>> checkNotifications() async {
    var news = <Safe, int>{};
    for (var safe in Coven.safes.values) {
      try {
        var files = await safe.listFiles(
            "chat", ListOptions(knownSince: safe.accessed));
        if (files.isNotEmpty) {
          news[safe] = files.length;
        }
        files.where((e) => e.name.endsWith(".i")).forEach((element) {});
      } catch (e) {
        continue;
      }
    }

    return news;
  }

  @override
  Widget build(BuildContext context) {
    _refresh();
    return PlatformIconButton(
      icon: _news.isEmpty
          ? const Icon(Icons
              .notifications_none) // Display the alarm_off icon when _news is empty
          : const Icon(Icons
              .notifications_active), // Display the alarm icon when _news is not empty
      onPressed: () {
        showNotifications(_news);
      },
    );
  }
}
