import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:ffi/ffi.dart';

List<T> dynamicToList<T>(dynamic value) {
  return ((value ?? []) as List<dynamic>).map((e) => e as T).toList();
}

typedef Args1T<T> = CResult Function(T);
typedef Args3TSS<T> = CResult Function(T, Pointer<Utf8>, Pointer<Utf8>);
typedef Args4TSSS<T> = CResult Function(
    T, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

class Safe {
  DateTime accessed = DateTime.now();
  String access = "";
  Identity currentUser;
  int hnd = 0;
  String creatorId = "";
  String name = "";
  String description = "";
  StorageDesc storage = StorageDesc();
  int quota = 0;
  String quotaGroup = "";

  static Map<String, Safe> instances = {};

  static pretty(String name) {
    var lastSlash = name.lastIndexOf("/");
    var covenName = name.substring(0, lastSlash);
    var roomName = name.substring(lastSlash + 1);
    return "$roomName@$covenName";
  }

  static Future<Safe> open(
      Identity identity, String access, OpenOptions options) async {
    return Isolate.run<Safe>(() => Safe._(identity, access, options));
  }

  static Future create(
      Identity identity, String token, Users users, CreateOptions options) {
    return Isolate.run(() {
      var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("wlnd_createSafe");
      fun(
              jsonEncode(identity).toNativeUtf8(),
              token.toNativeUtf8(),
              jsonEncode(users).toNativeUtf8(),
              jsonEncode(options).toNativeUtf8())
          .unwrapVoid();
    });
  }

  Safe._(Identity identity, this.access, OpenOptions options)
      : currentUser = identity {
    var fun = lib.lookupFunction<Args3SSS, Args3SSS>("wlnd_openSafe");
    var json = fun(jsonEncode(identity).toNativeUtf8(), access.toNativeUtf8(),
            jsonEncode(options).toNativeUtf8())
        .unwrapMap();
    hnd = json['hnd'];
    name = json['name'];
    currentUser = Identity.fromJson(json['currentUser']);
    creatorId = json['creatorId'];
    description = json['description'];
    storage = StorageDesc.fromJson(json['storage']);
    quota = json['quota'] ?? 0;
    quotaGroup = json['quotaGroup'] ?? "";
  }

  void close() {
    var fun = lib.lookupFunction<Args1T<Int>, Args1T<int>>("wlnd_closeSafe");
    fun(hnd).unwrapVoid();
  }

  String get prettyName => Safe.pretty(name);

  void touch() {
    accessed = DateTime.now();
  }

  Future<List<Header>> listFiles(String dir, ListOptions options) async {
    var fun =
        lib.lookupFunction<Args3TSS<Int>, Args3TSS<int>>("wlnd_listFiles");
    var l = fun(hnd, dir.toNativeUtf8(), jsonEncode(options).toNativeUtf8())
        .unwrapList();
    return l.map((e) => Header.fromJson(e)).toList();
  }

  Future<List<String>> listDirs(String dir, ListDirsOptions options) async {
    var fun = lib.lookupFunction<Args3TSS<Int>, Args3TSS<int>>("wlnd_listDirs");
    var l = fun(hnd, dir.toNativeUtf8(), jsonEncode(options).toNativeUtf8())
        .unwrapList();
    return l.cast<String>();
  }

  Future<Header> putBytes(
      String name, Uint8List data, PutOptions putOptions) async {
    var base64 = base64Encode(data);
    var fun =
        lib.lookupFunction<Args4TSSS<Int>, Args4TSSS<int>>("wlnd_putCString");
    var m = fun(hnd, name.toNativeUtf8(), base64.toNativeUtf8(),
            jsonEncode(putOptions).toNativeUtf8())
        .unwrapMap();
    return Header.fromJson(m);
  }

  Future<Header> putFile(
      String name, String filepath, PutOptions putOptions) async {
    return Isolate.run<Header>(() {
      var fun =
          lib.lookupFunction<Args4TSSS<Int>, Args4TSSS<int>>("wlnd_putFile");
      var m = fun(hnd, name.toNativeUtf8(), filepath.toNativeUtf8(),
              jsonEncode(putOptions).toNativeUtf8())
          .unwrapMap();
      return Header.fromJson(m);
    });
  }

  Future<Uint8List> getBytes(String name, GetOptions getOptions) async {
    return Isolate.run(() {
      var fun =
          lib.lookupFunction<Args3TSS<Int>, Args3TSS<int>>("wlnd_getCString");
      var s =
          fun(hnd, name.toNativeUtf8(), jsonEncode(getOptions).toNativeUtf8())
              .unwrapString();
      return base64Decode(s);
    });
  }

  Future getFile(String name, String filepath, GetOptions getOptions) async {
    return Isolate.run(() {
      var fun =
          lib.lookupFunction<Args4TSSS<Int>, Args4TSSS<int>>("wlnd_getFile");
      fun(hnd, name.toNativeUtf8(), filepath.toNativeUtf8(),
              jsonEncode(getOptions).toNativeUtf8())
          .unwrapVoid();
    });
  }

  Future setUsers(Users users, SetUsersOptions options) async {
    return Isolate.run(() {
      var fun =
          lib.lookupFunction<Args3TSS<Int>, Args3TSS<int>>("wlnd_setUsers");
      fun(hnd, jsonEncode(users).toNativeUtf8(),
              jsonEncode(options).toNativeUtf8())
          .unwrapVoid();
    });
  }

  Users getUsersSync() {
    var fun = lib.lookupFunction<Args1T<Int>, Args1T<int>>("wlnd_getUsers");
    var m = fun(hnd).unwrapMap();
    return m.map((key, value) => MapEntry(key, value as Permission));
  }
}
