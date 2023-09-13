import 'dart:async';

//import 'package:margarita/woland/woland.dart' as w;
//import 'package:margarita/woland/woland_def.dart' as w;
import 'package:flutter/material.dart';
import 'package:margarita/navigation/news.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
//import 'package:margarita/portal/pool.dart';
//import 'package:basic_utils/basic_utils.dart';

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
  Timer? _timer;
  late int _currentIndex;

  _NewsNavigationBarState() {
    _currentIndex = 0;
    _timer ??= Timer.periodic(
      const Duration(minutes: 10),
      (Timer t) {
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void showNotifications(Map<String, int> news) {
    var entries = news.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    var notificationsList = entries.map(
      (e) {
        var sn = e.key;
        var community = sn.substring(0, sn.lastIndexOf("/"));
        var space = sn.substring(sn.lastIndexOf("/") + 1);
        var count = e.value;
        return Card(
          child: ListTile(
            title: Text("$space@$community ($count)"),
            // subtitle: e.message.isNotEmpty ? Text(e.message) : null,
            // trailing: appsIcons[e.app] != null
            //     ? Text(StringUtils.capitalize(e.app))
            //     : Row(children: [
            //         Text(StringUtils.capitalize(e.app)),
            //         Icon(appsIcons[e.app])
            //       ]),
            onTap: () {
              // Navigator.pushNamed(context, "/apps/${e.app}",
              //     arguments: e.pool);
            },
          ),
        );
      },
    ).toList();

    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return Padding(
              padding: const EdgeInsets.all(32.0),
              child: ListView(
                shrinkWrap: true,
                children: notificationsList,
              ));
        });
  }

  Map<String, int> checkNotifications() {
    var news = <String, int>{};

    for (var e in openSaves.entries) {
      var lastOpen = openSaves[e.key] ?? DateTime.fromMicrosecondsSinceEpoch(0);
      var files = listFiles(e.key, "chat", ListOptions(knownSince: lastOpen));
      if (files.isNotEmpty) {
        news[e.key] = files.length;
      }
    }
    return news;
  }

  @override
  Widget build(BuildContext context) {
    var news = checkNotifications();
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (idx) {
        setState(() {
          _currentIndex = idx;
        });
        if (idx < widget.items.length) {
          widget.onTap?.call(idx);
        } else if (idx == widget.items.length) {
          showNotifications(news);
        }
      },
      items: [
        ...widget.items,
        BottomNavigationBarItem(
            icon: Icon(news.isEmpty
                ? Icons.notifications_none
                : Icons.notifications_active),
            label: news.isEmpty ? "No News" : "News (${news.length})")
      ],
    );
  }
}
