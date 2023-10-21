// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:behemoth/common/io.dart';
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
  final Safe safe;
  const Content(this.safe, {Key? key}) : super(key: key);

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

  String _folder = "";

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getState(String name, List<Header> headers) {
    var localFile = path.join(documentsFolder, widget.safe.name, name);
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
      return "new";
    }
    var downloadTime = headers[idx].downloads[localFile]!;
    var modified = localStat.modified.difference(downloadTime).inMinutes > 1;
    if (modified) {
      return idx == 0 ? "modified" : "conflict";
    } else {
      return idx == 0 ? "sync" : "updated";
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

  Future<List<Header>> _libraryList(String folder) async {
    var options = ListOptions();
    var dir = folder.isEmpty ? "content" : "content/$folder";
    return widget.safe.listFiles(dir, options);
  }

  Future<List<String>> _libraryDirs(String folder) async {
    var options = ListDirsOptions();
    var dir = folder.isEmpty ? "content" : "content/$folder";
    return widget.safe.listDirs(dir, options);
  }

  _read() async {
    var headers = await _libraryList(_folder);
    var dirs = await _libraryDirs(_folder);
    var files = SplayTreeMap<String, List<Header>>();
    for (var header in headers) {
      var versions = files.putIfAbsent(basename(header.name), () => []);
      versions.add(header);
    }

    var d = Directory(path.join(documentsFolder, widget.safe.name, _folder));
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
        if (name != ".previous" && !dirs.contains(name)) {
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
        var icon = isFeed ? Icons.rss_feed : Icons.folder;
        return Card(
          child: ListTile(
              title: Text(title),
              leading: Icon(icon),
              onTap: () {
                if (isFeed) {
                  Navigator.pushNamed(context, "/content/feed", arguments: {
                    'safe': widget.safe,
                    'folder': _folder.isEmpty ? e : "$_folder/$e"
                  });
                } else {
                  _folder = _folder.isEmpty ? e : "$_folder/$e";
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
      items.add(Card(
        child: ListTile(
          title: Text(name.split("/").last,
              style: TextStyle(color: _colorForState(state))),
          subtitle: Text(state),
          leading: FileIcon(name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.pushNamed(context, "/content/actions", arguments: {
              "safe": widget.safe,
              "name": name,
              "folder": _folder,
              "headers": headers
            });
            _read();
          },
        ),
      ));
    }

    var toolbar = Row(
      children: [
        if (_folder.isNotEmpty)
          PlatformIconButton(
            onPressed: () {
              _folder = _folder
                  .split("/")
                  .sublist(0, _folder.split("/").length - 1)
                  .join("/");
              _read();
            },
            icon: const Icon(Icons.arrow_upward),
          ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () =>
              fa.openFile(context, "$documentsFolder/${widget.safe}/$_folder"),
          child: Text(
            _folder.split("/").last,
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
            await Navigator.pushNamed(context, "/content/add",
                arguments: {'safe': widget.safe, 'folder': _folder});
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
            'safe': widget.safe,
            'zoneName': "widget.zoneName",
            'selection': selection,
          });
          _read();
        }
      },
      child: Expanded(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          children: items,
        ),
      ),
    );

    return PlatformScaffold(
      body: Column(children: [
        const SizedBox(height: 10),
        toolbar,
        const SizedBox(height: 10),
        files,
      ]),
    );
  }
}
