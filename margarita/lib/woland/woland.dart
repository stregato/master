import 'dart:ffi'; // For FFI
// For Platform.isX
import 'dart:convert';
import 'dart:io';
import 'package:margarita/woland/woland_def.dart';
import "package:ffi/ffi.dart";
import 'package:flutter/foundation.dart';
import 'woland_platform_interface.dart';

final DynamicLibrary lib = getLibrary();

DynamicLibrary getLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libwoland.so');
  }
  if (Platform.isLinux) {
//    var locs = ['linux/libwoland.so', 'libwoland.so', '/usr/lib/libwoland.so'];
    var locs = ['linux/libwoland.so'];

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
typedef Args1<T> = CResult Function(T);
typedef Args2SS = CResult Function(Pointer<Utf8>, Pointer<Utf8>);
typedef Args3SSS = CResult Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef Args4SSSS = CResult Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef Args5SSSS = CResult Function(
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

List<Identity> getIdentities(String portalName) {
  var fun = lib.lookupFunction<Args1S, Args1S>("getIdentities");
  var l = fun(portalName.toNativeUtf8()).unwrapList();
  return l.map((e) => Identity.fromJson(e)).toList();
}

String encodeToken(
    String userId, String portalName, String aesKey, List<String> urls) {
  var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("encodeToken");
  return fun(userId.toNativeUtf8(), portalName.toNativeUtf8(),
          aesKey.toNativeUtf8(), jsonEncode(urls).toNativeUtf8())
      .unwrapString();
}

DecodedToken decodeToken(Identity user, String token) {
  var fun = lib.lookupFunction<Args2SS, Args2SS>("decodeToken");
  var m =
      fun(jsonEncode(user).toNativeUtf8(), token.toNativeUtf8()).unwrapMap();
  return DecodedToken.fromJson(m);
}

Portal openPortal(Identity identity, String token, OpenOptions options) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("openPortal");
  var m = fun(jsonEncode(identity).toNativeUtf8(), token.toNativeUtf8(),
          jsonEncode(options).toNativeUtf8())
      .unwrapMap();
  return Portal.fromJson(m);
}

void closePortal(String portalName) {
  var fun = lib.lookupFunction<Args1S, Args1S>("closePortal");
  fun(portalName.toNativeUtf8()).unwrapVoid();
}

List<Header> listFiles(
    String portalName, String zoneName, ListOptions options) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("listFiles");
  var l = fun(portalName.toNativeUtf8(), zoneName.toNativeUtf8(),
          jsonEncode(options).toNativeUtf8())
      .unwrapList();
  return l.map((e) => Header.fromJson(e)).toList();
}

List<String> listSubFolders(String portalName, String zoneName, String folder) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("listSubFolders");
  var l = fun(portalName.toNativeUtf8(), zoneName.toNativeUtf8(),
          folder.toNativeUtf8())
      .unwrapList();
  return l.cast<String>();
}

Header putBytes(String portalName, String zoneName, String name, Uint8List data,
    PutOptions putOptions) {
  var base64 = base64Encode(data);
  var fun = lib.lookupFunction<Args5SSSS, Args5SSSS>("putCString");
  var m = fun(
          portalName.toNativeUtf8(),
          zoneName.toNativeUtf8(),
          name.toNativeUtf8(),
          base64.toNativeUtf8(),
          jsonEncode(putOptions).toNativeUtf8())
      .unwrapMap();
  return Header.fromJson(m);
}

Header putObject<T>(String portalName, String zoneName, String name, T object,
    PutOptions putOptions) {
  var fun = lib.lookupFunction<Args5SSSS, Args5SSSS>("putCString");
  var m = fun(
          portalName.toNativeUtf8(),
          zoneName.toNativeUtf8(),
          name.toNativeUtf8(),
          jsonEncode(object).toNativeUtf8(),
          jsonEncode(putOptions).toNativeUtf8())
      .unwrapMap();
  return Header.fromJson(m);
}

Header putFile<T>(String portalName, String zoneName, String name,
    String filepath, PutOptions putOptions) {
  var fun = lib.lookupFunction<Args5SSSS, Args5SSSS>("putFile");
  var m = fun(
          portalName.toNativeUtf8(),
          zoneName.toNativeUtf8(),
          name.toNativeUtf8(),
          filepath.toNativeUtf8(),
          jsonEncode(putOptions).toNativeUtf8())
      .unwrapMap();
  return Header.fromJson(m);
}

typedef JsonFactory<T> = T Function(Map<String, dynamic>);

T getObject<T>(String portalName, String zoneName, String name,
    GetOptions getOptions, JsonFactory<T> fromJson) {
  var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("getCString");

  var m = fun(portalName.toNativeUtf8(), zoneName.toNativeUtf8(),
          name.toNativeUtf8(), jsonEncode(getOptions).toNativeUtf8())
      .unwrapMap();

  return fromJson(m);
}

void createZone(String portalName, String zoneName, Map<String, int> users) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("createZone");
  fun(portalName.toNativeUtf8(), zoneName.toNativeUtf8(),
          jsonEncode(users).toNativeUtf8())
      .unwrapVoid();
}

List<String> listZones(String portalName) {
  var fun = lib.lookupFunction<Args1S, Args1S>("listZones");
  return fun(portalName.toNativeUtf8()).unwrapList().cast<String>();
}

void setUsers(String portalName, String zoneName, Users users) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("setUsers");
  fun(portalName.toNativeUtf8(), zoneName.toNativeUtf8(),
          jsonEncode(users).toNativeUtf8())
      .unwrapVoid();
}

Users getUsers(String portalName, String zoneName) {
  var fun = lib.lookupFunction<Args2SS, Args2SS>("getUsers");
  var m = fun(portalName.toNativeUtf8(), zoneName.toNativeUtf8()).unwrapMap();
  return m.map((key, value) => MapEntry(key, value as Permission));
}

List<String> getLogs() {
  var fun = lib.lookupFunction<Args0, Args0>("getLogs");
  return fun().unwrapList().cast<String>();
}

void setLogLevel(int level) {
  var fun = lib.lookupFunction<Args1<Int>, Args1<int>>("setLogLevel");
  fun(level).unwrapVoid();
}
