import 'package:flutter/material.dart';
import 'package:margarita/apps/chat/one_to_one.dart';
import 'package:margarita/safe/invite.dart';
import 'package:margarita/safe/settings.dart';
import 'package:margarita/safe/unilink.dart';
import 'package:margarita/common/io.dart';

import 'package:margarita/common/profile.dart';
import 'package:margarita/safe/add.dart';
import 'package:margarita/safe/create_community.dart';
import 'package:margarita/safe/create_space.dart';
import 'package:margarita/safe/home.dart';
import 'package:margarita/safe/library_actions.dart';
import 'package:margarita/safe/library_upload.dart';
import 'package:margarita/safe/community.dart';
import 'package:margarita/safe/space.dart';
import 'package:margarita/safe/unilink_accept.dart';
import 'package:margarita/safe/unilink_invite.dart';
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

      if (!Profile.hasProfile()) {
        initialRoot = "/setup";
      }
    } catch (e) {
      initialRoot = "/reset";
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
        "/": (context) => const Home(),
        "/setup": (context) => const Setup(),
        "/reset": (context) => const Reset(),
        "/invite": (context) => const Invite(),
        "/unilink": (context) => const Unilink(),
        "/unilink/invite": (context) => const UnilinkInvite(),
        "/unilink/accept": (context) => const UnilinkAccept(),
        //"/": (context) => const AddCommunity(),
        "/create": (context) => const CreateCommunity(),
        "/join": (context) => const Add(),
        "/settings": (context) => const Settings(),

        "/community": (context) => const CommunityView(),
        "/community/space": (context) => const Space(),
        "/community/createSpace": (context) => const CreateSpace(),
        "/community/onetoone": (context) => const OneToOne(),
        "/community/settings": (context) => const CommunitySettings(),

//         "/pool/sub": (context) => const SubPool(),
//         "/pool/settings": (context) => const PoolSettings(),
//         "/apps/chat": (context) => const Chat(),
//         "/apps/private": (context) => const Private(),
//         "/apps/library": (context) => const Library(),
        "/library/upload": (context) => const LibraryUpload(),
// //        "/apps/library/download": (context) => const DownloadFile(),
        "/library/actions": (context) => const LibraryActions(),
//         "/apps/invite/list": (context) => const InviteList(),
      },
    );
  }
}
