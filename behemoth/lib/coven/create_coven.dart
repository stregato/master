import 'dart:math';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/coven/addstorage.dart';
import 'package:behemoth/coven/coven.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/woland.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';

class CreateCoven extends StatefulWidget {
  const CreateCoven({super.key});

  @override
  State<CreateCoven> createState() => _CreateCovenState();
}

const urlHint = "Enter a supported URL and click +";
const validSchemas = ["s3", "sftp", "file"];

class _CreateCovenState extends State<CreateCoven> {
  final _formKey = GlobalKey<FormState>();

  String _name = "";
  String _description = "";
  List<String> _urls = [];
  String? _sameStorageAs;
  double _sliderValue = 1;
  bool _wipe = false;

  bool _validConfig() {
    return _name.isNotEmpty && _urls.isNotEmpty;
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

  @override
  Widget build(BuildContext context) {
    var profile = Profile.current();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Coven"),
      ),
      body: Container(
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
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    return null;
                  },
                  onChanged: (val) => setState(() => _name = val),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    return null;
                  },
                  onChanged: (val) => setState(() => _description = val),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      "Storages",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (context) => const AddStorage()))
                            .then((value) {
                          if (value is Storage) {
                            setState(() {
                              _urls.add(value.url);
                            });
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                    )
                  ],
                ),
                ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: _urls.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.share),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _urls.removeAt(index);
                          });
                        }),
                    title: Text(_urls[index]),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    const Text(
                      "Same storage as",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
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
                          var access = c?.rooms["lounge"]!;
                          var d = decodeAccess(profile.identity, access!);

                          setState(() {
                            _urls = d.urls;
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
                const Text(
                  "Limit storage",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
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
                    const Text(
                      "Wipe (danger)",
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    const Spacer(),
                    Switch(
                      value: _wipe,
                      onChanged: (value) {
                        setState(() {
                          _wipe = value;
                        });
                        if (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Danger: wipe will delete all data in the community'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _validConfig()
                        ? () async {
                            await progressDialog(
                                context,
                                "opening portal, please wait",
                                Coven.create(
                                    _name,
                                    _urls,
                                    CreateOptions(
                                        wipe: _wipe,
                                        description: _description,
                                        quota: _mapSliderToValue(_sliderValue),
                                        quotaGroup: "$_name/")),
                                successMessage:
                                    "Congrats! You successfully created $_name",
                                errorMessage: "Creation failed");
                            // ignore: use_build_context_synchronously
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          }
                        : null,
                    child: const Text('Create'),
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
