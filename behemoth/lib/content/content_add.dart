import 'dart:io';

import 'package:behemoth/common/io.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path/path.dart' as path;
import 'package:behemoth/common/file_access.dart' as fa;

class ContentAdd extends StatefulWidget {
  const ContentAdd({super.key}); // Constructor to receive the callback

  @override
  State<ContentAdd> createState() => _ContentStateAdd();
}

class _ContentStateAdd extends State<ContentAdd> {
  late Safe _safe;
  late String _folder;

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _safe = args["safe"] as Safe;
    _folder = args["folder"] as String;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Add to ${_safe.prettyName}"),
      ),
      body: ListView(
        children: <Widget>[
          _CustomCard(
            title: "Folder",
            icon: Icons.folder,
            onTap: () async {
              await _newFolderDialog(context, "Folder Name", "");
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          _CustomCard(
            title: "File",
            icon: Icons.insert_drive_file,
            onTap: () async {
              var selection = await fa.getFile(context);
              if (selection.valid && mounted) {
                await Navigator.pushNamed(context, "/content/upload",
                    arguments: {
                      'safe': _safe,
                      'selection': selection,
                      'folder': _folder,
                    });
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
          _CustomCard(
            title: "Markdown",
            icon: Icons.text_fields,
            onTap: () async {
              await _newTextDialog(context);
            },
          ),
          _CustomCard(
            title: "Feed",
            icon: Icons.rss_feed,
            onTap: () async {
              await _newFolderDialog(context, "New Feed", ".feed");
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _newFolderDialog(
      BuildContext context, String msg, String suffix) async {
    var textController = TextEditingController();

    return showPlatformDialog(
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
                var d = path.join(documentsFolder, _safe.name, _folder,
                    "${textController.text}$suffix");
                Directory(d).createSync(recursive: true);
                Navigator.of(context).pop(); // Close the dialog
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
                var d = path.join(documentsFolder, _safe.name, _folder,
                    "${textController.text}.md");
                await Navigator.pushNamed(context, "/content/editor",
                    arguments: {"filename": d});
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
  final IconData icon;
  final VoidCallback onTap;

  const _CustomCard(
      {required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
