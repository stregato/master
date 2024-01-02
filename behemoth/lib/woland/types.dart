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

  Identity({this.id = "", this.nick = "", this.email = "", this.private = ""});

  Identity.fromJson(Map<String, dynamic> json)
      : id = json['i'],
        nick = json['n'],
        email = json['e'] ?? "",
        private = json['p'] ?? "",
        avatar = base64Decode(json["a"] ?? "");

  Map<String, dynamic> toJson() => {
        'i': id,
        'n': nick,
        'e': email.isNotEmpty ? email : null,
        'p': private.isNotEmpty ? private : null,
        'a': avatar.isNotEmpty ? base64Encode(avatar) : null,
      };
}

// class Access {
//   String name;
//   int id;
//   String creatorId;
//   String url;

//   Access(this.name, this.id, this.creatorId, this.url);

//   Access.fromJson(Map<String, dynamic> json)
//       : name = json['name'],
//         id = json['id'],
//         creatorId = json['creatorId'],
//         url = json['url'];

//   Map<String, dynamic> toJson() => {
//         'name': name,
//         'id': id,
//         'creatorId': creatorId,
//         'url': url,
//       };
// }

class StoreDesc {
  double readCost;
  double writeCost;

  StoreDesc({this.readCost = 0.0, this.writeCost = 0.0});

  Map<String, dynamic> toJson() => {
        'readCost': readCost,
        'writeCost': writeCost,
      };

  StoreDesc.fromJson(Map<String, dynamic> json)
      : readCost = json['readCost'] ?? 0.0,
        writeCost = json['writeCost'] ?? 0.0;
}

// class Safe {
//   Identity currentUser;
//   String creatorId = "";
//   String name = "";
//   String description = "";
//   StorageDesc storage = StorageDesc();
//   int quota = 0;
//   String quotaGroup = "";

//   Safe.fromJson(Map<String, dynamic> json)
//       : name = json['name'],
//         currentUser = Identity.fromJson(json['currentUser']),
//         creatorId = json['creatorId'],
//         description = json['description'],
//         storage = StorageDesc.fromJson(json['storage']),
//         quota = json['quota'] ?? 0,
//         quotaGroup = json['quotaGroup'] ?? "";

//   Map<String, dynamic> toJson() => {
//         'name': name,
//         'currentUser': currentUser.toJson(),
//         'creatorId': creatorId,
//         'description': description,
//         'storage': storage.toJson(),
//         'quota': quota,
//         'quotaGroup': quotaGroup,
//       };
// }

class Attributes {
  Uint8List hash = Uint8List(0);
  String contentType = '';
  bool zip = false;
  Uint8List thumbnail = Uint8List(0);
  List<String> tags = [];
  Map<String, dynamic> meta = {};

  Attributes();

  Attributes.fromJson(Map<String, dynamic> json)
      : hash = base64Decode(json['ha'] ?? ""),
        contentType = json['co'] ?? "",
        zip = json['zip'] ?? false,
        thumbnail = base64Decode(json['th'] ?? ""),
        tags = dynamicToList(json['ta']),
        meta = json['mt'] ?? {};

  Map<String, dynamic> toJson() => {
        'ha': base64Encode(hash),
        'co': contentType,
        'zi': zip,
        'th': base64Encode(thumbnail),
        'ta': tags,
        'mt': meta,
      };
}

class Header {
  String name = '';
  String creator = '';
  String privateId = '';
  int size = 0;
  DateTime modTime = DateTime(0);
  int fileId = 0;
  Uint8List bodyKey = Uint8List(0);
  Uint8List iv = Uint8List(0);
  Attributes attributes = Attributes();
  bool deleted = false;
  bool uploading = false;
  Map<String, DateTime> downloads = {};
  String cached = '';
  DateTime cachedExpires = DateTime.now();

  Header.fromJson(Map<String, dynamic> json)
      : name = json['na'],
        creator = json['cr'],
        privateId = json['pr'] ?? "",
        size = json['si'],
        modTime = DateTime.parse(json['mo']),
        fileId = json['fi'],
        bodyKey = base64Decode(json['bo'] ?? ""),
        iv = base64Decode(json['iv'] ?? ""),
        attributes = Attributes.fromJson(json['at'] ?? {}),
        deleted = json['de'] ?? false,
        uploading = json['up'] ?? false,
        downloads = (json['do'] ?? {}).map<String, DateTime>(
            (key, value) => MapEntry(key.toString(), DateTime.parse(value))),
        cached = json['ca'] ?? "",
        cachedExpires = DateTime.parse(json['cac']);

  Map<String, dynamic> toJson() => {
        'na': name,
        'cr': creator,
        'pr': privateId,
        'si': size,
        'mo': modTime.toIso8601String(),
        'fi': fileId,
        'bo': base64Encode(bodyKey),
        'iv': base64Encode(iv),
        'at': attributes.toJson(),
        'de': deleted,
        'do': Map.fromEntries(downloads.entries
            .map((e) => MapEntry(e.key, e.value.toIso8601String()))),
        'ca': cached,
        'cac': cachedExpires.toIso8601String(),
      };
}

class CreateOptions {
  bool wipe;
  String description;
  int changeLogWatch;
  int replicaWatch;

  CreateOptions({
    this.wipe = false,
    this.description = '',
    this.changeLogWatch = 0,
    this.replicaWatch = 0,
  });

  Map<String, dynamic> toJson() => {
        'wipe': wipe,
        'description': description,
        'changeLogWatch': changeLogWatch,
        'replicaWatch': replicaWatch,
      };
}

class OpenOptions {
  String initiateSecret;
  bool forceCreate;
  bool adaptiveSync;
  Duration syncPeriod;

  OpenOptions(
      {this.initiateSecret = '',
      this.forceCreate = false,
      this.adaptiveSync = false,
      this.syncPeriod = Duration.zero});

  Map<String, dynamic> toJson() => {
        'initiateSecret': initiateSecret,
        'forceCreate': forceCreate,
        'adaptiveSync': adaptiveSync,
        'syncPeriod': syncPeriod.inMicroseconds * 1000,
      };
}

class SyncOptions {
  String bucket;
  bool replicate;
  bool users;

  SyncOptions({this.bucket = '', this.replicate = false, this.users = false});
  Map<String, dynamic> toJson() => {
        'replicate': replicate,
        'users': users,
        'bucket': bucket,
      };
}

class SyncResult {
  int changes;
  Header? last;

  SyncResult({this.changes = 0, this.last});

  SyncResult.fromJson(Map<String, dynamic> json)
      : changes = json['changes'],
        last = json['last'] != null ? Header.fromJson(json['last']) : null;
}

class ListOptions {
  String name;
  String dir;
  bool noSync;
  bool onlyChanges;
  String prefix;
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
  String orderBy; // modTime, name, size
  bool reverseOrder;

  ListOptions(
      {this.name = '',
      this.dir = '',
      this.noSync = false,
      this.onlyChanges = false,
      this.prefix = '',
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
      this.errorIfNotExist = false,
      this.orderBy = '',
      this.reverseOrder = false});

  Map<String, dynamic> toJson() => {
        'name': name,
        'dir': dir,
        'noSync': noSync,
        'onlyChanges': onlyChanges,
        'prefix': prefix,
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
        'orderBy': orderBy,
        'reverseOrder': reverseOrder,
      };
}

class ListDirsOptions {
  String dir;
  int depth;
  bool errorIfNotExist;

  ListDirsOptions(
      {this.dir = "", this.depth = 0, this.errorIfNotExist = false});

  Map<String, dynamic> toJson() => {
        'dir': dir,
        'depth': depth,
        'errorIfNotExist': errorIfNotExist,
      };
}

class PutOptions {
  bool replace;
  int replaceID;
  bool async;
  List<String> tags;
  List<int> thumbnail;
  int thumbnailWidth;
  bool autoThumbnail;
  String contentType;
  bool zip;
  Map<String, dynamic> meta;
  String source;
  String private;

  PutOptions(
      {this.replace = false,
      this.replaceID = 0,
      this.async = false,
      this.tags = const [],
      this.thumbnail = const [],
      this.thumbnailWidth = 0,
      this.autoThumbnail = false,
      this.contentType = '',
      this.zip = false,
      this.meta = const {},
      this.source = '',
      this.private = ''});

  Map<String, dynamic> toJson() => {
        'replace': replace,
        'replaceID': replaceID,
        'async': async,
        'tags': tags,
        'thumbnail': thumbnail,
        'thumbnailWidth': thumbnailWidth,
        'autoThumbnail': autoThumbnail,
        'contentType': contentType,
        'zip': zip,
        'meta': meta,
        'source': source,
        'private': private,
      };
}

class PatchOptions {
  bool byName;
  bool async;

  PatchOptions({this.byName = false, this.async = false});

  Map<String, dynamic> toJson() => {
        'byName': byName,
        'async': async,
      };

  PatchOptions.fromJson(Map<String, dynamic> json)
      : byName = json['byName'] ?? false,
        async = json['async'] ?? false;
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

class Initiate {
  String secret;
  Identity identity;

  Initiate(this.secret, this.identity);
  Initiate.fromJson(Map<String, dynamic> json)
      : secret = json['secret'],
        identity = Identity.fromJson(json['identity']);

  Map<String, dynamic> toJson() => {
        'secret': secret,
        'identity': identity.toJson(),
      };
}

typedef Permission = int;
typedef Users = Map<String, Permission>;
typedef Initiates = Map<String, String>;

var blocked = 1;
var reader = 2;
var standard = 4;
var admin = 16;
var creator = 32;
