// import 'package:margarita/apps/chat/chat.dart';
// import 'package:margarita/apps/private/private.dart';
// import 'package:margarita/apps/invite/invite.dart';
// import 'package:margarita/apps/invite/invite_list.dart';
// import 'package:margarita/apps/library/library.dart';
// import 'package:margarita/apps/library/library_actions.dart';
// import 'package:margarita/apps/library/upload_file.dart';

// import 'package:margarita/portal/addpool.dart';
// import 'package:margarita/portal/create.dart';
// import 'package:margarita/portal/join_by_number.dart';
// import 'package:margarita/portal/join_by_token.dart';
// import 'package:margarita/portal/pool.dart';
// import 'package:margarita/portal/home.dart';
// import 'package:margarita/portal/settings.dart';
// import 'package:margarita/portal/subpool.dart';
// import 'package:margarita/settings/reset.dart';
// import 'package:margarita/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:margarita/common/io.dart';

import 'package:margarita/common/profile.dart';
import 'package:margarita/safe/add.dart';
import 'package:margarita/safe/addportal.dart';
import 'package:margarita/safe/create.dart';
import 'package:margarita/safe/home.dart';
import 'package:margarita/safe/portal.dart';
import 'package:margarita/settings/reset.dart';
import 'package:margarita/settings/settings.dart';
import 'package:margarita/settings/setup.dart';
import 'package:margarita/woland/woland.dart';

class MargaritaApp extends StatefulWidget {
  const MargaritaApp({super.key});

  @override
  State<MargaritaApp> createState() => _MargaritaAppState();
}

class _MargaritaAppState extends State<MargaritaApp> {
  String initialRoot = "/";

  _MargaritaAppState() {
    try {
      start("$applicationFolder/woland.db", applicationFolder);
      loadProfiles();
    } catch (e) {
      initialRoot = "/reset";
    }
  }

  void loadProfiles() {
    var sib = getConfig("margarita", "profiles");
    if (sib.missing) {
      initialRoot = "/setup";
    } else {
      profiles = readProfiles(sib.b);
      if (profiles.isEmpty) {
        initialRoot = "/setup";
      } else {
        currentProfile = profiles[0];
      }
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caspian',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: initialRoot,
//      home: _reset ? const Reset() : null,
      routes: {
        "/": (context) => const HomeView(),
        "/setup": (context) => const Setup(),
        "/reset": (context) => const Reset(),
        "/addPortal": (context) => const AddPortal(),
        "/addPortal/create": (context) => const CreatePortal(),
        "/addPortal/add": (context) => const Add(),
        "/settings": (context) => const Settings(),

        "/portal": (context) => const PortalView(),
//         "/pool/sub": (context) => const SubPool(),
//         "/pool/settings": (context) => const PoolSettings(),
//         "/apps/chat": (context) => const Chat(),
//         "/apps/private": (context) => const Private(),
//         "/apps/library": (context) => const Library(),
//         "/apps/library/upload": (context) => const UploadFile(),
// //        "/apps/library/download": (context) => const DownloadFile(),
//         "/apps/library/actions": (context) => const LibraryActions(),
//         "/apps/invite": (context) => const Invite(),
//         "/apps/invite/list": (context) => const InviteList(),
      },
    );
  }
}
