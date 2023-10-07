import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
//import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';

// ignore: import_of_legacy_library_into_null_portal
import 'package:url_launcher/url_launcher.dart';

late Directory applicationSupportDirectory;

Future<bool> openFile(BuildContext context, String filePath) {
  // try {
  // if (Platform.isAndroid || Platform.isIOS) {
  //   return of.OpenFile.open(filePath).then((value) {
  //     return value.message;
  //   });
  // } else {
  //   await launchUrl(filePath);
  //   w.fileOpen(filePath);
  //   return Future.value("");
  // }

  var url = File(filePath).uri;
  return launchUrl(url);

  // } catch (e) {
  //    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //                         backgroundColor: Colors.red,
  //                         content: Text(
  //                           "Cannot upload $_targetName: $e",
  //                         )));
  //                   }
  // }
}

void deleteError(BuildContext context, String filePath, Object? e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.red,
      content: Text(
        "Cannot delete $filePath: $e",
      ),
    ),
  );
  Navigator.pop(context, false);
}

Future<bool?> deleteFile(BuildContext context, String filePath) {
// set up the buttons

  Widget cancelButton = ElevatedButton(
    child: const Text("Cancel"),
    onPressed: () {
      Navigator.pop(context, false);
    },
  );
  Widget continueButton = ElevatedButton(
      child: const Text("Continue"),
      onPressed: () async {
        if (filePath.isEmpty) return;
        try {
          File(filePath)
              .delete()
              .then((value) => Navigator.pop(context, true))
              .onError(
                  (error, stackTrace) => deleteError(context, filePath, error));
        } catch (e) {
          deleteError(context, filePath, e);
        }
      }); // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: const Text("Confirm Deletion"),
    content: Text("Do you want to delete the file $filePath"),
    actions: [
      cancelButton,
      continueButton,
    ],
  ); // show the dialog
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

class FileSelection {
  String name;
  String path;
  bool volatile;
  bool valid;
  FileSelection(this.name, this.path, this.volatile) : valid = true;

  FileSelection.cancel()
      : name = "",
        path = "",
        volatile = false,
        valid = false;
}

Future<FileSelection> getFile(BuildContext context) async {
  // Directory appDocDir = await getApplicationDocumentsDirectory();

  // return FilesystemPicker.open(
  //   context: context,
  //   rootDirectory: appDocDir,
  // ).then<FileSelection>((v) {
  //   return FileSelection(v ?? "", v ?? "", false);
  // });

//  if (Platform.isAndroid) {
  return FilePicker.platform.pickFiles().then<FileSelection>((v) {
    if (v == null || v.count != 1) {
      return FileSelection.cancel();
    } else {
      var f = v.files[0];
      return FileSelection(f.name, f.path ?? f.name, true);
    }
  });
//    });
//  } else {
  // return fs.openFile().then<FileSelection>((v) {
  //   if (v == null) {
  //     return FileSelection.cancel();
  //   } else {
  //     return FileSelection(v.name, v.path, false);
  //   }
  // });
  //}
}
