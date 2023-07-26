import 'dart:io';

import 'package:margarita/common/document.dart';
//import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as pl;

class ChooseFile extends StatefulWidget {
  final Document document;
  final String? message;
  final bool canChoose;

  const ChooseFile(this.document, this.message, this.canChoose, {super.key});

  @override
  State<ChooseFile> createState() => _ChooseFileState();
}

class _ChooseFileState extends State<ChooseFile> {
  final _formKey = GlobalKey<FormState>();
  String _target = "";

  Directory? _createFolder(Directory folder) {
    if (folder.existsSync()) {
      return null;
    } else {
      var parent = _createFolder(folder.parent);
      folder.createSync();
      return parent ?? folder;
    }
  }

  void _cleanUp(Directory parent, Directory created) {
    if (parent.listSync().isEmpty) {
      parent.delete();
      if (parent != created) {
        _cleanUp(parent.parent, created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_target.isEmpty) {
      _target = widget.document.path;
    }
    var saveTo = TextEditingController(text: _target);
    var name = pl.basename(widget.document.path);
    var parent = File(widget.document.path).parent;
    Directory? created;
    if (widget.canChoose) created = _createFolder(parent);

    var targetSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.message != null)
          Text(
            widget.message!,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        Row(
          children: [
            Flexible(
                child: TextFormField(
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Save to'),
              controller: saveTo,
            )),
            if (widget.canChoose)
              const SizedBox(
                width: 16,
              ),
            if (widget.canChoose)
              ElevatedButton(
                onPressed: () {
                  // getSavePath(
                  //         initialDirectory: parent.path, suggestedName: _target)
                  //     .then((value) {
                  //   if (value != null) {
                  //     setState(() {
                  //       _target = value;
                  //       saveTo.text = value;
                  //     });
                  //   }
                  // }).catchError((e) {
                  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  //       backgroundColor: Colors.red,
                  //       content: Text(
                  //         "Cannot set target: $e",
                  //       )));
                  // });
                },
                child: const Text("Choose"),
              ),
          ],
        ),
        const SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () {
            if (created != null) _cleanUp(parent, created);
            Navigator.pop(context, _target);
          },
          child: const Text('Save'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Download $name"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Builder(
          builder: (context) => Form(
            key: _formKey,
            child: targetSection,
          ),
        ),
      ),
    );
  }
}
