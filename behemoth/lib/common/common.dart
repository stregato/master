import 'dart:io';

final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
final isApple = Platform.isMacOS || Platform.isIOS;
final isMobile = Platform.isAndroid || Platform.isIOS;
var availableBandwidth = "high";
