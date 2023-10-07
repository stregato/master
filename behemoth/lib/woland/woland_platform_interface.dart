import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'woland_method_channel.dart';

abstract class PortalpoolPlatform extends PlatformInterface {
  /// Constructs a PortalpoolPlatform.
  PortalpoolPlatform() : super(token: _token);

  static final Object _token = Object();

  static PortalpoolPlatform _instance = MethodChannelPortalpool();

  /// The default instance of [PortalpoolPlatform] to use.
  ///
  /// Defaults to [MethodChannelPortalpool].
  static PortalpoolPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PortalpoolPlatform] when
  /// they register themselves.
  static set instance(PortalpoolPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
