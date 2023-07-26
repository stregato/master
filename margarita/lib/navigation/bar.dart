import 'dart:async';

//import 'package:margarita/woland/woland.dart' as w;
//import 'package:margarita/woland/woland_def.dart' as w;
import 'package:flutter/material.dart';
//import 'package:margarita/portal/pool.dart';
//import 'package:basic_utils/basic_utils.dart';

class MainNavigationBar extends StatefulWidget {
  final String? poolName;
  final bool settings;
  const MainNavigationBar(
    this.poolName, {
    Key? key,
    this.settings = false,
  }) : super(key: key);

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  static Timer? _timer;
//  static List<sp.Notification> _notifications = [];
  static List<String> _notifications = [];

  checkNotifications() {
    setState(() {
      _notifications = [];
      //  sp.notifications(DateTime.now().subtract(const Duration(days: 1)));
    });
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   _timer?.cancel();
  //   _timer = null;
  // }

  void showNotifications() {
    var notificationsList = _notifications
        .map(
          (e) => const Card(
            child: ListTile(
                // title: Text(e.count > 0 ? "${e.pool} (${e.count})" : e.pool),
                // subtitle: e.message.isNotEmpty ? Text(e.message) : null,
                // trailing: appsIcons[e.app] != null
                //     ? Text(StringUtils.capitalize(e.app))
                //     : Row(children: [
                //         Text(StringUtils.capitalize(e.app)),
                //         Icon(appsIcons[e.app])
                //       ]),
                // onTap: () {
                //   Navigator.pushNamed(context, "/apps/${e.app}",
                //       arguments: e.pool);
                // },
                ),
          ),
        )
        .toList();

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

  @override
  Widget build(BuildContext context) {
    if (_timer == null) {
      Future.delayed(const Duration(seconds: 1), checkNotifications);
      _timer ??= Timer.periodic(
        const Duration(minutes: 10),
        (Timer t) {
          checkNotifications();
        },
      );
    }

    var count = 0;
    // for (var e in _notifications) {
    //   count += e.count;
    // }

    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (idx) {
        switch (idx) {
          case 0:
            Navigator.of(context).popUntil((route) => route.isFirst);
            break;
          case 1:
            widget.poolName == null
                ? Navigator.pushNamed(context, '/settings')
                : Navigator.pushNamed(context, '/pool/settings',
                    arguments: widget.poolName);
            break;
          case 2:
            showNotifications();
            break;
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        widget.poolName == null
            ? const BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: "Settings")
            : const BottomNavigationBarItem(
                icon: Icon(Icons.waves), label: "Pool"),
        BottomNavigationBarItem(
            icon: Icon(count == 0
                ? Icons.notifications_none
                : Icons.notifications_active),
            label: count == 0 ? "No News" : "News ($count)")
      ],
    );
  }
}
