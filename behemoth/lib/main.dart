import 'dart:async';
import 'dart:io';
//import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/coven/cockpit.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_size/window_size.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uni_links_desktop/uni_links_desktop.dart';

import 'app.dart';

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Cockpit.sync();
    Workmanager().registerOneOffTask("sync", "",
        initialDelay: const Duration(minutes: 3));
    return Future.value(true);
  });
}

void startBackgroundService() {
  if (Platform.isWindows || Platform.isMacOS) {
    registerProtocol('mg');
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    Workmanager().registerOneOffTask("sync", "");
  } else {
    Timer.periodic(const Duration(minutes: 3), (timer) async {
      await Cockpit.sync();
    });
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  startBackgroundService();

  initFolders().then((_) {
    Connectivity().checkConnectivity().then((c) {
      availableBandwidth =
          Platform.isMacOS || Platform.isLinux || Platform.isWindows
              ? "high"
              : c == ConnectivityResult.wifi
                  ? "medium"
                  : "low";
      runApp(const BehemothApp());
    });
  });

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Behemoth Desktop');
    getCurrentScreen().then((screen) {});
  }
}
