import 'dart:io';

final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
final isMac = Platform.isMacOS || Platform.isIOS;
var availableBandwidth = "high";
