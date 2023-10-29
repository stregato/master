import 'dart:io';
//import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/io.dart';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_size/window_size.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uni_links_desktop/uni_links_desktop.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS) {
    registerProtocol('mg');
  }

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
  }
}
