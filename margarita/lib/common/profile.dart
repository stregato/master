import 'dart:convert';

import 'dart:typed_data';

import 'package:margarita/woland/woland.dart';
import 'package:margarita/woland/woland_def.dart';

var profiles = <Profile>[];
var currentProfile = Profile();
var identities = <String, Identity>{};

void clearProfiles() {
  profiles = [];
  currentProfile = Profile();
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

class Profile {
  Identity identity = Identity();
  Map<String, String> portals = {};

  Profile();

  Profile.fromJson(Map<String, dynamic> json)
      : identity = Identity.fromJson(json['identity']),
        portals = ((json['portals'] ?? {}) as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value.toString()));

  Map<String, dynamic> toJson() => {
        'identity': identity.toJson(),
        'portals': portals,
      };
}

List<Profile> readProfiles(Uint8List data) {
  var json = jsonDecode(utf8.decode(data));
  return dynamicToList(json).map((e) => Profile.fromJson(e)).toList();
}

Uint8List writeProfiles(List<Profile> profiles) {
  var json = jsonEncode(profiles.map((e) => e.toJson()).toList());
  return Uint8List.fromList(utf8.encode(json));
}
