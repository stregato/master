import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/chat.dart';
import 'package:margarita/safe/library.dart';

class ZoneViewArgs {
  String portalName;
  String zoneName;
  ZoneViewArgs(this.portalName, this.zoneName);
}

class ZoneView extends StatefulWidget {
  const ZoneView({Key? key}) : super(key: key);

  @override
  State<ZoneView> createState() => _ZoneViewState();
}

class _ZoneViewState extends State<ZoneView> {
  List<Widget> _panels = [];
  final List<String> _panelNames = ["Chat", "Library"];
  final List<IconData> _panelIcons = [Icons.chat, Icons.library_books];
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as ZoneViewArgs;
    if (_panels.isEmpty) {
      _panels = [
        Chat(args.portalName, args.zoneName),
        Library(args.portalName, args.zoneName)
      ];
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(" ${args.portalName}: ${_panelNames[_currentIndex]}"),
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
