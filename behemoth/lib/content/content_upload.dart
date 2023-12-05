import 'dart:async';
import 'dart:io';

import 'package:behemoth/common/file_access.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path/path.dart';

class ContentUpload extends StatefulWidget {
  const ContentUpload({super.key});

  @override
  State<ContentUpload> createState() => _ContentUploadState();
}

class _ContentUploadState extends State<ContentUpload> {
  final _formKey = GlobalKey<FormState>();
  String _targetName = "";
  late Safe _safe;
  late String _room;
  late String _folder;
  late FileSelection _selection;
  bool _copyLocally = false;

  Future<Header> _uploadFile(
      String name, FileSelection selection, PutOptions options) async {
    return await _safe.putFile(
        "rooms/$_room/content", name, selection.path, options);
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    _selection = args["selection"] as FileSelection;
    _safe = args["safe"] as Safe;
    _room = args["room"] as String;
    _folder = args["folder"] as String;
    _targetName = _selection.name;

    var action = PlatformElevatedButton(
      onPressed: () async {
        try {
          var options = PutOptions(async: true);
          if (_copyLocally) {
            var localPath =
                join(documentsFolder, _safe.name, _room, _folder, _targetName);
            File(_selection.path).copySync(localPath);
            options.source = localPath;
          }
          _uploadFile(join(_folder, _targetName), _selection, options);
          if (!mounted) return;

          showPlatformSnackbar(
              context, "File $_targetName is uploading in background",
              backgroundColor: Colors.green);
          Navigator.pop(context);
        } catch (e) {
          showPlatformSnackbar(context, "Cannot upload $_targetName: $e",
              backgroundColor: Colors.green);
        }
      },
      child: const Text('Upload'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Add ${_selection.name}"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Builder(
          builder: (context) => Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  initialValue: _targetName,
                  onChanged: (val) => setState(() {
                    _targetName = val;
                  }),
                ),
                Row(children: [
                  Checkbox(
                      value: _copyLocally,
                      activeColor: Colors.green,
                      onChanged: (v) {
                        setState(() {
                          _copyLocally = v ?? false;
                        });
                      }),
                  const Text('Save locally'),
                ]),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
