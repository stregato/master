import 'dart:math';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/coven/add_storage.dart';
import 'package:behemoth/woland/woland.dart';
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
  String _url = "";
  String? _sameStorageAs;
  double _sliderValue = 1;
  bool _wipe = false;

  bool _validConfig() {
    return _name.isNotEmpty && _url.isNotEmpty;
  }

  int _mapSliderToValue(double sliderValue) {
    if (sliderValue == 1) {
      return 0;
    }
    // Map the slider's logarithmic value (0-1) to the desired byte range
    const double minValue = 1e7; // 10 MB in bytes
    const double maxValue = 1.1e11; // 100 GB in bytes
    var value = minValue * pow(maxValue / minValue, sliderValue).truncate();
    return value < 1e9
        ? value.toInt()
        : ((value / 1e9).truncate() * 1e9).toInt();
  }

  String _getDisplayValue(int value) {
    if (value == 0) {
      return 'Unlimited';
    } else if (value >= 1e9) {
      // Display in GB if greater than or equal to 1 GB
      return '${(value / 1e9).toStringAsFixed(2)} GB';
    } else {
      // Display in MB if less than 1 GB
      return '${(value / 1e6).toStringAsFixed(2)} MB';
    }
  }

  void _createCoven(BuildContext context) async {
    await progressDialog(
        context,
        "opening portal, please wait",
        Coven.create(
            _name,
            _url,
            CreateOptions(
                wipe: _wipe,
                description: _description,
                quota: _mapSliderToValue(_sliderValue),
                quotaGroup: "$_name/")),
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
                      "Storage",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const Spacer(),
                    PlatformIconButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (context) => const AddStorage()))
                            .then((value) {
                          if (value is Storage) {
                            setState(() {
                              _url = value.url;
                            });
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                    )
                  ],
                ),
                Text(_url),
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
                          var access = c?.access;
                          var d = decodeAccess(profile.identity, access!);

                          setState(() {
                            _url = d.url;
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
                PlatformText(
                  "Limit storage",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_getDisplayValue(_mapSliderToValue(_sliderValue))),
                    Slider(
                      min: 0.0,
                      max: 1.0,
                      value: _sliderValue,
                      onChanged: (value) {
                        setState(() {
                          _sliderValue = value;
                        });
                      },
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
