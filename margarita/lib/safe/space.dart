import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/chat.dart';
import 'package:margarita/common/news_navigation_bar.dart';
import 'package:margarita/safe/library.dart';

class ZoneViewArgs {
  String safeName;
  String zoneName;
  ZoneViewArgs(this.safeName, this.zoneName);
}

var currentPanelIdx = <String, int>{};

class Space extends StatefulWidget {
  const Space({Key? key}) : super(key: key);

  @override
  State<Space> createState() => _SpaceState();
}

class _SpaceState extends State<Space> {
  List<Widget> _panels = [];
  int _currentItem = 0;

  @override
  Widget build(BuildContext context) {
    var safeName = ModalRoute.of(context)!.settings.arguments as String;
    if (_panels.isEmpty) {
      _panels = [Chat(safeName, ""), Library(safeName)];
    }
    openSaves[safeName] = DateTime.now();

    _currentItem = currentPanelIdx[safeName] ?? 0;
    var title = safeName.split("/").reversed.join("@");

    var items = const [
      BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.library_books),
        label: 'Library',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 18)),
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
      //body:  _panels[_currentIndex],
      bottomNavigationBar: NewsNavigationBar(
        onTap: (int index) {
          setState(() {
            _currentItem = _currentItem == 0 ? 1 : 0;
            currentPanelIdx[safeName] = _currentItem;
          });
        },
        items: [
          items[_currentItem == 0 ? 1 : 0],
        ],
      ),
    );
  }
}