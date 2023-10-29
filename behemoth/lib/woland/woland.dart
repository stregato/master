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

sealed class CResult extends Struct {
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
  var startC = lib.lookupFunction<Args2SS, Args2SS>("wlnd_start");
  startC(dbPath.toNativeUtf8(), appPath.toNativeUtf8()).unwrapVoid();
}

void stop() {
  var fun = lib.lookupFunction<Args0, Args0>("wlnd_stop");
  fun().unwrapVoid();
}

void factoryReset() {
  var fun = lib.lookupFunction<Args0, Args0>("wlnd_factoryReset");
  fun().unwrapVoid();
}

SIB getConfig(String node, String key) {
  var fun = lib.lookupFunction<Args2SS, Args2SS>("wlnd_getConfig");
  var m = fun(node.toNativeUtf8(), key.toNativeUtf8()).unwrapMap();
  return SIB.fromJson(m);
}

void setConfig(String node, String key, SIB value) {
  var fun = lib.lookupFunction<Args3SSS, Args3SSS>("wlnd_setConfig");
  fun(node.toNativeUtf8(), key.toNativeUtf8(), jsonEncode(value).toNativeUtf8())
      .unwrapVoid();
}

Identity newIdentity(String nick) {
  var fun = lib.lookupFunction<Args1S, Args1S>("wlnd_newIdentity");
  var m = fun(nick.toNativeUtf8()).unwrapMap();
  return Identity.fromJson(m);
}

void setIdentity(Identity identity) {
  var fun = lib.lookupFunction<Args1S, Args1S>("wlnd_setIdentity");
  var j = jsonEncode(identity);
  fun(j.toNativeUtf8()).unwrapVoid();
}

Identity getIdentity(String id) {
  var fun = lib.lookupFunction<Args1S, Args1S>("wlnd_getIdentity");
  var m = fun(id.toNativeUtf8()).unwrapMap();
  return Identity.fromJson(m);
}

List<Identity> getIdentities(String safeName) {
  var fun = lib.lookupFunction<Args1S, Args1S>("wlnd_getIdentities");
  var l = fun(safeName.toNativeUtf8()).unwrapList();
  return l.map((e) => Identity.fromJson(e)).toList();
}

String encodeAccess(
    String userId, String safeName, String creatorId, List<String> urls,
    {String aesKey = ""}) {
  var fun = lib.lookupFunction<Args5SSSSS, Args5SSSSS>("wlnd_encodeAccess");
  return fun(
          userId.toNativeUtf8(),
          safeName.toNativeUtf8(),
          creatorId.toNativeUtf8(),
          jsonEncode(urls).toNativeUtf8(),
          aesKey.toNativeUtf8())
      .unwrapString();
}

DecodedToken decodeAccess(Identity user, String access) {
  var fun = lib.lookupFunction<Args2SS, Args2SS>("wlnd_decodeAccess");
  var m =
      fun(jsonEncode(user).toNativeUtf8(), access.toNativeUtf8()).unwrapMap();
  return DecodedToken.fromJson(m);
}

List<Identity> getAllIdentities() {
  var fun = lib.lookupFunction<Args0, Args0>("wlnd_getAllIdentities");
  var l = fun().unwrapList();
  return l.map((e) => Identity.fromJson(e)).toList();
}

List<String> getLogs() {
  var fun = lib.lookupFunction<Args0, Args0>("wlnd_getLogs");
  return fun().unwrapList().cast<String>();
}

void setLogLevel(int level) {
  var fun = lib.lookupFunction<Args1T<Int>, Args1T<int>>("wlnd_setLogLevel");
  fun(level).unwrapVoid();
}
