// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/content/content_snippet.dart';
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
  const Content(this.coven, this.room, {super.key});

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
  String _bucket = "";
  Map<String, int> _layout = {};

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _safe = widget.coven.safe;
    _bucket = "rooms/$_room/content";
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      _read();
    });
    Future.delayed(Duration.zero, () async {
      _read();
    });
    _read();
    _readLayout();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getState(String name, List<Header> headers) {
    var localFile = path.join(documentsFolder, _safe.name, _room, name);
    var localStat = File(localFile).statSync();
    var localExists = File(localFile).existsSync();

    if (headers.isEmpty) {
      return "unstaged";
    }

    headers.sort((a, b) => b.modTime.compareTo(a.modTime));
    var idx = headers.indexWhere((h) => h.downloads[localFile] != null);
    if (idx < 0) {
      if (localExists) {
        return "conflict";
      }
      return headers[0].uploading ? "uploading" : "new";
    }
    if (!localExists) {
      return "deleted";
    }

    var downloadTime = headers[idx].downloads[localFile]!;
    var uploading = headers[idx].uploading;
    var modified = localStat.modified.difference(downloadTime).inSeconds > 2;
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
    return _safe.listFiles(_bucket, options);
  }

  Future<List<String>> _libraryDirs(String folder) async {
    var options = ListDirsOptions(dir: folder);
    return _safe.listDirs(_bucket, options);
  }

  _readLayout() async {
    try {
      var name = join(_dir, ".layout.json");
      var data = await _safe.getBytes(_bucket, name, GetOptions());
      var json = String.fromCharCodes(data);
      var layout = jsonDecode(json);
      _layout = Map<String, int>.from(layout);
      setState(() {});
    } catch (e) {
      // ignore
    }
  }

  _read() async {
    var headers = await _libraryList(_dir);
    var dirs = await _libraryDirs(_dir);
    var files = SplayTreeMap<String, List<Header>>();
    for (var header in headers) {
      if (header.name == ".layout.json") continue;
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

  _refresh() {
    _read();
    _readLayout();
  }

  SplayTreeMap<String, List<Header>> _files =
      SplayTreeMap<String, List<Header>>();
  List<String> _dirs = [];

  @override
  Widget build(BuildContext context) {
    var swaps = <int, int>{};
    var headersMap = <int, String>{};

    var items = <Widget>[];

    for (var name in _dirs) {
      var isFeed = name.endsWith(".feed");
      var isTaskList = name.endsWith(".tasks");
      var title = isFeed || isTaskList ? basenameWithoutExtension(name) : name;
      var icon = isFeed
          ? const Icon(Icons.rss_feed)
          : isTaskList
              ? const Icon(Icons.task_alt)
              : const Icon(Icons.folder);

      var pos = _layout[name];
      if (pos != null) {
        swaps[items.length] = pos;
      }
      headersMap[items.length] = name;

      items.add(Card(
        key: ValueKey(name),
        child: ListTile(
            title: Text(title),
            leading: icon,
            onTap: () async {
              if (isFeed) {
                Navigator.pushNamed(context, "/content/feed", arguments: {
                  'safe': _safe,
                  'room': _room,
                  'folder': _dir.isEmpty ? name : "$_dir/$name"
                });
              } else if (isTaskList) {
                Navigator.pushNamed(context, "/content/tasklist", arguments: {
                  'safe': _safe,
                  'room': _room,
                  'folder': _dir.isEmpty ? name : "$_dir/$name"
                });
              } else {
                _dir = _dir.isEmpty ? name : "$_dir/$name";
                _read();
              }
            }),
      ));
    }
    for (var entry in _files.entries) {
      var name = entry.key;
      var headers = entry.value;
      var state = _getState(name, headers);
      var uploading = state == "uploading";
      var isSnippet = name.endsWith(".snippet");

      var pos = _layout[name];
      if (pos != null) {
        swaps[items.length] = pos;
      }
      headersMap[items.length] = name;

      if (isSnippet) {
        items.add(Card(
            key: ValueKey(name),
            child: ContentSnippet(_safe, "rooms/$_room/content", name)));
        continue;
      }

      items.add(Card(
        key: ValueKey(name),
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

    for (var entry in swaps.entries) {
      var from = entry.key;
      var to = entry.value;
      var item = items.removeAt(from);
      items.insert(to, item);
      headersMap[to] = headersMap.remove(from)!;
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
        PlatformIconButton(
            onPressed: _refresh, icon: const Icon(Icons.refresh)),
        const SizedBox(width: 10),
        PlatformIconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            var h =
                await Navigator.pushNamed(context, "/content/add", arguments: {
              'safe': _safe,
              'room': _room,
              'folder': _dir,
            });
            if (h is Header) {
              _files[h.name] = [h];
            } else if (h is String) {
              _dirs.add(h);
            }
            _read();

            Future.delayed(Duration.zero, _read);
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
          child: items.isNotEmpty
              ? ReorderableListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  children: items,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      var name = headersMap[oldIndex];
                      if (name == null) {
                        return;
                      }
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      _layout[name] = newIndex;
                      var layoutName = join(_dir, ".layout.json");
                      var data = utf8.encode(jsonEncode(_layout));
                      _safe.putBytes(
                          _bucket, layoutName, data, PutOptions(async: true));
                    });
                  },
                )
              : const Center(
                  child: Text("Nothing here yet"),
                ),
          onRefresh: () async {
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
