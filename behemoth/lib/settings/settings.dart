import 'dart:convert';
import 'dart:io';

//import 'package:file_selector/file_selector.dart';
import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/copy_field.dart';
import 'package:behemoth/common/image.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:behemoth/common/file_access.dart' as fa;

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static String _logLevel = "Error";

  int _fullReset = 3;
  Uint8List _avatar = Uint8List(0);

  _selectAvatar() async {
    var xfiles = await pickImage(ImageSource.gallery);
    if (xfiles.isEmpty) return;

    var bytes = await xfiles[0].readAsBytes();
    setState(() {
      _avatar = bytes;
    });
  }

  Profile? _getProfile(fa.FileSelection fileSelection) {
    try {
      var file = File(fileSelection.path);
      var source = file.readAsStringSync();

      return Profile.fromJson(jsonDecode(source));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(14)),
    );

    final logLevels = {
      "Fatal": 1,
      "Error": 2,
      "Info": 4,
      "Debug": 5,
      "Trace": 6,
    };

    var profile = Profile.hasProfile() ? Profile.current : Profile();
    var currentUser = profile.identity;
    var nick = TextEditingController(text: profile.identity.nick);
    var email = TextEditingController(text: profile.identity.email);
    if (_avatar.isEmpty) {
      _avatar = currentUser.avatar;
    }
    var link = "https://behemoth.rocks/p/${currentUser.private}";

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text("Settings"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(children: [
                      PlatformTextFormField(
                        material: (context, platform) {
                          return MaterialTextFormFieldData(
                            decoration:
                                const InputDecoration(labelText: 'Your nick'),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          );
                        },
                        cupertino: (context, platform) {
                          return CupertinoTextFormFieldData(
                            placeholder: 'Your nick',
                          );
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: nick,
                      ),
                      PlatformTextFormField(
                        material: (context, platform) {
                          return MaterialTextFormFieldData(
                            decoration:
                                const InputDecoration(labelText: 'Your email'),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          );
                        },
                        cupertino: (context, platform) {
                          return CupertinoTextFormFieldData(
                            placeholder: 'Your email',
                          );
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: email,
                      ),
                    ]),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  InkWell(
                    onTap: _selectAvatar,
                    child: Image.memory(
                      _avatar,
                      width: 128,
                    ),
                  )
                ],
              ),
              ElevatedButton.icon(
                  style: buttonStyle,
                  label: const Text("Save"),
                  icon: const Icon(Icons.save),
                  onPressed: () {
                    currentUser.avatar = _avatar;
                    currentUser.nick = nick.text;
                    currentUser.email = email.text;
                    setIdentity(currentUser);
                  }),
              const SizedBox(height: 20),
              const Text("Danger Zone",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: buttonStyle,
                      label: const Text('Export Profile'),
                      icon: const Icon(Icons.download),
                      onPressed: () {
                        var profileAsJson = jsonEncode(profile.toJson());
                        if (isMobile) {
                          Share.share(profileAsJson,
                              subject: "Profile from Behemoth");
                        } else {
                          var file = File(path.join(
                              downloadFolder, "behemoth-profile.json"));
                          file.writeAsString(profileAsJson);
                          showPlatformSnackbar(
                              context, "Profile saved to $file",
                              backgroundColor: Colors.green);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: buttonStyle,
                      label: const Text('Import Profile'),
                      icon: const Icon(Icons.upload),
                      onPressed: () async {
                        var selection = await fa.getFile(context);
                        if (selection.valid && mounted) {
                          var profile = _getProfile(selection);
                          if (profile == null) {
                            showPlatformSnackbar(
                                context, "Invalid profile file",
                                backgroundColor: Colors.red);
                            return;
                          } else {
                            Navigator.pushNamed(
                                context, "/settings/import_profile",
                                arguments: profile);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CopyField("Your Private Key", link),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                  style: buttonStyle,
                  label: const Text("Update Private Key"),
                  icon: const Icon(Icons.key),
                  onPressed: () {
                    Navigator.pushNamed(context, "/settings/update_key",
                        arguments: currentUser);
                  }),
              const SizedBox(height: 20),
              DropdownButton(
                  value: _logLevel,
                  items: logLevels.keys
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (e) {
                    setState(() {
                      _logLevel = e!;
                      setLogLevel(logLevels[_logLevel] ?? 1);
                    });
                  }),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: buttonStyle,
                      label: const Text('Copy Logs'),
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        try {
                          var logs = getLogs();
                          var content = logs.join("\n");
                          if (content.length > 64000) {
                            content = content.substring(content.length - 64000);
                          }
                          if (Platform.isAndroid || Platform.isIOS) {
                            Share.share(content, subject: "Logs from Caspian");
                          } else {
                            Clipboard.setData(ClipboardData(text: content))
                                .then((_) {
                              showPlatformSnackbar(
                                  context, "Copied to clipboard");
                            });
                          }
                        } catch (e) {
                          showPlatformSnackbar(context, "Cannot dump: $e",
                              backgroundColor: Colors.red);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: buttonStyle,
                      label: const Text('Download Logs'),
                      icon: const Icon(Icons.download_for_offline),
                      onPressed: () {
                        try {
                          var logs = getLogs();
                          var content = logs.join("\n");

                          if (Platform.isAndroid || Platform.isIOS) {
                            var file = XFile.fromData(
                                Uint8List.fromList(utf8.encode(content)),
                                mimeType: "text/plain",
                                name: "woland.log");
                            Share.shareXFiles([file],
                                subject: "Dump from Caspian");
                          } else {
                            var file = path.join(downloadFolder, "woland.log");
                            File(file).writeAsString(content);
                            showPlatformSnackbar(
                                context, "Logs saved to $file");
                          }
                        } catch (e) {
                          showPlatformSnackbar(context, "Cannot dump: $e",
                              backgroundColor: Colors.red);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              ElevatedButton.icon(
                  style: buttonStyle,
                  label: Text("Factory Reset (click $_fullReset times)"),
                  icon: const Icon(Icons.restore),
                  onPressed: () => setState(() {
                        if (_fullReset == 1) {
                          clearIdentities();
                          factoryReset();
                          start("$applicationFolder/woland.db",
                              applicationFolder);
                          _fullReset = 5;
                          showPlatformSnackbar(
                              context, "Factory Reset completed!",
                              backgroundColor: Colors.green);
                          Navigator.pushReplacementNamed(context, "/setup");
                        } else {
                          _fullReset--;
                          showPlatformSnackbar(
                              context, "$_fullReset clicks to factory reset!",
                              backgroundColor: Colors.red);
                        }
                      })),
            ],
          ),
        ),
        // bottomNavigationBar: const NewsNavigationBar(null),
      ),
    );
  }
}
