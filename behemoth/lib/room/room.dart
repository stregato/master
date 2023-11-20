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
  String _title = "";
  Chat? _chat;
  Content? _content;
  People? _people;
  late Safe _lounge;
  Safe? _safe;

  @override
  Widget build(BuildContext context) {
    NewsIcon.onChange = (_) => setState(() {});

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
              _safe = snapshot.data!;
              switch (_currentItem) {
                case 0:
                  _chat ??= Chat(_safe!, "");
                  return _chat!;
                case 1:
                  _content ??= Content(_safe!);
                  return _content!;
                case 2:
                  _people ??= People(_safe!, _lounge);
                  return _people!;
                default:
                  return const Text("Unknown screen");
              }

              // var stack = <Widget>[];
              // for (var i = 0; i < _items.length; i++) {
              //   var e = _items[i];
              //   stack.add(ExcludeFocus(
              //     excluding: i != _currentItem,
              //     child: e,
              //   ));
              // }
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
