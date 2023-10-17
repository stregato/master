import 'package:behemoth/common/progress.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';

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
    var access = args["access"] ?? "";
    var p = Profile.current();
    String title;
    Widget body;

    try {
      var d = decodeAccess(p.identity, access);
      var names = covenAndRoom(d.safeName);

      title = "Join ${names[0]}";
      body = Column(
        children: [
          Text("You have been invited to join ${names[0]}"),
          const SizedBox(height: 20),
          ElevatedButton(
              child: const Text("Accept"),
              onPressed: () async {
                await progressDialog<Coven>(
                    context, "Connect to ${names[0]}", Coven.join(access),
                    successMessage: "Successfully connected to ${names[0]}",
                    errorMessage: "Failed to connect to ${names[0]}");
                if (mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              }),
        ],
      );
    } catch (e) {
      title = "Invalid access link";
      body = Text(
          "cannot access to the community with the provided link: ${e.toString()}");
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(title),
      ),
      body: body,
    );
  }
}
