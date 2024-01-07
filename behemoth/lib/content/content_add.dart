import 'dart:convert';
import 'dart:io';

import 'package:behemoth/common/io.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path/path.dart' as path;
import 'package:behemoth/common/file_access.dart' as fa;
import 'package:snowflake_dart/snowflake_dart.dart';

class ContentAdd extends StatefulWidget {
  const ContentAdd({super.key}); // Constructor to receive the callback

  @override
  State<ContentAdd> createState() => _ContentStateAdd();
}

class _ContentStateAdd extends State<ContentAdd> {
  late Safe _safe;
  late String _room;
  late String _folder;

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _safe = args["safe"] as Safe;
    _room = args["room"] as String;
    _folder = args["folder"] as String;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Add to  $_room@${_safe.name}"),
      ),
      body: ListView(
        children: <Widget>[
          _CustomCard(
            title: "Folder",
            icon: const Icon(Icons.folder),
            onTap: () async {
              await _newFolderDialog(context, "Folder Name", "");
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          _CustomCard(
            title: "File",
            icon: const Icon(Icons.insert_drive_file),
            onTap: () async {
              var selection = await fa.getFile(context);
              if (selection.valid && mounted) {
                var h = await Navigator.pushNamed(context, "/content/upload",
                    arguments: {
                      'safe': _safe,
                      'selection': selection,
                      'folder': _folder,
                      'room': _room,
                    });
                if (mounted) {
                  Navigator.pop(context, h);
                }
              }
            },
          ),
          _CustomCard(
            title: "Markdown",
            icon: const Icon(Icons.text_fields),
            onTap: () async {
              await _newTextDialog(context);
            },
          ),
          _CustomCard(
            title: "Snippet",
            icon: const Icon(Icons.text_snippet),
            onTap: () async {
              var content = await Navigator.pushNamed(
                context,
                "/content/editor",
                arguments: {
                  'title': "Snippet",
                  'content': "Edit the snippet here",
                  'tabs': ['edit', 'preview'],
                },
              );
              Header? h;
              if (content != null && content is String) {
                var name = ".${Snowflake(nodeId: 0).generate()}.snippet";
                var data = utf8.encode(content);
                h = await _safe.putBytes(
                    "rooms/$_room/content", name, data, PutOptions());
              }
              if (mounted) {
                Navigator.pop(context, h);
              }
            },
          ),
          _CustomCard(
            title: "Feed",
            icon: const Icon(Icons.rss_feed),
            onTap: () async {
              await _newFolderDialog(context, "New Feed", ".feed");
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          _CustomCard(
            title: "Task List",
            icon: const Icon(Icons.task_alt),
            onTap: () async {
              var name =
                  await _newFolderDialog(context, "New Task List", ".tasks");
              if (mounted) {
                Navigator.pop(context, name);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _newFolderDialog(
      BuildContext context, String msg, String suffix) async {
    var textController = TextEditingController();

    return showPlatformDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(msg),
          content: PlatformTextField(
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
                var name = "${textController.text}$suffix";
                var d = path.join(
                    documentsFolder, _safe.name, _room, _folder, name);
                Directory(d).createSync(recursive: true);
                Navigator.of(context).pop(name); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _newTextDialog(BuildContext context) async {
    var textController = TextEditingController();

    return showPlatformDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Name of the file:"),
          content: PlatformTextField(
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
              onPressed: () async {
                var name = "${textController.text}.md";
                var d = path.join(
                    documentsFolder, _safe.name, _room, _folder, name);
                var content = await Navigator.pushNamed(
                    context, "/content/editor",
                    arguments: {
                      'title': name,
                      'content': "_Edit the markdown here_",
                      'tabs': ['edit', 'preview'],
                    });
                if (content != null && content is String) {
                  File(d).writeAsStringSync(content);
                }
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _CustomCard extends StatelessWidget {
  final String title;
  final Icon icon;
  final VoidCallback onTap;

  const _CustomCard(
      {required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: icon,
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
