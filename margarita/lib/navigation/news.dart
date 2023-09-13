import 'dart:async';

import 'package:flutter/material.dart';
import 'package:margarita/woland/woland.dart';

Map<String, DateTime> openSaves = {};

Timer? _timer;
List<String> _news = [];

checkNotifications() {
  var news = <String>[];

  for (var e in openSaves.entries) {
    var communityName = e.key;
    var lastOpen = e.value;

    news.addAll(checkForUpdates(communityName, "chat", lastOpen, 0));
  }
  return news;
}

BottomNavigationBarItem news2() {
  _timer ??= Timer.periodic(const Duration(minutes: 1), (timer) {
    var news = checkNotifications();
    if (news != _news) {
      _news = news;
    }
  });

  var count = _news.length;
  return BottomNavigationBarItem(
      icon: Icon(
          count == 0 ? Icons.notifications_none : Icons.notifications_active),
      label: count == 0 ? "No News" : "News ($count)");
}
