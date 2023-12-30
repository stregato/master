import 'dart:math';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/coven/add_store.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class CreateCoven extends StatefulWidget {
  final void Function()? onComplete;
  const CreateCoven({this.onComplete, super.key});

  @override
  State<CreateCoven> createState() => _CreateCovenState();
}

const urlHint = "Enter a supported URL and click +";
const validSchemas = ["s3", "sftp", "file"];

class _CreateCovenState extends State<CreateCoven> {
  final _formKey = GlobalKey<FormState>();

  String _name = "";
  String _description = "";
  StoreConfig _storeConfig = StoreConfig("", primary: true);
  String? _sameStorageAs;
  bool _wipe = false;

  bool _validConfig() {
    return _name.isNotEmpty && _storeConfig.url.isNotEmpty;
  }

  void _createCoven(BuildContext context) async {
    await progressDialog(
        context,
        "opening portal, please wait",
        Coven.create(_name, _storeConfig,
            CreateOptions(wipe: _wipe, description: _description)),
        successMessage: "Congrats! You successfully created $_name",
        errorMessage: "Creation failed");
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    var profile = Profile.current;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Builder(
          builder: (context) => Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    "Enter a name and at least a storage, i.e. sftp or s3"),
                PlatformTextFormField(
                  material: (_, __) => MaterialTextFormFieldData(
                    decoration: const InputDecoration(labelText: 'Name'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  cupertino: (_, __) => CupertinoTextFormFieldData(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 0,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    placeholder: 'Name',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-z 0-9]"))
                  ],
                  validator: (value) {
                    return null;
                  },
                  onChanged: (val) => setState(() => _name = val),
                ),
                PlatformTextFormField(
                  material: (_, __) => MaterialTextFormFieldData(
                    decoration: const InputDecoration(labelText: 'Description'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  cupertino: (_, __) => CupertinoTextFormFieldData(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 0,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    placeholder: 'Description',
                  ),
                  validator: (value) {
                    return null;
                  },
                  onChanged: (val) => setState(() => _description = val),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    PlatformText(
                      "Store",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    PlatformElevatedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (context) => const AddStore()))
                            .then((value) {
                          if (value is StoreConfig) {
                            value.primary = true;
                            setState(() {
                              _storeConfig = value;
                            });
                          }
                        });
                      },
                      child: PlatformText('Set'),
                    ),
                  ],
                ),
                Text(_storeConfig.name.isNotEmpty
                    ? _storeConfig.name
                    : "${_storeConfig.url.substring(0, min(32, _storeConfig.url.length))}..."),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    PlatformText(
                      "Same storage as",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: // Replace with your label
                          DropdownButton<String>(
                        value: _sameStorageAs,
                        items: profile.covens.keys
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (name) {
                          var c = profile.covens[name];
                          setState(() {
                            _storeConfig = c?.storeConfig ??
                                StoreConfig("", primary: true);
                            _sameStorageAs = name;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    PlatformText(
                      "Wipe (danger)",
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    const Spacer(),
                    Switch(
                      value: _wipe,
                      onChanged: (value) {
                        setState(() {
                          _wipe = value;
                        });
                        if (value) {
                          showPlatformSnackbar(context,
                              'Danger: wipe will delete all data in the community',
                              backgroundColor: Colors.red);
                        }
                      },
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: PlatformElevatedButton(
                    onPressed:
                        _validConfig() ? () => _createCoven(context) : null,
                    child: PlatformText('Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
