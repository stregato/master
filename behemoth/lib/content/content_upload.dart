import 'dart:async';
import 'dart:io';

import 'package:behemoth/common/file_access.dart';
import 'package:behemoth/common/io.dart';
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
  late String _folder;
  late FileSelection _selection;
  bool _copyLocally = false;
  bool _uploading = false;

  Future<String> _uploadFile(
      String name, FileSelection selection, PutOptions options) async {
    try {
      await _safe.putFile(name, selection.path, options);
      return "";
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    _selection = args["selection"] as FileSelection;
    _safe = args["safe"] as Safe;
    _folder = args["folder"] as String;
    _targetName = _selection.name;

    var action = _uploading
        ? const CircularProgressIndicator()
        : PlatformElevatedButton(
            onPressed: () {
              try {
                setState(() {
                  _uploading = true;
                });
                var options = PutOptions();
                if (_copyLocally) {
                  var localPath =
                      join(documentsFolder, _safe.name, _folder, _targetName);
                  File(_selection.path).copySync(localPath);
                  options.source = localPath;
                }
                _uploadFile(
                        "content/$_folder/$_targetName", _selection, options)
                    .then((value) {
                  setState(() {
                    _uploading = false;
                  });
                  Navigator.pop(context);
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(
                      "Cannot upload $_targetName: $e",
                    )));
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
