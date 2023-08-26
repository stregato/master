import 'dart:isolate';

import 'package:margarita/common/progress.dart';
import 'package:margarita/safe/library_actions.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/theme.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:margarita/common/file_access.dart';
import 'package:file_icon/file_icon.dart';
import 'dart:collection';

class Library extends StatefulWidget {
  final String portalName;
  final String zoneName;
  const Library(this.portalName, this.zoneName, {Key? key}) : super(key: key);

  @override
  State<Library> createState() => _LibraryState();
}

class UploadArgs {
  String poolName;
  FileSelection selection;
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

  String _getState(List<Header> headers) {
    headers.sort((a, b) => b.modTime.compareTo(a.modTime));
    var idx = headers.indexWhere((h) => h.downloads.isNotEmpty);

    if (idx < 0) {
      return "new";
    }
    var local = headers[idx];
    var modified =
        local.downloads.values.any((modTime) => modTime.isAfter(local.modTime));
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
    options.folder = folder;
    return Isolate.run<List<Header>>(
        () => listFiles(widget.portalName, widget.zoneName, options));
  }

  bool _reload = true;
  List<Header> _list = [];

  @override
  Widget build(BuildContext context) {
    if (_reload) {
      _reload = false;
      Future.delayed(const Duration(milliseconds: 10), () async {
        var list = await progressDialog<List<Header>>(
            context, "loading...", _libraryList(widget, _folder));
        if (list != null) {
          setState(() {
            _list = list;
          });
        }
      });
    }

    var items = listSubFolders(widget.portalName, widget.zoneName, _folder)
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

    var options = ListOptions();
    options.folder = _folder;
    var files = SplayTreeMap<String, List<Header>>();
    var headers = listFiles(widget.portalName, widget.zoneName, options);

    for (var header in headers) {
      var versions = files.putIfAbsent(header.name, () => []);
      versions.add(header);
    }

    for (var entry in files.entries) {
      var name = entry.key;
      var headers = entry.value;
      var state = _getState(headers);
      items.add(Card(
        child: ListTile(
          title: Text(name.split("/").last,
              style: TextStyle(color: _colorForState(state))),
          subtitle: Text(state),
          leading: FileIcon(name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pushNamed(context, "/library/actions",
                    arguments: LibraryActionsArgs(
                        widget.portalName, widget.zoneName, headers))
                .then((value) => setState(
                      () {},
                    ));
          },
        ),
      ));
    }

    var breadcrumbsItems = <BreadCrumbItem>[
      BreadCrumbItem(
        content: RichText(
          text: TextSpan(
            text: widget.zoneName,
            style: const TextStyle(color: Colors.blue),
            recognizer: TapGestureRecognizer()
              ..onTap = () => setState(
                    () {
                      _folder = "";
                      _reload = true;
                    },
                  ),
          ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Library"),
        actions: [
          ElevatedButton.icon(
            label: const Text("Reload"),
            onPressed: () {
              setState(() {
                _reload = true;
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(children: [
          Row(
            children: [
              BreadCrumb(
                items: breadcrumbsItems,
                divider: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  getFile(context).then((selection) {
                    if (selection.valid) {
                      Navigator.pushNamed(context, "/upload", arguments: {
                        'portalName': widget.portalName,
                        'zoneName': widget.zoneName,
                        'selection': selection,
                      }).then((value) => setState(
                            () {},
                          ));
                    }
                  });
                },
                icon: const Icon(Icons.upload_file),
              ),
            ],
          ),
          DropTarget(
            onDragDone: (details) {
              for (var file in details.files) {
                var selection = FileSelection(file.name, file.path, false);
                Navigator.pushNamed(context, "/upload", arguments: {
                  'portalName': widget.portalName,
                  'zoneName': widget.zoneName,
                  'selection': selection,
                }).then((value) => setState(
                      () {},
                    ));
              }
            },
            child: Expanded(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                children: items,
              ),
            ),
          ),
        ]),
      ),
//      bottomNavigationBar: MainNavigationBar(_poolName),
    );
  }
}
