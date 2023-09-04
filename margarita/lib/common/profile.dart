import 'dart:convert';

import 'dart:typed_data';

import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';

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

class Community {
  String name;
  Map<String, String> spaces;

  Community(this.name, this.spaces);
  Community.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        spaces = json['spaces'].map<String, String>((key, value) =>
                MapEntry<String, String>(key.toString(), value.toString()))
            as Map<String, String>;

  Map<String, dynamic> toJson() => {
        'name': name,
        'spaces': spaces,
      };
}

class Profile {
  Identity identity = Identity();
  Map<String, Community> communities = {};

  Profile();

  Profile.fromJson(Map<String, dynamic> json)
      : identity = Identity.fromJson(json['identity']),
        communities = json['communities'].map<String, Community>((key, value) =>
                MapEntry<String, Community>(
                    key.toString(), Community.fromJson(value)))
            as Map<String, Community>;

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        'communities': communities,
      };

  static Profile current() {
    var sib = getConfig("margarita", "profile");
    if (sib.missing) {
      throw Exception("no profile");
    }

    return Profile.fromJson(jsonDecode(utf8.decode(sib.b)));
  }

  static bool hasProfile() {
    var sib = getConfig("margarita", "profile");
    if (!sib.missing) Profile.fromJson(jsonDecode(utf8.decode(sib.b)));
    return !sib.missing;
  }

  save() {
    setConfig("margarita", "profile",
        SIB.fromBytes(Uint8List.fromList(utf8.encode(jsonEncode(this)))));
  }
}
