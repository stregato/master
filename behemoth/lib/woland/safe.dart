import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

List<T> dynamicToList<T>(dynamic value) {
  return ((value ?? []) as List<dynamic>).map((e) => e as T).toList();
}

typedef CallbackC = Void Function(CResult);
typedef CallbackP = Pointer<NativeFunction<CallbackC>>;

typedef Args1T<T> = CResult Function(T);
typedef Args2TS<T> = CResult Function(T, Pointer<Utf8>);
typedef Args3TSS<T> = CResult Function(T, Pointer<Utf8>, Pointer<Utf8>);
typedef Args3TST<T1, T2> = CResult Function(T1, Pointer<Utf8>, T2);
typedef Args4TSSS<T> = CResult Function(
    T, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef Args5TSSSS<T> = CResult Function(
    T, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

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

  static Future<Safe> open(
      Identity identity, String access, OpenOptions options) async {
    return Isolate.run<Safe>(() {
      var fun = lib.lookupFunction<Args3SSS, Args3SSS>("wlnd_openSafe");
      var json = fun(jsonEncode(identity).toNativeUtf8(), access.toNativeUtf8(),
              jsonEncode(options).toNativeUtf8())
          .unwrapMap();
      var safe = Safe._(identity);
      safe.fromJson(json);
      return safe;
    });
  }

  static Future<Safe> create(
      Identity identity, String token, Users users, CreateOptions options) {
    return Isolate.run<Safe>(() {
      var fun = lib.lookupFunction<Args4SSSS, Args4SSSS>("wlnd_createSafe");
      var json = fun(
              jsonEncode(identity).toNativeUtf8(),
              token.toNativeUtf8(),
              jsonEncode(users).toNativeUtf8(),
              jsonEncode(options).toNativeUtf8())
          .unwrapMap();
      var safe = Safe._(identity);
      safe.fromJson(json);
      return safe;
    });
  }

  Safe._(Identity identity) : currentUser = identity;

  fromJson(Map<String, dynamic> json) {
    hnd = json['hnd'];
    name = json['name'];
    access = json['access'];
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

  void touch() {
    accessed = DateTime.now();
  }

  Future<int> syncBucket(String bucket, SyncOptions options) async {
    var fun =
        lib.lookupFunction<Args3TSS<Int32>, Args3TSS<int>>("wlnd_syncBucket");
    return fun(hnd, bucket.toNativeUtf8(), jsonEncode(options).toNativeUtf8())
        .unwrapInt();
  }

  Future<int> syncUsers() async {
    var fun = lib.lookupFunction<Args1T<Int32>, Args1T<int>>("wlnd_syncUsers");
    return fun(hnd).unwrapInt();
  }

  List<Header> listFiles(String bucket, ListOptions options) {
    var fun =
        lib.lookupFunction<Args3TSS<Int>, Args3TSS<int>>("wlnd_listFiles");
    var l = fun(hnd, bucket.toNativeUtf8(), jsonEncode(options).toNativeUtf8())
        .unwrapList();
    return l.map((e) => Header.fromJson(e)).toList();
  }

  Future<List<String>> listDirs(String bucket, ListDirsOptions options) async {
    var fun = lib.lookupFunction<Args3TSS<Int>, Args3TSS<int>>("wlnd_listDirs");
    var l = fun(hnd, bucket.toNativeUtf8(), jsonEncode(options).toNativeUtf8())
        .unwrapList();
    return l.cast<String>();
  }

  Future<Header> putBytes(
      String bucket, String name, Uint8List data, PutOptions putOptions) async {
    var base64 = base64Encode(data);
    var fun =
        lib.lookupFunction<Args5TSSSS<Int>, Args5TSSSS<int>>("wlnd_putCString");
    var m = fun(hnd, bucket.toNativeUtf8(), name.toNativeUtf8(),
            base64.toNativeUtf8(), jsonEncode(putOptions).toNativeUtf8())
        .unwrapMap();
    return Header.fromJson(m);
  }

  Future<Header> putFile(String bucket, String name, String filepath,
      PutOptions putOptions) async {
    return Isolate.run<Header>(() {
      var fun =
          lib.lookupFunction<Args5TSSSS<Int>, Args5TSSSS<int>>("wlnd_putFile");
      var m = fun(hnd, bucket.toNativeUtf8(), name.toNativeUtf8(),
              filepath.toNativeUtf8(), jsonEncode(putOptions).toNativeUtf8())
          .unwrapMap();
      return Header.fromJson(m);
    });
  }

  Future<Uint8List> getBytes(
      String bucket, String name, GetOptions getOptions) async {
    return Isolate.run(() {
      var fun =
          lib.lookupFunction<Args4TSSS<Int>, Args4TSSS<int>>("wlnd_getCString");
      var s = fun(hnd, bucket.toNativeUtf8(), name.toNativeUtf8(),
              jsonEncode(getOptions).toNativeUtf8())
          .unwrapString();
      return base64Decode(s);
    });
  }

  Future getFile(String bucket, String name, String filepath,
      GetOptions getOptions) async {
    return Isolate.run(() {
      var fun =
          lib.lookupFunction<Args5TSSSS<Int>, Args5TSSSS<int>>("wlnd_getFile");
      fun(hnd, bucket.toNativeUtf8(), name.toNativeUtf8(),
              filepath.toNativeUtf8(), jsonEncode(getOptions).toNativeUtf8())
          .unwrapVoid();
    });
  }

  void deleteFile(String bucket, int fileId) {
    var fun = lib.lookupFunction<Args3TST<Int, Int>, Args3TST<int, int>>(
        "wlnd_deleteFile");
    fun(hnd, bucket.toNativeUtf8(), fileId).unwrapVoid();
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

  Initiates getInitiatesSync() {
    var fun = lib.lookupFunction<Args1T<Int>, Args1T<int>>("wlnd_getInitiates");
    var m = fun(hnd).unwrapMap();
    return m.map((key, value) => MapEntry(key, value as String));
  }
}
