import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';

class CovenSettings extends StatefulWidget {
  const CovenSettings({super.key});

  @override
  State<CovenSettings> createState() => _CovenSettingsState();
}

class _CovenSettingsState extends State<CovenSettings> {
  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final coven = args['coven'] as Coven;
    var safe = coven.safe;

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
        title: Text("Settings - ${coven.name}"),
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
                var p = Profile.current;
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
