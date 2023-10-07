import 'dart:convert';

import 'dart:typed_data';

import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/woland_def.dart';

var identities = <String, Identity>{};
void clearIdentities() {
  identities = {};
}

Identity getCachedIdentity(String id) {
  return identities.putIfAbsent(id, () {
    try {
      return getIdentity(id);
    } catch (e) {
      var i = Identity();
      i.id = id;
      return i;
    }
  });
}

class Coven {
  String name;
  Map<String, String> rooms;

  Coven(this.name, this.rooms);
  Coven.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        rooms = json['spaces'].map<String, String>((key, value) =>
                MapEntry<String, String>(key.toString(), value.toString()))
            as Map<String, String>;

  Map<String, dynamic> toJson() => {
        'name': name,
        'spaces': rooms,
      };
}

class Profile {
  Identity identity = Identity();
  Map<String, Coven> covens = {};

  Profile();

  Profile.fromJson(Map<String, dynamic> json)
      : identity = Identity.fromJson(json['identity']),
        covens = json['communities'].map<String, Coven>((key, value) =>
                MapEntry<String, Coven>(key.toString(), Coven.fromJson(value)))
            as Map<String, Coven>;

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        'communities': covens,
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
