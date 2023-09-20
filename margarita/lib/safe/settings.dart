import 'package:margarita/common/profile.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';

class CommunitySettings extends StatefulWidget {
  const CommunitySettings({super.key});

  @override
  State<CommunitySettings> createState() => _CommunitySettingsState();
}

class _CommunitySettingsState extends State<CommunitySettings> {
  @override
  Widget build(BuildContext context) {
    final community = ModalRoute.of(context)!.settings.arguments as Community;

    var identity = Profile.current().identity;
    var access = community.spaces["welcome"]!;
    var safe = openSafe(identity, access, OpenOptions());

    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(20)),
    );

    var quota = safe.quota == 0
        ? "unlimited"
        : safe.quota < 1e9
            ? "${safe.quota / 1e6}MB"
            : "${safe.quota / 1e9}GB";

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings - ${community.name}"),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Description: ${safe.description}"),
            const SizedBox(height: 20),
            Text("Quota: $quota"),
            const SizedBox(height: 20),
            Text("Quota Group: ${safe.quotaGroup}"),
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
                p.communities.remove(community.name);
                p.save();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: Colors.green,
                    content: Text(
                      "you successfully left ${community.name}}",
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
