import 'package:behemoth/common/progress.dart';
import 'package:behemoth/coven/join_coven.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/profile.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class UnilinkAccept extends StatefulWidget {
  const UnilinkAccept({super.key});

  @override
  State<UnilinkAccept> createState() => _UnilinkAcceptState();
}

class _UnilinkAcceptState extends State<UnilinkAccept> {
  @override
  Widget build(BuildContext context) {
    var args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>;
    var link = args["link"] ?? "";
    String title;
    Widget body;

    var parts = JoinCoven.parseInvite(link);
    if (parts == null) {
      title = "Invalid access link";
      body =
          const Text("cannot access to the community with the provided link");
      return PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text(title),
        ),
        body: body,
      );
    }

    var name = parts[0];
    var creatorId = parts[1];
    var url = parts[2];

    title = "Join $name";
    body = Column(
      children: [
        Text("You have been invited to join $name"),
        const SizedBox(height: 20),
        PlatformElevatedButton(
            child: const Text("Accept"),
            onPressed: () async {
              await progressDialog<Coven>(context, "Connect to $name",
                  Coven.join(name, url, creatorId, ""),
                  successMessage: "Successfully connected to $name",
                  errorMessage: "Failed to connect to $name");
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            }),
      ],
    );

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(title),
      ),
      body: body,
    );
  }
}
