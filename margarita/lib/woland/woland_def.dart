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
  String safeName = "";
  String creatorId = "";
  String aesKey = "";
  List<String> urls = [];

  DecodedToken.fromJson(Map<String, dynamic> json)
      : safeName = json['safeName'],
        aesKey = json['aesKey'] ?? "",
        urls = dynamicToList(json['urls']),
        creatorId = json['creatorId'];

  Map<String, dynamic> toJson() => {
        'safeName': safeName,
        'aesKey': aesKey,
        'urls': urls,
        'creatorId': creatorId,
      };
}

class Safe {
  Identity currentUser;
  String creatorId = "";
  String name = "";
  String description = "";

  Safe.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        currentUser = Identity.fromJson(json['currentUser']),
        creatorId = json['creatorId'],
        description = json['description'];

  Map<String, dynamic> toJson() => {
        'name': name,
        'currentUser': currentUser.toJson(),
        'creatorId': creatorId,
        'description': description,
      };
}

class Attributes {
  Uint8List hash = Uint8List(0);
  String contentType = '';
  bool zip = false;
  Uint8List thumbnail = Uint8List(0);
  List<String> tags = [];
  Map<String, dynamic> extra = {};

  Attributes();

  Attributes.fromJson(Map<String, dynamic> json)
      : hash = base64Decode(json['ha'] ?? ""),
        contentType = json['co'] ?? "",
        zip = json['zip'] ?? false,
        thumbnail = base64Decode(json['th'] ?? ""),
        tags = dynamicToList(json['ta']),
        extra = json['ex'] ?? {};

  Map<String, dynamic> toJson() => {
        'ha': base64Encode(hash),
        'co': contentType,
        'zi': zip,
        'th': base64Encode(thumbnail),
        'ta': tags,
        'ex': extra,
      };
}

class Header {
  String name = '';
  String creator = '';
  int size = 0;
  DateTime modTime = DateTime(0);
  int fileId = 0;
  Uint8List bodyKey = Uint8List(0);
  Uint8List iv = Uint8List(0);
  Attributes attributes = Attributes();
  bool deleted = false;
  Map<String, DateTime> downloads = {};
  String cached = '';
  DateTime cachedExpires = DateTime.now();

  Header.fromJson(Map<String, dynamic> json)
      : name = json['na'],
        creator = json['cr'],
        size = json['si'],
        modTime = DateTime.parse(json['mo']),
        fileId = json['fi'],
        bodyKey = base64Decode(json['bo'] ?? ""),
        iv = base64Decode(json['iv'] ?? ""),
        attributes = Attributes.fromJson(json['at'] ?? {}),
        deleted = json['de'] ?? false,
        downloads = (json['do'] ?? {}).map<String, DateTime>(
            (key, value) => MapEntry(key.toString(), DateTime.parse(value))),
        cached = json['ca'] ?? "",
        cachedExpires = DateTime.parse(json['cac']);

  Map<String, dynamic> toJson() => {
        'na': name,
        'cr': creator,
        'si': size,
        'mo': modTime.toIso8601String(),
        'fi': fileId,
        'bo': base64Encode(bodyKey),
        'iv': base64Encode(iv),
        'at': attributes.toJson(),
        'de': deleted,
        'do': downloads,
        'ca': cached,
        'cac': cachedExpires.toIso8601String(),
      };
}

class CreateOptions {
  bool wipe;
  String description;
  int changeLogWatch;
  int replicaWatch;

  CreateOptions()
      : wipe = false,
        description = "",
        changeLogWatch = 0,
        replicaWatch = 0;

  Map<String, dynamic> toJson() => {
        'wipe': wipe,
        'description': description,
        'changeLogWatch': changeLogWatch,
        'replicaWatch': replicaWatch,
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
  String name;
  int depth;
  String suffix;
  String contentType;
  String creator;
  bool noPrivate;
  String privateId;
  int bodyID;
  List<String> tags;
  DateTime? before;
  DateTime? after;
  DateTime? knownSince;
  int offset;
  int limit;
  bool includeDeleted;
  bool prefetch;
  bool errorIfNotExist;

  ListOptions(
      {this.name = '',
      this.depth = 0,
      this.suffix = '',
      this.contentType = '',
      this.creator = '',
      this.noPrivate = false,
      this.privateId = '',
      this.bodyID = 0,
      this.tags = const [],
      this.before,
      this.after,
      this.knownSince,
      this.offset = 0,
      this.limit = 0,
      this.includeDeleted = false,
      this.prefetch = false,
      this.errorIfNotExist = false});

  Map<String, dynamic> toJson() => {
        'name': name,
        'depth': depth,
        'suffix': suffix,
        'contentType': contentType,
        'creator': creator,
        'noPrivate': noPrivate,
        'privateId': privateId,
        'bodyID': bodyID,
        'tags': tags,
        'before': before?.toUtc().toIso8601String(),
        'after': after?.toUtc().toIso8601String(),
        'knownSince': knownSince?.toUtc().toIso8601String(),
        'offset': offset,
        'limit': limit,
        'includeDeleted': includeDeleted,
        'prefetch': prefetch,
        'errorIfNotExist': errorIfNotExist,
      };
}

class ListDirsOptions {
  int depth;
  bool errorIfNotExist;

  ListDirsOptions({this.depth = 0, this.errorIfNotExist = false});

  Map<String, dynamic> toJson() => {
        'depth': depth,
        'errorIfNotExist': errorIfNotExist,
      };
}

class PutOptions {
  bool replace;
  int replaceID;
  List<String> tags;
  List<int> thumbnail;
  bool autoThumbnail;
  String contentType;
  bool zip;
  Map<String, dynamic> meta;
  String source;

  PutOptions(
      {this.replace = false,
      this.replaceID = 0,
      this.tags = const [],
      this.thumbnail = const [],
      this.autoThumbnail = false,
      this.contentType = '',
      this.zip = false,
      this.meta = const {},
      this.source = ''});

  Map<String, dynamic> toJson() => {
        'replace': replace,
        'replaceID': replaceID,
        'tags': tags,
        'thumbnail': thumbnail,
        'autoThumbnail': autoThumbnail,
        'contentType': contentType,
        'zip': zip,
        'meta': meta,
        'source': source,
      };
}

class GetOptions {
  String destination;
  int fileId;
  bool noCache;
  Duration cacheExpire;

  GetOptions(
      {this.destination = '',
      this.fileId = 0,
      this.noCache = false,
      this.cacheExpire = Duration.zero});

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'fileId': fileId,
        'noCache': noCache,
        'cacheExpire': cacheExpire.inMicroseconds * 1000,
      };
}

class SetUsersOptions {
  bool replaceUsers;
  Duration alignDelay;
  bool syncAlign;

  SetUsersOptions(
      {this.replaceUsers = false,
      this.alignDelay = Duration.zero,
      this.syncAlign = false});

  Map<String, dynamic> toJson() => {
        'replaceUsers': replaceUsers,
        'alignDelay': alignDelay.inMicroseconds * 1000,
        'syncAlign': syncAlign,
      };
}

typedef Permission = int;
typedef Users = Map<String, Permission>;

var permissionRead = 1;
var permissionWrite = 2;
var permissionAdmin = 16;
var permissionSuperAdmin = 32;
