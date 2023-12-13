import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/cockpit.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/chat.dart';
import 'package:behemoth/common/news_icon.dart';

import 'package:behemoth/content/content.dart';
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
  late Cockpit _cockpit;
  late Coven _coven;
  late String _room;
  int _unread = 0;

  void updateUnread(int unread) {
    if (unread != _unread) {
      setState(() {
        _unread = unread;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    NewsIcon.onChange = (_) => setState(() {});

    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _room = args['room'] as String;
    _coven = args['coven'] as Coven;
    if (_title.isEmpty) {
      _title = "$_room@${_coven.name}";
      _currentItem = currentPanelIdx[_title] ?? 0;
      _cockpit = Cockpit(_coven, _room, updateUnread: (unread) {
        if (unread != _unread) {
          setState(() {
            _unread = unread;
          });
        }
      });
    }

    var invite = PlatformIconButton(
        onPressed: () async {
          await Navigator.pushNamed(context, "/invite", arguments: {
            "coven": _coven,
            "room": _room,
          });
        },
        icon: const Icon(Icons.person_add));

    var items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.dataset),
        label: 'Content',
      ),
      BottomNavigationBarItem(
        icon: _unread > 0
            ? const Icon(
                Icons.explore,
                color: Colors.yellowAccent,
              )
            : const Icon(Icons.explore),
        label: _unread == 0 ? 'Cockpit' : 'Cockpit ($_unread)',
      ),
    ];

    return PlatformScaffold(
      appBar: PlatformAppBar(
//        leading: const NewsIcon(),
        title: Text(_title, style: const TextStyle(fontSize: 18)),
        trailingActions: [
          // const NewsIcon(),
          invite,
        ],
      ),
      body: FutureBuilder<Safe>(
          future: _coven.open(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              var message = snapshot.error.toString();
              if (message == "access pending") {
                message = "Admin didn't provide access yet. Retry later.";
              } else if (message == "access denied") {
                message = "Admin removed your access.";
              } else {
                message = "Technical Error: $message";
              }

              return Center(
                  child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.lock, size: 40),
                  const SizedBox(height: 20),
                  PlatformText(message),
                  const SizedBox(height: 40),
                  PlatformElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                    child: PlatformText('Back to Home'),
                  ),
                  const SizedBox(height: 20),
                  PlatformElevatedButton(
                    onPressed: () {
                      var p = Profile.current;
                      p.covens.remove(_coven.name);
                      p.save();
                      Navigator.pop(context);
                    },
                    color: Colors.red,
                    child: PlatformText('Remove the coven ${_coven.name}'),
                  ),
                  const Spacer(),
                  PlatformText(
                      "tecnical details may be available in the logs (app settings)",
                      style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 4)
                ],
              ));
            }
            if (snapshot.hasData) {
              if (!_coven.rooms.contains(_room)) {
                _coven.addRoom(_room);
                Profile.current.update(_coven);
              }

              switch (_currentItem) {
                case 0:
                  _chat ??= Chat(_coven, _room, "");
                  return _chat!;
                case 1:
                  _content ??= Content(_coven, _room);
                  return _content!;
                case 2:
                  return _cockpit;
                // _people ??= People(_safe!, _coven.getLoungeSync()!);
                // return _people!;
                default:
                  return const Text("Unknown screen");
              }
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
          if (index != 2) {
            currentPanelIdx[_title] = index;
          }
        },
        items: items,
      ),
    );
  }
}
