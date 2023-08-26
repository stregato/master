import 'package:margarita/common/file_access.dart';
import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:margarita/woland/woland_def.dart';

class LibraryUploadArgs {
  String portalName;
  String zoneName;
  FileSelection selection;

  LibraryUploadArgs(this.portalName, this.zoneName, this.selection);
}

class LibraryUpload extends StatefulWidget {
  const LibraryUpload({super.key});

  @override
  State<LibraryUpload> createState() => _LibraryUploadState();
}

class _LibraryUploadState extends State<LibraryUpload> {
  final _formKey = GlobalKey<FormState>();
  late LibraryUploadArgs _args;
  String _targetFolder = "";
  String _targetName = "";
  bool _copyLocally = false;
  bool _uploading = false;
  final Map<String, List<String>> _virtualFolders = {};
  final TextEditingController _createFolderController = TextEditingController();

  Future<String?> _createFolderDialog(BuildContext context) async {
    return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create Folder'),
            content: TextField(
              controller: _createFolderController,
              decoration: const InputDecoration(hintText: "Name"),
            ),
            actions: [
              ElevatedButton(
                child: const Text('Confirm'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  Widget _getFolderSelection(BuildContext context) {
    var crumbs = <BreadCrumbItem>[
      BreadCrumbItem(
        content: Text(_args.portalName),
        onTap: () {
          setState(() {
            _targetFolder = "";
          });
        },
      ),
    ];
    var s = "";
    _targetFolder.split("/").forEach((n) {
      if (n.isNotEmpty) {
        s = s.isEmpty ? n : "$s/$n";
        crumbs.add(BreadCrumbItem(
            content: Text(n),
            onTap: () {
              setState(() {
                _targetFolder = s;
              });
            }));
      }
    });

    var ls = listSubFolders(_args.portalName, _args.zoneName, _targetFolder);
    var subfolders = (_virtualFolders[_targetFolder] ?? []) + ls;
    var items = subfolders
        .map((e) => ListTile(
              leading: const Icon(Icons.folder),
              title: Text(e),
              onTap: () => setState(() {
                _targetFolder = "$_targetFolder/$e";
              }),
            ))
        .toList();

    return Column(
      children: [
        Row(
          children: [
            BreadCrumb(
              items: crumbs,
              divider: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                _createFolderDialog(context).then((value) {
                  var text = _createFolderController.text;
                  if (text.isNotEmpty) {
                    setState(() {
                      if (_virtualFolders[_targetFolder] != null) {
                        _virtualFolders[_targetFolder]?.add(text);
                      } else {
                        _virtualFolders[_targetFolder] = [text];
                      }
                      _createFolderController.clear();
                      _targetFolder =
                          _targetFolder.isEmpty ? text : "$_targetFolder/$text";
                    });
                  }
                });
              },
              icon: const Icon(Icons.create_new_folder),
            ),
          ],
        ),
        ListView(
          padding: const EdgeInsets.all(8.0),
          shrinkWrap: true,
          children: items,
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    _args = ModalRoute.of(context)!.settings.arguments as LibraryUploadArgs;
    _targetName = _args.selection.name;

    var action = _uploading
        ? const CircularProgressIndicator()
        : ElevatedButton(
            onPressed: () {
              try {
                var target = _targetFolder.isEmpty
                    ? _targetName
                    : "$_targetFolder/$_targetName";

                setState(() {
                  _uploading = true;
                });
                var options = PutOptions();
                putFile(_args.portalName, _args.zoneName, target,
                    _args.selection.path, options);
                Navigator.pop(context);
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
        title: Text("Add ${_args.selection.name}"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Builder(
          builder: (context) => Form(
            key: _formKey,
            child: Column(
              children: [
                _getFolderSelection(context),
                TextFormField(
                  maxLines: 6,
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
