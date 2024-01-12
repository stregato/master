import 'dart:convert';

import 'dart:typed_data';

import 'package:behemoth/coven/cockpit.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';

var identities = <String, Identity>{};
void clearIdentities() {
  identities = {};
}

Identity getCachedIdentity(String id) {
  try {
    return identities.putIfAbsent(id, () => getIdentity(id));
  } catch (e) {
    return Identity(id: id, nick: "unknown");
  }
}

List<String> covenAndRoom(String safeName) {
  var lastSlash = safeName.lastIndexOf('/');
  return [safeName.substring(0, lastSlash), safeName.substring(lastSlash + 1)];
}

class Coven {
  Identity identity;
  String name;
  StoreConfig storeConfig = StoreConfig("");
  String creatorId = "";
  String secret = "";
  Set<String> rooms;
  Set<String> federated = {};
  Safe? _safe;
  static Map<String, Coven> opened = {};
  static Map<String, DateTime> safesAccessed = {};

  bool get isOpen {
    return _safe != null;
  }

  static Future<Coven> join(
      String name, String url, String creatorId, String secret) async {
    var p = Profile.current;

    try {
      await Safe.open(p.identity, name, url, creatorId,
          OpenOptions(initiateSecret: secret));
    } catch (e) {
      // ignore
    }
    var storeConfig = StoreConfig(url, creatorid: creatorId);
    var coven = p.covens.putIfAbsent(name,
        () => Coven(p.identity, name, storeConfig, creatorId, secret, {}));
    p.save();
    return coven;
  }

  static Future create(
      String name, StoreConfig storeConfig, CreateOptions options) async {
    var p = Profile.current;

    var safe = await Safe.create(p.identity, name, storeConfig, {}, options);
    await safe.putBytes("rooms/.list", "lounge", Uint8List(0), PutOptions());
    safe.close();

    var coven =
        Coven(p.identity, name, storeConfig, p.identity.id, "0000", {"lounge"});
    p.update(coven);
  }

  Coven(this.identity, this.name, this.storeConfig, this.creatorId, this.secret,
      this.rooms);
  Coven.fromJson(this.identity, Map<String, dynamic> json)
      : name = json['name'],
        storeConfig = StoreConfig.fromJson(json['storeConfig']),
        creatorId = json['creatorId'],
        rooms = json['rooms'].map<String>((v) => v as String).toList().toSet();

  Map<String, dynamic> toJson() => {
        'name': name,
        'storeConfig': storeConfig.toJson(),
        'creatorId': creatorId,
        'rooms': rooms.toList(),
      };

  Future<Safe> open() async {
    if (_safe != null) {
      return _safe!;
    }
    _safe = await Safe.open(identity, name, storeConfig.url, creatorId,
        OpenOptions(initiateSecret: secret));
    opened[name] = this;
    safesAccessed[name] = DateTime.now();
    Cockpit.openCoven(this);

    for (var st in _safe!.storeConfigs) {
      if (st.url == storeConfig.url &&
          (st.creatorid != storeConfig.creatorid ||
              st.name != storeConfig.name ||
              st.quota != storeConfig.quota)) {
        storeConfig = st;
        Profile.current.update(this);
        break;
      }
    }

    return _safe!;
  }

  Safe get safe {
    if (_safe == null) {
      throw Exception("coven $name not open");
    }

    safesAccessed[name] = DateTime.now();
    return _safe!;
  }

  void close() {
    opened.remove(name);
    safe.close();
    Cockpit.closeCoven(this);
  }

  Future<void> createRoom(String name, List<String> users) async {
    await safe.putBytes("rooms/.list", name, Uint8List(0), PutOptions());

    for (var user in users) {
      safe.putBytes("rooms/.invites/$user", name, Uint8List(0), PutOptions());
    }

    rooms.add(name);
    Profile.current.update(this);
    Cockpit.updateRoom(this, name, true);
  }

  void addRoom(String name) async {
    rooms.add(name);
    Profile.current.update(this);
    Cockpit.updateRoom(this, name, true);
  }
}

class Profile {
  Identity identity = Identity();
  Map<String, Coven> covens = {};

  Profile();

  Profile.fromJson(Map<String, dynamic> json)
      : identity = Identity.fromJson(json['identity']) {
    covens = json['covens'].map<String, Coven>((key, value) =>
            MapEntry<String, Coven>(
                key.toString(), Coven.fromJson(identity, value)))
        as Map<String, Coven>;
  }

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        'covens': covens,
      };

  static Profile? _current;

  static Profile get current {
    if (_current != null) {
      return _current!;
    }

    var sib = getConfig("behemoth", "profile");
    if (sib.missing) {
      throw Exception("no profile");
    }

    _current = Profile.fromJson(jsonDecode(utf8.decode(sib.b)));
    return _current!;
  }

  static bool hasProfile() {
    var sib = getConfig("behemoth", "profile");
    if (!sib.missing) Profile.fromJson(jsonDecode(utf8.decode(sib.b)));
    return !sib.missing;
  }

  void update(Coven coven) {
    covens[coven.name] = coven;
    save();
  }

  save() {
    _current = this;
    setConfig("behemoth", "profile",
        SIB.fromBytes(Uint8List.fromList(utf8.encode(jsonEncode(this)))));
  }
}
