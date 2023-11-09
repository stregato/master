import 'package:behemoth/content/content_add.dart';
import 'package:behemoth/content/content_editor.dart';
import 'package:behemoth/content/content_feed.dart';
import 'package:behemoth/settings/import_profile.dart';
import 'package:behemoth/settings/nolib.dart';
import 'package:behemoth/settings/update_private_key.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/chat/one_to_one.dart';
import 'package:behemoth/coven/add_person.dart';
import 'package:behemoth/coven/invite.dart';
import 'package:behemoth/coven/settings.dart';
import 'package:behemoth/coven/unilink.dart';
import 'package:behemoth/common/io.dart';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/coven/join.dart';
import 'package:behemoth/coven/create_coven.dart';
import 'package:behemoth/room/create_room.dart';
import 'package:behemoth/coven/home.dart';
import 'package:behemoth/content/content_actions.dart';
import 'package:behemoth/content/content_upload.dart';
import 'package:behemoth/coven/coven.dart';
import 'package:behemoth/room/room.dart';
import 'package:behemoth/coven/unilink_accept.dart';
import 'package:behemoth/coven/unilink_invite.dart';
import 'package:behemoth/settings/reset.dart';
import 'package:behemoth/settings/settings.dart';
import 'package:behemoth/settings/setup.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class BehemothApp extends StatefulWidget {
  const BehemothApp({super.key});

  @override
  State<BehemothApp> createState() => _BehemothAppState();
}

class _BehemothAppState extends State<BehemothApp> {
  String initialRoot = "/";
  String err = "";
  ThemeMode? themeMode = ThemeMode.dark; // initial brightness

  _BehemothAppState() {
    try {
      getLibrary();
    } catch (e) {
      initialRoot = "/nolib";
      err = e.toString();
      return;
    }

    try {
      start("$applicationFolder/woland.db", applicationFolder);
      if (!Profile.hasProfile()) {
        initialRoot = "/setup";
      }
    } catch (e) {
      initialRoot = "/reset";
    }

    var d = getConfig("ui", "theme");
    if (d.s == "dark") {
      themeMode = ThemeMode.dark;
    } else if (d.s == "light") {
      themeMode = ThemeMode.light;
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final materialLightTheme = ThemeData.light();
    final materialDarkTheme = ThemeData.dark();

    const darkDefaultCupertinoTheme =
        CupertinoThemeData(brightness: Brightness.dark);
    final cupertinoDarkTheme = MaterialBasedCupertinoThemeData(
      materialTheme: materialDarkTheme.copyWith(
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: Brightness.dark,
          barBackgroundColor: darkDefaultCupertinoTheme.barBackgroundColor,
          textTheme: CupertinoTextThemeData(
            primaryColor: Colors.white,
            navActionTextStyle:
                darkDefaultCupertinoTheme.textTheme.navActionTextStyle.copyWith(
              color: const Color(0xF0F9F9F9),
            ),
            navLargeTitleTextStyle: darkDefaultCupertinoTheme
                .textTheme.navLargeTitleTextStyle
                .copyWith(color: const Color(0xF0F9F9F9)),
          ),
        ),
      ),
    );
    final cupertinoLightTheme =
        MaterialBasedCupertinoThemeData(materialTheme: materialLightTheme);

    return PlatformProvider(
      settings: PlatformSettingsData(
        iosUsesMaterialWidgets: true,
        iosUseZeroPaddingForAppbarPlatformIcon: true,
        // platformStyle: const PlatformStyleData(
        //   linux: PlatformStyle.Cupertino,
        // ),
      ),
      builder: (context) => PlatformTheme(
        themeMode: themeMode,
        materialLightTheme: materialLightTheme,
        materialDarkTheme: materialDarkTheme,
        cupertinoLightTheme: cupertinoLightTheme,
        cupertinoDarkTheme: cupertinoDarkTheme,
        matchCupertinoSystemChromeBrightness: true,
        onThemeModeChanged: (themeMode) {
          this.themeMode = themeMode; /* you can save to storage */
        },
        builder: (context) => PlatformApp(
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          title: 'Behemoth',
          // theme: ThemeData(
          //   primarySwatch: Colors.blue,
          // ),
          initialRoute: initialRoot,
//      home: _reset ? const Reset() : null,
          routes: {
            "/": (context) => const Home(),
            "/nolib": (context) => NoLib(err),
            "/setup": (context) => const Setup(),
            "/reset": (context) => const Reset(),
            "/invite": (context) => const Invite(),
            "/unilink": (context) => const Unilink(),
            "/unilink/invite": (context) => const UnilinkInvite(),
            "/unilink/accept": (context) => const UnilinkAccept(),
            //"/": (context) => const AddCommunity(),
            "/create": (context) => const CreateCoven(),
            "/join": (context) => const Join(),
            "/settings": (context) => const Settings(),
            "/settings/update_key": (context) => const UpdatePrivateKey(),
            "/settings/import_profile": (context) => const ImportProfile(),

            "/coven": (context) => const CovenWidget(),
            "/coven/room": (context) => const Room(),
            "/coven/add_person": (context) => const AddPerson(),
            "/coven/create": (context) => const CreateRoom(),
            "/coven/onetoone": (context) => const Privates(),
            "/coven/settings": (context) => const CommunitySettings(),
            "/content/add": (context) => const ContentAdd(),
            "/content/upload": (context) => const ContentUpload(),
            "/content/editor": (context) => const ContentEditor(),
            "/content/feed": (context) => const ContentFeed(),
// //        "/apps/content/download": (context) => const DownloadFile(),
            "/content/actions": (context) => const ContentActions(),
//         "/apps/invite/list": (context) => const InviteList(),
          },
        ),
      ),
    );
  }
}
