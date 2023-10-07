import 'package:flutter/material.dart';
import 'package:behemoth/apps/chat/chat.dart';
import 'package:behemoth/common/news_icon.dart';

import 'package:behemoth/coven/library.dart';
import 'package:behemoth/coven/people.dart';

var currentPanelIdx = <String, int>{};

class Room extends StatefulWidget {
  const Room({Key? key}) : super(key: key);

  @override
  State<Room> createState() => _RoomState();
}

class _RoomState extends State<Room> {
  List<Widget> _panels = [];
  int _currentItem = 0;

  @override
  Widget build(BuildContext context) {
    var safeName = ModalRoute.of(context)!.settings.arguments as String;
    if (_panels.isEmpty) {
      _panels = [Chat(safeName, ""), Library(safeName), People(safeName)];
    }
    openSaves[safeName] = DateTime.now();

    _currentItem = currentPanelIdx[safeName] ?? 0;
    var roomName = safeName.substring(safeName.lastIndexOf("/") + 1);
    var covenName = safeName.substring(0, safeName.lastIndexOf("/"));
    var title = "$roomName@$covenName";

    var items = const [
      BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.library_books),
        label: 'Library',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'People',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        actions: [
          const NewsIcon(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.exit_to_app)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(children: [
          Expanded(
            child: IndexedStack(
              index: _currentItem,
              children: _panels,
            ),
          ),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentItem,
        onTap: (int index) {
          setState(() {
            _currentItem = index;
            currentPanelIdx[safeName] = _currentItem;
          });
        },
        items: items,
      ),
    );
  }
}
