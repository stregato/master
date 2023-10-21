import 'dart:async';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/news_icon.dart';

import 'package:behemoth/content/content.dart';
import 'package:behemoth/coven/people.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

var currentPanelIdx = <String, int>{};

class Room extends StatefulWidget {
  const Room({Key? key}) : super(key: key);

  @override
  State<Room> createState() => _RoomState();
}

class _RoomState extends State<Room> {
  int _currentItem = 0;
  Timer? _timer;
  String _title = "";
  List<Widget> _items = [];
  late Safe _lounge;
  Safe? _safe;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    var future = args['future'] as Future<Safe>;
    _lounge = args['lounge'] as Safe;
    if (_title.isEmpty) {
      _title = args['name'] as String;
      _currentItem = currentPanelIdx[_title] ?? 0;
    }

    var addPerson = PlatformIconButton(
        onPressed: () async {
          if (_safe == null) return;
          await Navigator.pushNamed(context, "/coven/add_person",
              arguments: {"safe": _safe, "lounge": _lounge});
          if (!mounted) return;
          Navigator.pop(context);
        },
        icon: const Icon(Icons.person_add));

    var items = const [
      BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.dataset),
        label: 'Content',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'People',
      ),
    ];

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_title, style: const TextStyle(fontSize: 18)),
        trailingActions: [
          const NewsIcon(),
          const SizedBox(width: 10),
          addPerson,
        ],
      ),
      body: FutureBuilder<Safe>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (_items.isEmpty) {
                _safe = snapshot.data!;
                _items = [
                  Chat(_safe!, ""),
                  Content(_safe!),
                  People(_safe!, _lounge),
                ];
              }

              var stack = <Widget>[];
              for (var i = 0; i < _items.length; i++) {
                var e = _items[i];
                stack.add(ExcludeFocus(
                  excluding: i != _currentItem,
                  child: e,
                ));
              }

              return IndexedStack(
                index: _currentItem,
                children: stack,
              );
            } else {
              return CatProgressIndicator("opening $_title");
            }
          }),
      bottomNavBar: PlatformNavBar(
        currentIndex: _currentItem,
        itemChanged: (int index) {
          setState(() {
            _currentItem = index;
          });
          currentPanelIdx[_title] = index;
        },
        items: items,
      ),
    );
  }
}
