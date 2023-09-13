import 'package:flutter/material.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';

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
    var current = Profile.current();
    String title;
    Widget body;

    try {
      var safe = openSafe(current.identity, access, OpenOptions());
      var identities = getIdentities(safe.name);
      title = "Access to ${safe.name}";

      var creatorIdentity = identities.where((e) => e.id == safe.creatorId);
      var creatorNick = creatorIdentity.isNotEmpty
          ? creatorIdentity.first.nick
          : safe.creatorId;
      body = Column(
        children: [
          Text("You have been invited to join ${safe.name} by $creatorNick"),
          ElevatedButton(
              child: const Text("Accept"),
              onPressed: () {
                var parts = safe.name.split('/');
                var space = parts.removeLast();
                var name = parts.join('/');
                var communities = current.communities;
                var community =
                    communities.putIfAbsent(name, () => Community(name, {}));
                community.spaces[space] = access;
                current.save();
                Navigator.popUntil(context, (route) => route.isFirst);
              }),
        ],
      );
    } catch (e) {
      title = "No access to community";
      body = Text(
          "cannot access to the community with the provided link: ${e.toString()}");
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(title),
      ),
      body: body,
//      bottomNavigationBar: MainNavigationBar(safeName),
    );
  }
}
