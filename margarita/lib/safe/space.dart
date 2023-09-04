import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/chat.dart';
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
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    var safeName = ModalRoute.of(context)!.settings.arguments as String;
    if (_panels.isEmpty) {
      _panels = [Chat(safeName), Library(safeName)];
    }

    _currentIndex = currentPanelIdx[safeName] ?? 0;
    var title = safeName.split("/").reversed.join("@");

    return Scaffold(
      appBar: AppBar(
          title: Text(title, style: const TextStyle(fontSize: 18)),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.pushNamed(context, "/addPortal");
              },
            ),
          ]),
      body: _panels[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
            currentPanelIdx[safeName] = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
