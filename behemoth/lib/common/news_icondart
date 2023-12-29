import 'dart:async';

import 'package:flutter/material.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Notification {
  Coven coven;
  String room;
  int updates;

  Notification(this.coven, this.room, this.updates);
}

typedef Notifications = List<Notification>;

class NewsIcon extends StatefulWidget {
  const NewsIcon({Key? key}) : super(key: key);

  @override
  State<NewsIcon> createState() => _NewsIconState();

  static Notifications notifications = [];

  static Timer? _timer;
  static DateTime _lastUpdate = DateTime(0);
  static Function(Notifications)? _onChange;

  static set onChange(Function(Notifications)? f) {
    if (f == _onChange) return;

    Future.delayed(const Duration(seconds: 1), () {
      _onChange = f;
      _timer?.cancel();
      if (_onChange != null) {
        _timer = Timer(const Duration(seconds: 30), _updateNotifications);
        if (DateTime.now().difference(_lastUpdate).inSeconds > 30) {
          _updateNotifications();
        }
      }
    });
  }

  static _updateNotifications() async {
    notifications = [];
    for (var coven in Coven.opened.values) {
      try {
        for (var room in coven.rooms) {
          var updates =
              await coven.safe.syncBucket("$room/chat", SyncOptions());
          if (updates > 0) {
            notifications.add(Notification(coven, room, updates));
          }
          // var files = await coven.safe
          //     .listFiles("$room/chat", ListOptions(knownSince: safe.accessed));
          // if (files.isNotEmpty) {}
          // files.where((e) => e.name.endsWith(".i")).forEach((element) {});
        }
      } catch (e) {
        continue;
      }
    }
    try {
      _onChange?.call(notifications);
    } catch (e) {
      //ignore
    }
    _lastUpdate = DateTime.now();
  }
}

class _NewsIconState extends State<NewsIcon> {
  static DateTime _nextRefresh = DateTime(0);
//  static Map<Safe, int> _news = {};

  @override
  void initState() {
    super.initState();
    if (_nextRefresh.year == 0) {
      var sib = getConfig("news", "next_refresh");
      if (!sib.missing) {
        _nextRefresh = DateTime.fromMillisecondsSinceEpoch(sib.i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //  _refresh();
    return PlatformIconButton(
      icon: NewsIcon.notifications.isEmpty
          ? const Icon(
              Icons.home) // Display the alarm_off icon when _news is empty
          : const Icon(Icons
              .notification_important_outlined), // Display the alarm icon when _news is not empty
      onPressed: () {
        Navigator.pushNamed(
          context,
          "/",
        );
      },
    );
  }
}
