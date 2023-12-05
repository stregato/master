// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/theme.dart';
import 'package:behemoth/common/file_access.dart' as fa;
import 'package:file_icon/file_icon.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'dart:collection';
import 'package:path/path.dart' as path;

import 'package:path/path.dart';

class Content extends StatefulWidget {
  final Coven coven;
  final String room;
  const Content(this.coven, this.room, {Key? key}) : super(key: key);

  @override
  State<Content> createState() => _ContentState();
}

class UploadArgs {
  String poolName;
  fa.FileSelection selection;
  UploadArgs(this.poolName, this.selection);
}

class _ContentState extends State<Content> {
  AppTheme theme = LightTheme();

  String _dir = "";
  late Timer _timer;
  late String _room;
  late Safe _safe;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _safe = widget.coven.safe;
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      await _safe.syncBucket("rooms/$_room/content", SyncOptions());
      _read();
    });
    Future.delayed(Duration.zero, () async {
      await _safe.syncBucket("rooms/$_room/content", SyncOptions());
      _read();
    });
    _read();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getState(String name, List<Header> headers) {
    var localFile = path.join(documentsFolder, _safe.name, _room, name);
    var localStat = File(localFile).statSync();

    if (headers.isEmpty) {
      return "unstaged";
    }

    headers.sort((a, b) => b.modTime.compareTo(a.modTime));
    var idx = headers.indexWhere((h) => h.downloads[localFile] != null);
    if (idx < 0) {
      if (File(localFile).existsSync()) {
        return "conflict";
      }
      return headers[0].uploading ? "uploading" : "new";
    }
    var downloadTime = headers[idx].downloads[localFile]!;
    var uploading = headers[idx].uploading;
    var modified = localStat.modified.difference(downloadTime).inMinutes > 1;
    if (modified) {
      return idx == 0 ? "modified" : "conflict";
    } else {
      return idx == 0
          ? uploading
              ? "uploading"
              : "sync"
          : "updated";
    }
  }

  Color? _colorForState(String state) {
    switch (state) {
      case "sync":
        return Colors.green;
      case "updated":
        return Colors.blue;
      case "modified":
        return Colors.yellow;
      case "conflict":
        return Colors.redAccent;
      case "new":
        return Colors.blue;
      default:
        return null;
    }
  }

  Future<List<Header>> _libraryList(String dir) async {
    var options = ListOptions(dir: dir);
    return _safe.listFiles("rooms/$_room/content", options);
  }

  Future<List<String>> _libraryDirs(String folder) async {
    var options = ListDirsOptions(dir: folder);
    return _safe.listDirs("rooms/$_room/content", options);
  }

  _read() async {
    var headers = await _libraryList(_dir);
    var dirs = await _libraryDirs(_dir);
    var files = SplayTreeMap<String, List<Header>>();
    for (var header in headers) {
      var versions = files.putIfAbsent(basename(header.name), () => []);
      versions.add(header);
    }

    var d = Directory(path.join(documentsFolder, _safe.name, _room, _dir));
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    for (var f in d.listSync()) {
      if (f is File) {
        var name = f.path.split("/").last;
        if (!files.containsKey(name)) {
          files[name] = [];
        }
      }
      if (f is Directory) {
        var name = f.path.split("/").last;
        if (name != ".gallery" && name != ".previous" && !dirs.contains(name)) {
          dirs.add(name);
        }
      }
    }

    setState(() {
      _files = files;
      _dirs = dirs;
    });
  }

  SplayTreeMap<String, List<Header>> _files =
      SplayTreeMap<String, List<Header>>();
  List<String> _dirs = [];

  @override
  Widget build(BuildContext context) {
    var items = _dirs.map(
      (e) {
        var isFeed = e.endsWith(".feed");
        var title = isFeed ? e.substring(0, e.length - 5) : e;
        var icon =
            isFeed ? const Icon(Icons.rss_feed) : const Icon(Icons.folder);
        return Card(
          child: ListTile(
              title: Text(title),
              leading: icon,
              onTap: () async {
                if (isFeed) {
                  Navigator.pushNamed(context, "/content/feed", arguments: {
                    'safe': _safe,
                    'room': _room,
                    'folder': _dir.isEmpty ? e : "$_dir/$e"
                  });
                } else {
                  await _safe.syncBucket("rooms/$_room/content", SyncOptions());

                  _dir = _dir.isEmpty ? e : "$_dir/$e";
                  _read();
                }
              }),
        );
      },
    ).toList();

    for (var entry in _files.entries) {
      var name = entry.key;
      var headers = entry.value;
      var state = _getState(name, headers);
      var uploading = state == "uploading";
      items.add(Card(
        child: ListTile(
          title: Text(name.split("/").last,
              style: TextStyle(color: _colorForState(state))),
          subtitle: Text(state),
          leading: FileIcon(name),
          trailing: uploading
              ? const CircularProgressIndicator()
              : const Icon(Icons.chevron_right),
          onTap: !uploading
              ? () async {
                  await Navigator.pushNamed(context, "/content/actions",
                      arguments: {
                        "safe": _safe,
                        "name": name,
                        "room": _room,
                        "folder": _dir,
                        "headers": headers
                      });
                  _read();
                }
              : null,
        ),
      ));
    }

    var toolbar = Row(
      children: [
        if (_dir.isNotEmpty)
          PlatformIconButton(
            onPressed: () {
              _dir = _dir
                  .split("/")
                  .sublist(0, _dir.split("/").length - 1)
                  .join("/");
              _read();
            },
            icon: const Icon(Icons.arrow_upward),
          ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () =>
              fa.openFile(context, "$documentsFolder/$_safe/$_room/$_dir"),
          child: Text(
            _dir.split("/").last,
            style: const TextStyle(
              fontSize: 18,
              decoration: TextDecoration.underline,
              color: Colors.blue,
            ),
          ),
        ),
        const Spacer(),
        PlatformIconButton(onPressed: _read, icon: const Icon(Icons.refresh)),
        const SizedBox(width: 10),
        PlatformIconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.pushNamed(context, "/content/add", arguments: {
              'safe': _safe,
              'room': _room,
              'folder': _dir,
            });
            _read();
          },
        ),
      ],
    );

    var files = DropTarget(
      onDragDone: (details) async {
        for (var file in details.files) {
          var selection = fa.FileSelection(file.name, file.path, false);
          await Navigator.pushNamed(context, "/upload", arguments: {
            'safe': _safe,
            'room': _room,
            'zoneName': "widget.zoneName",
            'selection': selection,
          });
          _read();
        }
      },
      child: Expanded(
        child: RefreshIndicator(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            children: items,
          ),
          onRefresh: () async {
            await _safe.syncBucket("rooms/$_room/content", SyncOptions());
            _read();
          },
        ),
      ),
    );

    return SafeArea(
        child: Column(children: [
      const SizedBox(height: 10),
      toolbar,
      const SizedBox(height: 10),
      files,
    ]));
  }
}
