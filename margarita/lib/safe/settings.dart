import 'package:margarita/common/profile.dart';
import 'package:flutter/material.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

const urlHint = "Enter a supported URL and click +";
const validSchemas = ["s3", "sftp", "file"];
const availableApps = ["chat", "library", "gallery"];

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final safeName = ModalRoute.of(context)!.settings.arguments as String;

    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pool Settings"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text("Danger Zone",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              style: buttonStyle,
              label: const Text('Leave'),
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                var p = Profile.current();
                p.communities.remove(safeName);
                p.save();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: Colors.green,
                    content: Text(
                      "you successfully left $safeName",
                    )));

                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
