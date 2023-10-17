import 'dart:io';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:intl/intl.dart';
import 'package:behemoth/common/file_access.dart' as fa;
import 'package:behemoth/common/io.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/theme.dart';
import 'package:mime/mime.dart';

import 'package:path/path.dart' as path;

class ContentActions extends StatefulWidget {
  const ContentActions({Key? key}) : super(key: key);

  @override
  State<ContentActions> createState() => _ContentActionsState();
}

class _ContentActionsState extends State<ContentActions> {
  AppTheme theme = LightTheme();
  late Safe _safe;
  late String _name;
  late String _folder;
  late List<Header> _headers;
  late List<Identity> _identities;
  int _deleteCount = 3;
  @override
  void initState() {
    super.initState();
  }

  String getNick(String id) {
    var identity =
        _identities.firstWhere((i) => i.id == id, orElse: () => Identity());
    return identity.nick.isNotEmpty ? identity.nick : id.substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _safe = args["safe"] as Safe;
    _name = args["name"] as String;
    _folder = args["folder"] as String;
    _headers = args["headers"] as List<Header>;
    _headers.sort((a, b) => b.modTime.compareTo(a.modTime));
    _identities =
        _safe.getUsersSync().keys.map((e) => getCachedIdentity(e)).toList();

    var libraryFolder = path.join(documentsFolder, _safe.name);
    var localPath = path.join(documentsFolder, _safe.name, _folder, _name);
    var prevPath =
        path.join(documentsFolder, _safe.name, _folder, ".previous", _name);
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
            localModtime.difference(downloadTime).inMinutes < 1) {
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("${path.basename(localPath)} deleted")),
                  );
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
              title: Text("$action to ${_safe.prettyName}"),
              leading: Icon(_headers.isEmpty ? Icons.add : Icons.file_upload),
              onTap: () async {
                try {
                  var options = PutOptions();
                  options.source = localPath;
                  var dest = _folder.isEmpty
                      ? "content/$_name"
                      : "content/$_folder/$_name";
                  await _safe.putFile(dest, localPath, options);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: Colors.green,
                        content: Text(
                          "$_name uploaded to $_safe",
                        )));
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: Colors.red,
                        content: Text(
                          "Cannot $action $_name: $e",
                        )));
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
            leading: const Icon(Icons.file_download),
            onTap: () async {
              try {
                if (localExists) {
                  Directory prevDir = Directory(path.join(
                      documentsFolder, _safe.name, _folder, ".previous"));
                  if (!prevDir.existsSync()) {
                    prevDir.createSync(recursive: true);
                  }
                  File(localPath).copySync(prevPath);
                }
                var options = GetOptions();
                var name = path.joinAll(path.split(h.name).skip(1));
                options.destination = "$libraryFolder/$name";
                options.fileId = h.fileId;
                await _safe.getFile(h.name, options.destination, options);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(
                        "${h.name} downloaded to $libraryFolder",
                      )));
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        "Cannot download ${h.name}: $e",
                      )));
                }
              }
            },
          ),
        ),
      );
      version--;
    }
    //     items.add(
    //       Card(
    //         child: ListTile(
    //           title: const Text("Share"),
    //           leading: const Icon(Icons.share),
    //           onTap: () {
    //             final box = context.findRenderObject() as RenderBox?;
    //             Share.shareXFiles([XFile(d.localPath)],
    //                 subject: "Can you add me to your pool?",
    //                 sharePositionOrigin:
    //                     box!.localToGlobal(Offset.zero) & box.size);
    //           },
    //         ),
    //       ),
    //     );
    //   }
    return Scaffold(
      appBar: AppBar(
        title: Text(_name, style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal");
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal");
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () {
              Navigator.pushNamed(context, "/addPortal");
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(children: [
          ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            children: items,
          ),
        ]),
      ),
//      bottomNavigationBar: MainNavigationBar(poolName),
    );
  }
}
