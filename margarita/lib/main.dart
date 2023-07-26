import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:margarita/common/common.dart';
import 'package:margarita/common/io.dart';

import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uni_links_desktop/uni_links_desktop.dart';

import 'margarita_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      runApp(const MargaritaApp());
    });
  });

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Margarita Desktop');
    getCurrentScreen().then((screen) {
      doWhenWindowReady(() {
        var height = (screen?.visibleFrame.height ?? 800);
        var width = (screen?.frame.width ?? 1024) * 0.2;
        if (width < 200) width = 200;
        if (width > 600) width = 600;

        appWindow.minSize = Size(width, height);
        appWindow.size = Size(width, height);
        appWindow.alignment = Alignment.topRight;

        appWindow.show();
      });
    });
  }
}
