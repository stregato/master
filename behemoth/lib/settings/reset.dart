//import 'package:file_selector/file_selector.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';

class Reset extends StatefulWidget {
  const Reset({Key? key}) : super(key: key);

  @override
  State<Reset> createState() => _Reset();
}

class _Reset extends State<Reset> {
  int _fullReset = 3;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(14)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Major Issue"),
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                "Possible corrupted database. You can try a factory reset"),
            const SizedBox(
              height: 14,
            ),
            ElevatedButton.icon(
                style: buttonStyle,
                label: Text("Factory Reset (click $_fullReset times)"),
                icon: const Icon(Icons.restore),
                onPressed: () => setState(() {
                      if (_fullReset == 1) {
                        clearIdentities();
                        factoryReset();
                        start(
                            "$applicationFolder/woland.db", applicationFolder);
                        _fullReset = 3;
                        showPlatformSnackbar(
                            context, "Full Reset completed! Good luck",
                            backgroundColor: Colors.green);
                        Navigator.of(context).pop();
                        Navigator.pushReplacementNamed(context, "/");
                      } else {
                        _fullReset--;
                        showPlatformSnackbar(
                            context, "$_fullReset clicks to factory reset!",
                            backgroundColor: Colors.red,
                            duration: const Duration(milliseconds: 300));
                      }
                    })),
          ],
        ),
      ),
    );
  }
}
