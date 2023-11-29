import 'dart:convert';

import 'dart:typed_data';

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

String prettyName(String safeName) {
  var lastSlash = safeName.lastIndexOf('/');
  var covenName = safeName.substring(0, lastSlash);
  var roomName = safeName.substring(lastSlash + 1);
  return "$roomName@$covenName";
}

class Coven {
  Identity identity;
  String name;
  Map<String, String> rooms;
  static Map<String, Safe> safes = {};
  static Map<String, DateTime> safesAccessed = {};

  static Future<Coven> join(String access) async {
    var p = Profile.current();
    var d = decodeAccess(p.identity, access);
    var name = d.safeName;
    var ps = covenAndRoom(name);
    var covenName = ps[0];
    var roomName = ps[1];
    var coven =
        p.covens.putIfAbsent(covenName, () => Coven(p.identity, covenName, {}));
    coven.rooms[roomName] = access;
    p.save();
    Safe.open(p.identity, access, OpenOptions());
    return coven;
  }

  static Future create(
      String name, List<String> urls, CreateOptions options) async {
    var p = Profile.current();
    var token =
        encodeAccess(p.identity.id, "$name/lounge", p.identity.id, urls);
    await Safe.create(p.identity, token, {}, options);
    p.covens[name] = Coven(p.identity, name, {"lounge": token});
    p.save();
  }

  Coven(this.identity, this.name, this.rooms);
  Coven.fromJson(this.identity, Map<String, dynamic> json)
      : name = json['name'],
        rooms = json['rooms'].map<String, String>((key, value) =>
                MapEntry<String, String>(key.toString(), value.toString()))
            as Map<String, String>;

  Map<String, dynamic> toJson() => {
        'name': name,
        'rooms': rooms,
      };

  Future<Safe> getLounge() async {
    return getSafe("lounge");
  }

  Safe? getLoungeSync() {
    return getSafeSync("lounge");
  }

  Future<Safe> getSafe(String roomName) async {
    var safe = safes["$name/$roomName"];
    if (safe != null) {
      return safe;
    }
    var access = rooms[roomName];
    if (access == null) {
      throw Exception("no access to $roomName");
    }
    safe = await Safe.open(identity, access, OpenOptions());
    safes["$name/$roomName"] = safe;
    safesAccessed["$name/$roomName"] = DateTime.now();
    return safe;
  }

  Safe? getSafeSync(String roomName) {
    var safe = safes["$name/$roomName"];
    if (safe != null) {
      safesAccessed["$name/$roomName"] = DateTime.now();
    }
    return safe;
  }

  void closeSafe(String roomName) {
    var safe = safes["$name/$roomName"];
    if (safe != null) {
      safe.close();
      safes.remove(roomName);
    }
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

  static Profile current() {
    var sib = getConfig("behemoth", "profile");
    if (sib.missing) {
      throw Exception("no profile");
    }

    return Profile.fromJson(jsonDecode(utf8.decode(sib.b)));
  }

  static bool hasProfile() {
    var sib = getConfig("behemoth", "profile");
    if (!sib.missing) Profile.fromJson(jsonDecode(utf8.decode(sib.b)));
    return !sib.missing;
  }

  save() {
    setConfig("behemoth", "profile",
        SIB.fromBytes(Uint8List.fromList(utf8.encode(jsonEncode(this)))));
  }
}
