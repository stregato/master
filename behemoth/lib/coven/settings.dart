import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';

class CommunitySettings extends StatefulWidget {
  const CommunitySettings({super.key});

  @override
  State<CommunitySettings> createState() => _CommunitySettingsState();
}

class _CommunitySettingsState extends State<CommunitySettings> {
  @override
  Widget build(BuildContext context) {
    final coven = ModalRoute.of(context)!.settings.arguments as Coven;
    var lounge = coven.getLoungeSync()!;

    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
    );

    var quota = lounge.quota == 0
        ? "unlimited"
        : lounge.quota < 1e9
            ? "${lounge.quota / 1e6}MB"
            : "${lounge.quota / 1e9}GB";

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings - ${coven.name}"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Description: ${lounge.description}"),
            const SizedBox(height: 20),
            Text("Quota: $quota"),
            const SizedBox(height: 20),
            Text("Quota Group: ${lounge.quotaGroup}"),
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
                p.covens.remove(coven.name);
                p.save();
                showPlatformSnackbar(
                    context, "you successfully left ${coven.name}",
                    backgroundColor: Colors.green);

                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
