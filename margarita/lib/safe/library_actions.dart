import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:margarita/common/document.dart';
import 'package:margarita/common/io.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/navigation/bar.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:margarita/common/file_access.dart';
import 'package:intl/intl.dart';

import 'package:path/path.dart' as path;

class LibraryActionsArgs {
  String portalName;
  String zoneName;
  List<Header> versions;

  LibraryActionsArgs(this.portalName, this.zoneName, this.versions);
}

class LibraryActions extends StatefulWidget {
  const LibraryActions({Key? key}) : super(key: key);

  @override
  State<LibraryActions> createState() => _LibraryActionsState();
}

class _LibraryActionsState extends State<LibraryActions> {
  AppTheme theme = LightTheme();
  late LibraryActionsArgs _args;

  @override
  void initState() {
    super.initState();
  }

  static _saveFile(String poolName, int id, String target) {
    return Isolate.run(() {
//TODO      sp.librarySave(poolName, id, target);
      return true;
    });
  }

  static _receiveFile(String poolName, int id, String target) {
    return Isolate.run(() {
//TODO      sp.libraryReceive(poolName, id, target);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    _args = ModalRoute.of(context)!.settings.arguments as LibraryActionsArgs;

    var libraryFolder =
        path.join(documentsFolder, _args.portalName, _args.zoneName);

    return const Text("TODO");
    // var items = <Card>[];
    // if (d.localPath.isNotEmpty && d.state != sp.DocumentState.deleted) {
    //   items.add(
    //     Card(
    //       child: ListTile(
    //         title: const Text("Open Locally"),
    //         leading: const Icon(Icons.file_open),
    //         onTap: () => openFile(context, d.localPath),
    //       ),
    //     ),
    //   );

    //   if (isDesktop) {
    //     items.add(
    //       Card(
    //         child: ListTile(
    //           title: const Text("Open Folder"),
    //           leading: const Icon(Icons.folder_open),
    //           onTap: () => openFile(context, File(d.localPath).parent.path),
    //         ),
    //       ),
    //     );
    //   } else {
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
    //   if (d.state == sp.DocumentState.modified ||
    //       d.state == sp.DocumentState.conflict) {
    //     items.add(
    //       Card(
    //         child: ListTile(
    //           title: const Text("Send update"),
    //           leading: const Icon(Icons.upload_file),
    //           onTap: () {
    //             try {
    //               sp.librarySend(poolName, d.localPath, d.name, true, []);
    //               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //                   backgroundColor: Colors.green,
    //                   content: Text(
    //                     "${d.name} uploaded to $poolName",
    //                   )));
    //             } catch (e) {
    //               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //                   backgroundColor: Colors.red,
    //                   content: Text(
    //                     "Cannot upload ${d.name}: $e",
    //                   )));
    //             }
    //           },
    //         ),
    //       ),
    //     );
    //   }
    // }
    // for (var v in d.versions) {
    //   var author = nicks[v.authorId] ?? "🥸 ${v.authorId}";
    //   DateFormat formatter = DateFormat('E d H:m');
    //   var modTime = formatter.format(v.modTime);
    //   switch (v.state) {
    //     case sp.DocumentState.updated:
    //       var localPath = "";
    //       var message = "";
    //       var title = "";
    //       var canChoose = false;
    //       if (d.localPath.isEmpty) {
    //         localPath = path.join(libraryFolder, d.name);
    //         title = "new file from $author,"
    //             " added on $modTime";
    //         message = "This is new content";
    //         canChoose = isDesktop;
    //       } else {
    //         localPath = d.localPath;
    //         title = "update from $author,"
    //             " added on $modTime";
    //         message = "the file contains an update on something you have";
    //         canChoose = false;
    //       }

    //       items.add(
    //         Card(
    //           child: ListTile(
    //             title: Text(title),
    //             leading: const Icon(Icons.arrow_back),
    //             onTap: () async {
    //               var d = Document(localPath, size: v.size, time: v.modTime);
    //               var target = await chooseFile(context, d,
    //                   message: message, canChoose: canChoose);
    //               if (context.mounted && target != null) {
    //                 var name = path.basename(target);
    //                 progressDialog<bool>(context, "downloading $name",
    //                     _receiveFile(poolName, v.id, target),
    //                     successMessage: "$name received",
    //                     errorMessage: "cannot receive $name",
    //                     getProgress: getProgress(target, v.size));
    //               }
    //             },
    //           ),
    //         ),
    //       );

    //       items.add(
    //         Card(
    //           child: ListTile(
    //             title: Text("download a copy from $author,"
    //                 " added on $modTime"),
    //             leading: const Icon(Icons.download),
    //             onTap: () async {
    //               var target = await chooseFile(
    //                 context,
    //                 Document(path.join(downloadFolder, path.basename(d.name)),
    //                     size: v.size, time: v.modTime),
    //                 canChoose: isDesktop,
    //               );
    //               if (context.mounted && target != null) {
    //                 var name = path.basename(target);
    //                 progressDialog<bool>(context, "downloading $name",
    //                     _saveFile(poolName, v.id, target),
    //                     successMessage: "$name downloaded",
    //                     errorMessage: "cannot download $name",
    //                     getProgress: getProgress(target, v.size));
    //               }
    //             },
    //           ),
    //         ),
    //       );
    //       break;
    //     case sp.DocumentState.conflict:
    //       var message =
    //           "the file was created from an older version than yours; "
    //           "you may lose some data if you update";
    //       var title = "replace with a conflicting file from $author,"
    //           " added on $modTime";
    //       title = "receive a new file from $author,"
    //           " added on $modTime";
    //       message = "new content";
    //       items.add(
    //         Card(
    //           child: ListTile(
    //             title: Text(
    //               title,
    //               style: const TextStyle(color: Colors.amber),
    //             ),
    //             leading: const Icon(Icons.download),
    //             onTap: () {
    //               chooseFile(context,
    //                   Document(d.localPath, time: v.modTime, size: v.size),
    //                   message: message);
    //             },
    //           ),
    //         ),
    //       );
    //       break;
    //     default:
    //       break;
    //   }
    // }

    // if (d.localPath.isNotEmpty && d.state != sp.DocumentState.deleted) {
    //   items.add(
    //     Card(
    //       child: ListTile(
    //         title: const Text("Delete Locally"),
    //         leading: const Icon(Icons.delete),
    //         onTap: () {
    //           deleteFile(context, d.localPath).then((deleted) {
    //             if (deleted ?? false) Navigator.pop(context);
    //           });
    //         },
    //       ),
    //     ),
    //   );
    // }

    // items.add(
    //   Card(
    //     child: ListTile(
    //       title: const Text("Pop on chat"),
    //       leading: const Icon(Icons.delete),
    //       onTap: () {
    //         sp.chatSend(poolName, "", "library:/${d.name}", Uint8List(0), []);
    //       },
    //     ),
    //   ),
    // );
    // return Scaffold(
    //   appBar: AppBar(
    //     title: Text("Library $poolName"),
    //   ),
    //   body: Container(
    //     padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    //     child: Column(children: [
    //       ListView(
    //         shrinkWrap: true,
    //         padding: const EdgeInsets.all(8),
    //         children: items,
    //       ),
    //     ]),
    //   ),
    //   bottomNavigationBar: MainNavigationBar(poolName),
    // );
  }
}
