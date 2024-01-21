import 'dart:async';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/cockpit.dart';
import 'package:behemoth/room/status.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/chat.dart';

import 'package:behemoth/content/content.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

var currentPanelIdx = <String, int>{};

class Room extends StatefulWidget {
  const Room({super.key});

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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), _updateSafe);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateSafe(Timer _) {
    if (_coven.isOpen) {
      var safe = _coven.safe;
      var connected = safe.connected;
      var permission = safe.permission;

      safe.update();
      if (connected != safe.connected || permission != safe.permission) {
        setState(() {});
      }
    }
  }

  void updateUnread(int unread) {
    if (unread != _unread) {
      setState(() {
        _unread = unread;
      });
    }
  }

  Widget _errorBuilder(BuildContext context, Object? error) {
    var message = "Technical Error: $error";
    return PlatformScaffold(
      body: SingleChildScrollView(
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
        ),
      ),
    );
  }

  Widget _roomBuilder(BuildContext context) {
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

    if (!_coven.rooms.contains(_room)) {
      _coven.addRoom(_room);
      Profile.current.update(_coven);
    }

    var barItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dataset),
        label: 'Content',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
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

    var invite = PlatformIconButton(
        onPressed: _coven.isOpen
            ? () async {
                await Navigator.pushNamed(context, "/invite", arguments: {
                  "coven": _coven,
                  "room": _room,
                });
              }
            : null,
        icon: const Icon(Icons.person_add));

    var connected = IconButton(
        onPressed: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => Status(_coven)));
        },
        icon: _coven.safe.connected
            ? _coven.safe.permission == 0
                ? const Icon(Icons.block, color: Colors.red)
                : const Icon(
                    Icons.link,
                    color: Colors.green,
                  )
            : const Icon(Icons.link_off));

    Widget? body;
    switch (_currentItem) {
      case 0:
        _content ??= Content(_coven, _room);
        body = _content;
      case 1:
        _chat ??= Chat(_coven, _room, "");
        body = _chat;
      case 2:
        body = _cockpit;
      default:
        body = const Text("Unknown screen");
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_title, style: const TextStyle(fontSize: 18)),
        trailingActions: [
          connected,
          invite,
        ],
      ),
      body: body,
      bottomNavBar: PlatformNavBar(
        items: barItems,
        currentIndex: _currentItem,
        itemChanged: (newItem) {
          setState(() {
            _currentItem = newItem;
          });
        },
      ),
    );
  }

  Widget _builder(BuildContext context, AsyncSnapshot<Safe> snapshot) {
    if (snapshot.hasError) {
      return _errorBuilder(context, snapshot.error);
    }
    if (snapshot.hasData) {
      return _roomBuilder(context);
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text("Opening ${_coven.name}")),
      body: const CatProgressIndicator("opening the room"),
    );
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _room = args['room'] as String;
    _coven = args['coven'] as Coven;

    return FutureBuilder<Safe>(
      future: _coven.open(),
      builder: _builder,
    );
  }
}
