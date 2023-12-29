import 'dart:io';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:intl/intl.dart';
import 'package:behemoth/common/file_access.dart' as fa;
import 'package:behemoth/common/io.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/theme.dart';
import 'package:mime/mime.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:path/path.dart' as path;

class ContentActions extends StatefulWidget {
  const ContentActions({super.key});

  @override
  State<ContentActions> createState() => _ContentActionsState();
}

class _ContentActionsState extends State<ContentActions> {
  AppTheme theme = LightTheme();
  late Safe _safe;
  late String _room;
  late String _name;
  late String _folder;
  late List<Header> _headers;

  int _deleteCount = 3;
  int _downloading = 0;
  @override
  void initState() {
    super.initState();
  }

  String getNick(String id) {
    var identity = getCachedIdentity(id);
    return identity.nick.isNotEmpty ? identity.nick : "unknown";
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _safe = args["safe"] as Safe;
    _room = args["room"] as String;
    _name = args["name"] as String;
    _folder = args["folder"] as String;
    _headers = args["headers"] as List<Header>;
    _headers.sort((a, b) => b.modTime.compareTo(a.modTime));

    var libraryFolder = path.join(documentsFolder, _safe.name, _room);
    var localPath =
        path.join(documentsFolder, _safe.name, _room, _folder, _name);
    var prevPath = path.join(
        documentsFolder, _safe.name, _room, _folder, ".previous", _name);
    var items = <Card>[];
    var syncFileId = 0;

    var localExists = File(localPath).existsSync();
    var localModtime = localExists ? File(localPath).statSync().modified : null;
    _headers.sort((a, b) => b.modTime.compareTo(a.modTime));

    if (localExists) {
      for (var h in _headers) {
        var downloadTime = h.downloads[localPath];
        if (localModtime != null &&
            downloadTime != null &&
            localModtime.difference(downloadTime).inSeconds < 2) {
          syncFileId = h.fileId;
        }
      }
      var mime = lookupMimeType(localPath);
      if (mime == "text/markdown" || localPath.endsWith(".md")) {
        items.add(
          Card(
            child: ListTile(
              title: Text("Edit ${path.basename(localPath)}"),
              leading: const Icon(Icons.edit),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  "/content/editor",
                  arguments: {
                    'filename': localPath,
                  },
                );
              },
            ),
          ),
        );
      }
      items.add(
        Card(
          child: ListTile(
            title: Text("Open ${path.basename(localPath)}"),
            leading: const Icon(Icons.file_open),
            onTap: () => fa.openFile(context, localPath),
          ),
        ),
      );
      items.add(
        Card(
          child: ListTile(
              title: Text(
                  "Delete ${path.basename(localPath)} ($_deleteCount clicks)"),
              leading: const Icon(Icons.delete),
              onTap: () {
                if (_deleteCount > 1) {
                  setState(() {
                    _deleteCount--;
                  });
                } else {
                  File(localPath).deleteSync();
                  showPlatformSnackbar(
                      context, "${path.basename(localPath)} deleted",
                      backgroundColor: Colors.green);
                  Navigator.pop(context);
                }
              }),
        ),
      );
      if (_headers.isEmpty || syncFileId == 0) {
        var action = _headers.isEmpty ? "Add" : "Upload";
        items.add(
          Card(
            child: ListTile(
              title: Text("$action to $_room@${_safe.name}"),
              leading: Icon(_headers.isEmpty ? Icons.add : Icons.file_upload),
              onTap: () async {
                try {
                  var options = PutOptions();
                  options.source = localPath;
                  var dest = _folder.isEmpty ? _name : "$_folder/$_name";
                  await _safe.putFile(
                      "rooms/$_room/content", dest, localPath, options);
                  if (mounted) {
                    showPlatformSnackbar(
                        context, "$_name uploaded to $_room@${_safe.name}",
                        backgroundColor: Colors.green);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    showPlatformSnackbar(context, "Cannot $action $_name: $e",
                        backgroundColor: Colors.red);
                  }
                }
              },
            ),
          ),
        );
      }
      var dir = File(localPath).parent.path;
      items.add(
        Card(
          child: ListTile(
            title: const Text("Open parent directory"),
            leading: const Icon(Icons.folder_open),
            onTap: () => fa.openFile(context, dir),
          ),
        ),
      );
    }

    if (File(prevPath).existsSync()) {
      items.add(
        Card(
          child: ListTile(
            title: Text("Open previous version of ${path.basename(localPath)}"),
            leading: const Icon(Icons.file_open),
            onTap: () => fa.openFile(context, prevPath),
          ),
        ),
      );
    }

    var version = _headers.length;
    for (var h in _headers) {
      var action = "";
      // local is sync and version is last
      if (h.fileId == syncFileId && version == _headers.length) {
        continue;
      }
      // local is sync but not last version: update
      else if (h.fileId == syncFileId && version != _headers.length) {
        action = "Update to";
      }
      // local is not sync, so any download will be replace
      else if (!localExists) {
        action = "Download";
      } else if (syncFileId == 0) {
        action = "Replace with";
      } else {
        action = "Update to";
      }
      items.add(
        Card(
          child: ListTile(
            title: Text(
                "$action v$version from ${getNick(h.creator)}\n${DateFormat('dd/MM HH:mm').format(h.modTime)}"),
            leading: _downloading == h.fileId
                ? const CircularProgressIndicator()
                : const Icon(Icons.file_download),
            onTap: () async {
              try {
                if (localExists) {
                  Directory prevDir = Directory(path.join(documentsFolder,
                      _safe.name, _room, _folder, ".previous"));
                  if (!prevDir.existsSync()) {
                    prevDir.createSync(recursive: true);
                  }
                  File(localPath).copySync(prevPath);
                }
                var options = GetOptions();
                var name = path.basename(h.name);
                options.destination = "$libraryFolder/$name";
                options.fileId = h.fileId;
                setState(() {
                  _downloading = h.fileId;
                });
                await _safe.getFile("rooms/$_room/content", h.name,
                    options.destination, options);
                if (!mounted) return;
                showPlatformSnackbar(
                    context, "${h.name} downloaded to $libraryFolder",
                    backgroundColor: Colors.green);
                setState(() {
                  _downloading = 0;
                });
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                showPlatformSnackbar(context, "Cannot download ${h.name}: $e",
                    backgroundColor: Colors.red);
              }
            },
          ),
        ),
      );
      version--;
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_name, style: const TextStyle(fontSize: 18)),
        trailingActions: [
          PlatformIconButton(
            icon: const Icon(Icons.file_open),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal");
            },
          ),
          PlatformIconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal");
            },
          ),
          PlatformIconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal");
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(children: [
            ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: items,
            ),
          ]),
        ),
      ),
//      bottomNavigationBar: MainNavigationBar(poolName),
    );
  }
}
