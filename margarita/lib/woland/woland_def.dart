import 'dart:convert';
import 'dart:typed_data';

List<T> dynamicToList<T>(dynamic value) {
  return ((value ?? []) as List<dynamic>).map((e) => e as T).toList();
}

class SIB {
  String s = "";
  int i = 0;
  Uint8List b = Uint8List(0);
  bool missing = false;

  SIB.fromString(this.s);
  SIB.fromInt(this.i);
  SIB.fromBytes(this.b);

  SIB.fromJson(Map<String, dynamic> json)
      : s = json['s'] ?? "",
        i = json['i'] ?? 0,
        b = base64Decode(json['b'] ?? ""),
        missing = json['missing'] ?? false;

  Map<String, dynamic> toJson() => {
        's': s,
        'i': i,
        'b': base64Encode(b),
        'missing': missing,
      };
}

class Identity {
  String id = "";
  String nick = "";
  String email = "";
  String private = "";

  Uint8List avatar = Uint8List(0);

  Identity();

  Identity.fromJson(Map<String, dynamic> json)
      : id = json['i'],
        nick = json['n'],
        email = json['m'] ?? "",
        private = json['p'] ?? "",
        avatar = base64Decode(json["a"] ?? "");

  Map<String, dynamic> toJson() => {
        'i': id,
        'n': nick,
        'm': email.isNotEmpty ? email : null,
        'p': private.isNotEmpty ? private : null,
        'a': avatar.isNotEmpty ? base64Encode(avatar) : null,
      };
}

class DecodedToken {
  String portalName = "";
  String aesKey = "";
  List<String> urls = [];

  DecodedToken.fromJson(Map<String, dynamic> json)
      : portalName = json['portalName'],
        aesKey = json['aesKey'],
        urls = dynamicToList(json['urls']);

  Map<String, dynamic> toJson() => {
        'portalName': portalName,
        'aesKey': aesKey,
        'urls': urls,
      };
}

class Portal {
  String name = "";
  Identity currentUser;

  Portal.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        currentUser = Identity.fromJson(json['currentUser']);

  Map<String, dynamic> toJson() => {
        'name': name,
        'currentUser': currentUser.toJson(),
      };
}

class Header {
  String name = '';
  String author = '';
  int size = 0;
  Uint8List hash = Uint8List(0);
  bool zip = false;
  List<String> tags = [];
  Uint8List thumbnail = Uint8List(0);
  String contentType = '';
  DateTime modTime = DateTime(0);
  Map<String, dynamic> meta = {};
  int bodyID = 0;
  Uint8List bodyKey = Uint8List(0);
  Uint8List iv = Uint8List(0);
  bool deleted = false;
  Map<String, DateTime> downloads = {};
  String cached = '';
  DateTime cachedExpires = DateTime.now();

  Header.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        author = json['author'],
        size = json['size'],
        hash = base64Decode(json['hash'] ?? ""),
        zip = json['zip'],
        tags = dynamicToList(json['tags']),
        thumbnail = base64Decode(json['thumbnail'] ?? ""),
        contentType = json['contentType'],
        modTime = DateTime.parse(json['modTime']),
        meta = json['meta'] ?? {},
        bodyID = json['bodyID'],
        bodyKey = base64Decode(json['bodyKey'] ?? ""),
        iv = base64Decode(json['iv'] ?? ""),
        deleted = json['deleted'] ?? false,
        downloads = json['downloads'] ?? {},
        cached = json['cached'],
        cachedExpires = DateTime.parse(json['cachedExpires']);

  Map<String, dynamic> toJson() => {
        'name': name,
        'author': author,
        'size': size,
        'hash': base64Encode(hash),
        'zip': zip,
        'tags': tags,
        'thumbnail': base64Encode(thumbnail),
        'contentType': contentType,
        'modTime': modTime.toIso8601String(),
        'meta': meta,
        'bodyID': bodyID,
        'bodyKey': base64Encode(bodyKey),
        'iv': base64Encode(iv),
        'deleted': deleted,
        'downloads': downloads,
        'cached': cached,
        'cachedExpires': cachedExpires.toIso8601String(),
      };
}

class OpenOptions {
  bool forceCreate;
  bool adaptiveSync;
  Duration syncPeriod;

  OpenOptions()
      : forceCreate = false,
        adaptiveSync = false,
        syncPeriod = Duration.zero;

  Map<String, dynamic> toJson() => {
        'forceCreate': forceCreate,
        'adaptiveSync': adaptiveSync,
        'syncPeriod': syncPeriod.inMicroseconds * 1000,
      };
}

class ListOptions {
  String folder = '';
  String name = '';
  String suffix = '';
  String contentType = '';
  int bodyID = 0;
  List<String> tags = [];
  DateTime before = DateTime(0); // Default value for before (Year 2000)
  DateTime after = DateTime(0); // Default value for after (Year 2000)
  int offset = 0;
  int limit = 0;
  bool includeDeleted = false;
  bool prefetch = false;

  Map<String, dynamic> toJson() => {
        'folder': folder,
        'name': name,
        'suffix': suffix,
        'contentType': contentType,
        'bodyID': bodyID,
        'tags': tags,
        //'before': before.toIso8601String(),
        //'after': after.toIso8601String(),
        'offset': offset,
        'limit': limit,
        'includeDeleted': includeDeleted,
        'prefetch': prefetch,
      };
}

class PutOptions {
  bool replace = false;
  int replaceID = 0;
  List<String> tags = [];
  List<int> thumbnail = [];
  bool autoThumbnail = false;
  String contentType = "";
  bool zip = false;
  Map<String, dynamic> meta = {};

  Map<String, dynamic> toJson() => {
        'replace': replace,
        'replaceID': replaceID,
        'tags': tags,
        'thumbnail': thumbnail,
        'autoThumbnail': autoThumbnail,
        'contentType': contentType,
        'zip': zip,
        'meta': meta,
      };
}

class GetOptions {
  String destination = '';
  int bodyID = 0;
  bool noCache = false;
  Duration cacheExpire = Duration.zero;
}

typedef Permission = int;
typedef Users = Map<String, Permission>;

var permissionUser = 1;
var permissionAdmin = 2;
