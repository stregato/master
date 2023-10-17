import 'dart:ffi'; // For FFI
// For Platform.isX
import 'dart:convert';
import 'dart:io';
import 'package:behemoth/woland/types.dart';
import "package:ffi/ffi.dart";
import 'package:flutter/foundation.dart';
import 'woland_platform_interface.dart';

final DynamicLibrary lib = getLibrary();

DynamicLibrary getLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libwoland.so');
  }
  if (Platform.isLinux) {
    var locs = ['linux/libwoland.so', 'libwoland.so', '/lib/libwoland.so'];
//    var locs = ['linux/libwoland.so'];

    for (var loc in locs) {
      try {
        return DynamicLibrary.open(loc);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    }
  }
  if (Platform.isMacOS) {
    // if (kDebugMode) {
    //   return DynamicLibrary.open('macos/libs/amd64/libwoland.dylib');
    // } else {
    return DynamicLibrary.open('libwoland.dylib');
    // }
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
    //return DynamicLibrary.open('libwoland.dylib');
  }
  return DynamicLibrary.process();
}

class Woland {
  Future<String?> getPlatformVersion() {
    return PortalpoolPlatform.instance.getPlatformVersion();
  }
}

class CResult extends Struct {
  external Pointer<Utf8> res;
  external Pointer<Utf8> err;

  void unwrapVoid() {
    if (err.address != 0) {
      throw CException(err.toDartString());
    }
  }

  String unwrapRaw() {
    unwrapVoid();
    if (res.address == 0) {
      return "";
    }

    return res.toDartString();
  }

  String unwrapString() {
    unwrapVoid();
    if (res.address == 0) {
      return "";
    }

    return jsonDecode(res.toDartString()) as String;
  }

  int unwrapInt() {
    unwrapVoid();

    return jsonDecode(res.toDartString()) as int;
  }

  Map<String, dynamic> unwrapMap() {
    unwrapVoid();
    if (res.address == 0) {
      return {};
    }

    return jsonDecode(res.toDartString()) as Map<String, dynamic>;
  }

  List<dynamic> unwrapList() {
    if (err.address != 0) {
      throw CException(err.toDartString());
    }
    if (res.address == 0) {
      return [];
    }

    var ls = jsonDecode(res.toDartString());

    return ls == null ? [] : ls as List<dynamic>;
  }
}

class CException implements Exception {
  String msg;
  CException(this.msg);

  @override
  String toString() {
    return msg;
  }
}

typedef Args0 = CResult Function();
typedef Args1S = CResult Function(Pointer<Utf8>);
typedef Args1T<T> = CResult Function(T);
typedef Args2SS = CResult Function(Pointer<Utf8>, Pointer<Utf8>);
typedef Args3SSS = CResult Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef Args4SSSS = CResult Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef Args4SSST<T> = CResult Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, T);
typedef Args5SSSSS = CResult Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

void start(String dbPath, String appPath) {
  var startC = lib.lookupFunction<Args2SS, Args2SS>("start");
  startC(dbPath.toNativeUtf8(), appPath.toNativeUtf8()).unwrapVoid();
}

void stop() {
  var fun = lib.lookupFunction<Args0, Args0>("stop");
  fun().unwrapVoid();
}

void factoryReset() {
  var fun = lib.lookupFunction<Args0, Args0>("factoryReset");
  fun().unwrapVoid();
}

SIB getConfig(String node, String key) {
  var fun = lib.lookupFunction<Args2SS, Args2SS>("getConfig");
  var m = fun(node.toNativeUtf8(), key.toNativeUtf8()).unwrapMap();
  return SIB.fromJson(m);
}

void setConfig(String node, String key, SIB value) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("setConfig");
  fun(node.toNativeUtf8(), key.toNativeUtf8(), jsonEncode(value).toNativeUtf8())
      .unwrapVoid();
}

Identity newIdentity(String nick) {
  var fun = lib.lookupFunction<Args1S, Args1S>("newIdentity");
  var m = fun(nick.toNativeUtf8()).unwrapMap();
  return Identity.fromJson(m);
}

void setIdentity(Identity identity) {
  var fun = lib.lookupFunction<Args1S, Args1S>("setIdentity");
  var j = jsonEncode(identity);
  fun(j.toNativeUtf8()).unwrapVoid();
}

Identity getIdentity(String id) {
  var fun = lib.lookupFunction<Args1S, Args1S>("getIdentity");
  var m = fun(id.toNativeUtf8()).unwrapMap();
  return Identity.fromJson(m);
}

List<Identity> getIdentities(String safeName) {
  var fun = lib.lookupFunction<Args1S, Args1S>("getIdentities");
  var l = fun(safeName.toNativeUtf8()).unwrapList();
  return l.map((e) => Identity.fromJson(e)).toList();
}

String encodeAccess(String userId, String safeName, String creatorId,
    String aesKey, List<String> urls) {
  var fun = lib.lookupFunction<Args5SSSSS, Args5SSSSS>("encodeAccess");
  return fun(
          userId.toNativeUtf8(),
          safeName.toNativeUtf8(),
          creatorId.toNativeUtf8(),
          aesKey.toNativeUtf8(),
          jsonEncode(urls).toNativeUtf8())
      .unwrapString();
}

DecodedToken decodeAccess(Identity user, String access) {
  var fun = lib.lookupFunction<Args2SS, Args2SS>("decodeAccess");
  var m =
      fun(jsonEncode(user).toNativeUtf8(), access.toNativeUtf8()).unwrapMap();
  return DecodedToken.fromJson(m);
}

// Safe createSafe(Identity identity, String token, CreateOptions options) {
//   var fun = lib.lookupFunction<Args3SSS, Args3SSS>("createSafe");
//   var m = fun(jsonEncode(identity).toNativeUtf8(), token.toNativeUtf8(),
//           jsonEncode(options).toNativeUtf8())
//       .unwrapMap();
//   return Safe.fromJson(m);
// }

// Safe openSafe(Identity identity, String token, OpenOptions options) {
//   var fun = lib.lookupFunction<Args3SSS, Args3SSS>("openSafe");
//   var m = fun(jsonEncode(identity).toNativeUtf8(), token.toNativeUtf8(),
//           jsonEncode(options).toNativeUtf8())
//       .unwrapMap();
//   return Safe.fromJson(m);
// }

// void closeSafe(String safeName) {
//   var fun = lib.lookupFunction<Args1S, Args1S>("closeSafe");
//   fun(safeName.toNativeUtf8()).unwrapVoid();
// }

// List<Header> listFiles(String safeName, String dir, ListOptions options) {
//   var fun = lib.lookupFunction<Args3SSS, Args3SSS>("listFiles");
//   var l = fun(safeName.toNativeUtf8(), dir.toNativeUtf8(),
//           jsonEncode(options).toNativeUtf8())
//       .unwrapList();
//   return l.map((e) => Header.fromJson(e)).toList();
// }

// List<String> listDirs(String safeName, String dir, ListDirsOptions options) {
//   var fun = lib.lookupFunction<Args3SSS, Args3SSS>("listDirs");
//   var l = fun(safeName.toNativeUtf8(), dir.toNativeUtf8(),
//           jsonEncode(options).toNativeUtf8())
//       .unwrapList();
//   return l.cast<String>();
// }

// Header putBytes(
//     String safeName, String name, Uint8List data, PutOptions putOptions) {
//   var base64 = base64Encode(data);
//   var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("putCString");
//   var m = fun(safeName.toNativeUtf8(), name.toNativeUtf8(),
//           base64.toNativeUtf8(), jsonEncode(putOptions).toNativeUtf8())
//       .unwrapMap();
//   return Header.fromJson(m);
// }

// Header putObject<T>(
//     String safeName, String name, T object, PutOptions putOptions) {
//   var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("putCString");
//   var m = fun(
//           safeName.toNativeUtf8(),
//           name.toNativeUtf8(),
//           jsonEncode(object).toNativeUtf8(),
//           jsonEncode(putOptions).toNativeUtf8())
//       .unwrapMap();
//   return Header.fromJson(m);
// }

// Header putFile<T>(
//     String safeName, String name, String filepath, PutOptions putOptions) {
//   var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("putFile");
//   var m = fun(safeName.toNativeUtf8(), name.toNativeUtf8(),
//           filepath.toNativeUtf8(), jsonEncode(putOptions).toNativeUtf8())
//       .unwrapMap();
//   return Header.fromJson(m);
// }

// typedef JsonFactory<T> = T Function(Map<String, dynamic>);

// T getObject<T>(String safeName, String name, GetOptions getOptions,
//     JsonFactory<T> fromJson) {
//   var fun = lib.lookupFunction<Args3SSS, Args3SSS>("getCString");

//   var m = fun(safeName.toNativeUtf8(), name.toNativeUtf8(),
//           jsonEncode(getOptions).toNativeUtf8())
//       .unwrapMap();

//   return fromJson(m);
// }

// void getFile(
//     String safeName, String name, String filepath, GetOptions getOptions) {
//   var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("getFile");
//   fun(safeName.toNativeUtf8(), name.toNativeUtf8(), filepath.toNativeUtf8(),
//           jsonEncode(getOptions).toNativeUtf8())
//       .unwrapVoid();
// }

// void createZone(String safeName, Map<String, int> users) {
//   var fun = lib.lookupFunction<Args2SS, Args2SS>("createZone");
//   fun(safeName.toNativeUtf8(), jsonEncode(users).toNativeUtf8()).unwrapVoid();
// }

// void setUsers(String safeName, Users users, SetUsersOptions options) {
//   var fun = lib.lookupFunction<Args3SSS, Args3SSS>("setUsers");
//   fun(safeName.toNativeUtf8(), jsonEncode(users).toNativeUtf8(),
//           jsonEncode(options).toNativeUtf8())
//       .unwrapVoid();
// }

// Users getUsers(String safeName) {
//   var fun = lib.lookupFunction<Args1S, Args1S>("getUsers");
//   var m = fun(safeName.toNativeUtf8()).unwrapMap();
//   return m.map((key, value) => MapEntry(key, value as Permission));
// }

// typedef Args4SSSI = Args4SSST<Int>;
// typedef Args4SSSi = Args4SSST<int>;
// List<String> checkForUpdates(
//     String safeName, String dir, DateTime after, int depth) {
//   var fun = lib.lookupFunction<Args4SSSI, Args4SSSi>("checkForUpdates");
//   var l = fun(safeName.toNativeUtf8(), dir.toNativeUtf8(),
//           after.toUtc().toIso8601String().toNativeUtf8(), depth)
//       .unwrapList();
//   return l.cast<String>();
// }

List<Identity> getAllIdentities() {
  var fun = lib.lookupFunction<Args0, Args0>("getAllIdentities");
  var l = fun().unwrapList();
  return l.map((e) => Identity.fromJson(e)).toList();
}

List<String> getLogs() {
  var fun = lib.lookupFunction<Args0, Args0>("getLogs");
  return fun().unwrapList().cast<String>();
}

void setLogLevel(int level) {
  var fun = lib.lookupFunction<Args1T<Int>, Args1T<int>>("setLogLevel");
  fun(level).unwrapVoid();
}
