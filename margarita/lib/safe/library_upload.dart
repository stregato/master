import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:margarita/common/file_access.dart';
import 'package:margarita/common/io.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:path/path.dart';

class LibraryUploadArgs {
  String safeName;
  String zoneName;
  FileSelection selection;

  LibraryUploadArgs(this.safeName, this.zoneName, this.selection);
}

class LibraryUpload extends StatefulWidget {
  const LibraryUpload({super.key});

  @override
  State<LibraryUpload> createState() => _LibraryUploadState();
}

class _LibraryUploadState extends State<LibraryUpload> {
  final _formKey = GlobalKey<FormState>();
  String _targetName = "";
  late String _safeName;
  late String _folder;
  late FileSelection _selection;
  bool _copyLocally = false;
  bool _uploading = false;

  static Future<String> _uploadFile(String safeName, String name,
      FileSelection selection, PutOptions options) {
    return Isolate.run<String>(() {
      try {
        putFile(safeName, name, selection.path, options);
        return "";
      } catch (e) {
        return e.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    _selection = args["selection"] as FileSelection;
    _safeName = args["safeName"] as String;
    _folder = args["folder"] as String;
    _targetName = _selection.name;

    var action = _uploading
        ? const CircularProgressIndicator()
        : ElevatedButton(
            onPressed: () {
              try {
                setState(() {
                  _uploading = true;
                });
                var options = PutOptions();
                if (_copyLocally) {
                  var localPath =
                      join(documentsFolder, _safeName, _folder, _targetName);
                  File(_selection.path).copySync(localPath);
                  options.source = localPath;
                }
                _uploadFile(_safeName, "library/$_folder/$_targetName",
                        _selection, options)
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
