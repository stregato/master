// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:isolate';

import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/woland_def.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/apps/chat/theme.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:behemoth/common/file_access.dart' as fa;
import 'package:file_icon/file_icon.dart';
import 'dart:collection';
import 'package:path/path.dart' as path;

import 'package:path/path.dart';

class Library extends StatefulWidget {
  final String safeName;
  const Library(this.safeName, {Key? key}) : super(key: key);

  @override
  State<Library> createState() => _LibraryState();
}

class UploadArgs {
  String poolName;
  fa.FileSelection selection;
  UploadArgs(this.poolName, this.selection);
}

class _LibraryState extends State<Library> {
  AppTheme theme = LightTheme();

  String _folder = "";

  @override
  void dispose() {
    super.dispose();
    _reload = true;
  }

  String _getState(String name, List<Header> headers) {
    var localFile = path.join(documentsFolder, widget.safeName, name);
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

  static Future<List<Header>> _libraryList(
      Library widget, String folder) async {
    var options = ListOptions();
    var dir = folder.isEmpty ? "library" : "library/$folder";
    return Isolate.run<List<Header>>(
        () => listFiles(widget.safeName, dir, options));
  }

  static Future<List<String>> _libraryDirs(
      Library widget, String folder) async {
    var options = ListDirsOptions();
    var dir = folder.isEmpty ? "library" : "library/$folder";
    return Isolate.run<List<String>>(
        () => listDirs(widget.safeName, dir, options));
  }

  T _refresh<T>(T t) {
    setState(() {
      _reload = true;
    });
    return t;
  }

  Future<void> _newFolderDialog(BuildContext context) async {
    var textController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter folder name'),
          content: TextField(
            controller: textController,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                var d = path.join(documentsFolder, widget.safeName, _folder,
                    textController.text);
                Directory(d).createSync(recursive: true);
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  _refreshIfNeeded(BuildContext context) {
    if (_reload) {
      _reload = false;
      Future.delayed(const Duration(milliseconds: 10), () async {
        if (!mounted) {
          return;
        }
        var headers = await progressDialog<List<Header>>(
            context, "loading...", _libraryList(widget, _folder));
        var dirs = await progressDialog<List<String>>(
            context, "loading...", _libraryDirs(widget, _folder));

        var files = SplayTreeMap<String, List<Header>>();
        if (headers != null) {
          for (var header in headers) {
            var versions = files.putIfAbsent(basename(header.name), () => []);
            versions.add(header);
          }
        } else {
          headers = [];
        }

        dirs = dirs ?? [];
        var d = Directory(path.join(documentsFolder, widget.safeName, _folder));
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
          _dirs = dirs ?? [];
        });
      });
    }
  }

  bool _reload = true;
  SplayTreeMap<String, List<Header>> _files =
      SplayTreeMap<String, List<Header>>();
  List<String> _dirs = [];

  @override
  Widget build(BuildContext context) {
    _refreshIfNeeded(context);
    var items = _dirs
        .map(
          (e) => Card(
            child: ListTile(
              title: Text(e),
              leading: const Icon(Icons.folder),
              onTap: () => setState(() {
                _folder = _folder.isEmpty ? e : "$_folder/$e";
                _reload = true;
              }),
            ),
          ),
        )
        .toList();

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
          onTap: () {
            Navigator.pushNamed(context, "/library/actions", arguments: {
              "safeName": widget.safeName,
              "name": name,
              "folder": _folder,
              "headers": headers
            }).then(_refresh);
          },
        ),
      ));
    }

    var breadcrumbsItems = <BreadCrumbItem>[
      BreadCrumbItem(
        content: GestureDetector(
          onTap: () {
            setState(() {
              _folder = "";
              _reload = true;
            });
          },
          child: const Icon(Icons.home, color: Colors.blue),
        ),
      ),
    ];

    breadcrumbsItems.addAll(_folder.split("/").map(
          (e) => BreadCrumbItem(
            content: RichText(
              text: TextSpan(
                text: e,
                style: const TextStyle(color: Colors.blue),
                recognizer: TapGestureRecognizer()..onTap = () {},
              ),
            ),
          ),
        ));

    var toolbar = Row(
      children: [
        IconButton(
          onPressed: _folder.isNotEmpty
              ? () => setState(() {
                    _folder = _folder
                        .split("/")
                        .sublist(0, _folder.split("/").length - 1)
                        .join("/");
                    _reload = true;
                  })
              : null,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => fa.openFile(
              context, "$documentsFolder/${widget.safeName}/$_folder"),
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
        IconButton(
          icon: const Icon(Icons.create_new_folder),
          onPressed: () => _newFolderDialog(context).then((value) {
            setState(() {
              _reload = true;
            });
          }),
        ),
      ],
    );

    var upload = Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
            child: Container(
                margin: const EdgeInsets.only(
                  top: 12.0,
                  right: 12.0,
                  bottom: 12.0,
                  left: 12.0,
                ),
                child: const Row(children: [
                  Text("Upload File"),
                  Spacer(),
                  Icon(Icons.upload_file),
                ])),
            onPressed: () {
              fa.getFile(context).then((selection) {
                if (selection.valid) {
                  Navigator.pushNamed(context, "/library/upload", arguments: {
                    'safeName': widget.safeName,
                    'selection': selection,
                    'folder': _folder,
                  }).then(_refresh);
                }
              });
            }));

    var files = DropTarget(
      onDragDone: (details) {
        for (var file in details.files) {
          var selection = fa.FileSelection(file.name, file.path, false);
          Navigator.pushNamed(context, "/upload", arguments: {
            'safeName': widget.safeName,
            'zoneName': "widget.zoneName",
            'selection': selection,
          }).then(_refresh);
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

    return Scaffold(
      body: Column(children: [
        // Row(
        //   children: [
        //     BreadCrumb(
        //       items: breadcrumbsItems,
        //       divider: const Icon(Icons.chevron_right),
        //     ),
        //     const Spacer(),
        //   ],
        // ),
        const SizedBox(height: 10),
        toolbar,
        const SizedBox(height: 10),
        files,
        upload,
      ]),
    );
  }
}
