import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'woland_platform_interface.dart';

/// An implementation of [PortalpoolPlatform] that uses method channels.
class MethodChannelPortalpool extends PortalpoolPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('woland');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
