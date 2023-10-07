import 'package:flutter/material.dart';
import 'package:behemoth/apps/chat/one_to_one.dart';
import 'package:behemoth/coven/add_person.dart';
import 'package:behemoth/coven/invite.dart';
import 'package:behemoth/coven/settings.dart';
import 'package:behemoth/coven/unilink.dart';
import 'package:behemoth/common/io.dart';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/add.dart';
import 'package:behemoth/coven/create_coven.dart';
import 'package:behemoth/coven/create_room.dart';
import 'package:behemoth/coven/home.dart';
import 'package:behemoth/coven/library_actions.dart';
import 'package:behemoth/coven/library_upload.dart';
import 'package:behemoth/coven/coven.dart';
import 'package:behemoth/coven/room.dart';
import 'package:behemoth/coven/unilink_accept.dart';
import 'package:behemoth/coven/unilink_invite.dart';
import 'package:behemoth/settings/reset.dart';
import 'package:behemoth/settings/settings.dart';
import 'package:behemoth/settings/setup.dart';
import 'package:behemoth/woland/woland.dart';

class BehemothApp extends StatefulWidget {
  const BehemothApp({super.key});

  @override
  State<BehemothApp> createState() => _BehemothAppState();
}

class _BehemothAppState extends State<BehemothApp> {
  String initialRoot = "/";

  _BehemothAppState() {
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
        "/create": (context) => const CreateCoven(),
        "/join": (context) => const Add(),
        "/settings": (context) => const Settings(),

        "/coven": (context) => const CovenWidget(),
        "/coven/room": (context) => const Room(),
        "/coven/add_person": (context) => const AddPerson(),
        "/coven/create": (context) => const CreateRoom(),
        "/coven/onetoone": (context) => const Privates(),
        "/coven/settings": (context) => const CommunitySettings(),

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
