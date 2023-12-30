import 'dart:math';

import 'package:behemoth/common/profile.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class AddStore extends StatefulWidget {
  const AddStore({super.key});

  @override
  State<AddStore> createState() => _AddStoreState();
}

class Args {
  String url = "";
  String host = "";
  String path = "";
  String username = "";
  String password = "";
  String key = "";
  String bucket = "";
  String accessKey = "";
  String secret = "";
  bool public_ = true;
  bool https = true;
  int verbose = 0;
}

class _AddStoreState extends State<AddStore> {
  String storageType = "";
  Args a = Args();

  final StoreConfig _storeConfig = StoreConfig("");
  double _sliderValue = 1;

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

  String getUrl() {
    switch (storageType) {
      case "S3":
        if (a.verbose == 0) {
          return "s3://${a.host}/${a.bucket}?a=${a.accessKey}&s=${a.secret}";
        } else {
          return "s3://${a.host}/${a.bucket}?a=${a.accessKey}&s=${a.secret}&v=${a.verbose}";
        }
      case "SFTP":
        var u = "sftp://";
        if (a.username.isNotEmpty && a.password.isNotEmpty) {
          u += "${a.username}:${a.password}@";
        } else if (a.username.isNotEmpty) {
          u += "${a.username}@";
        }
        u += "${a.host}/${a.path}";
        if (a.key.isNotEmpty) {
          u += "?k=${a.key}";
        }
        return u;
      case "WebDAV":
        var u = a.https ? "davs://" : "dav://";
        if (a.username.isNotEmpty && a.password.isNotEmpty) {
          u += "${a.username}:${a.password}@";
        }
        u += "${a.host}/${a.path}";
        return u;
      case "URL":
        return a.url;
      default:
        return "";
    }
  }

  bool valid() {
    switch (storageType) {
      case "S3":
        return a.host.isNotEmpty &&
            a.accessKey.isNotEmpty &&
            a.secret.isNotEmpty &&
            a.bucket.isNotEmpty;
      case "SFTP":
        return a.host.isNotEmpty;
      case "WebDAV":
        return a.host.isNotEmpty;
      case "URL":
        return a.url.isNotEmpty;
      default:
        return false;
    }
  }

  Map<String, Widget> getBuilders() {
    return {
      "S3": Column(
        children: [
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Host',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Host',
            ),
            onChanged: (val) => setState(() {
              a.host = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Bucket',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Bucket',
            ),
            onChanged: (val) => setState(() {
              a.bucket = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Access Key',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Access Key',
            ),
            onChanged: (val) => setState(() {
              a.accessKey = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Secret',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Secret',
            ),
            onChanged: (val) => setState(() {
              a.secret = val;
            }),
          ),
        ],
      ),
      "SFTP": Column(
        children: [
          PlatformTextFormField(
            material: (_, __) => MaterialTextFormFieldData(
              decoration: const InputDecoration(
                labelText: 'Host',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFormFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Host',
            ),
            onChanged: (val) => setState(() {
              a.host = val;
            }),
          ),
          PlatformTextFormField(
            material: (_, __) => MaterialTextFormFieldData(
              decoration: const InputDecoration(
                labelText: 'Path',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFormFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Path',
            ),
            onChanged: (val) => setState(() {
              a.path = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Username',
            ),
            onChanged: (val) => setState(() {
              a.username = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Password',
            ),
            onChanged: (val) => setState(() {
              a.password = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Key',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Key',
            ),
            onChanged: (val) => setState(() {
              a.key = val;
            }),
          ),
        ],
      ),
      "WebDAV": Column(
        children: [
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Host',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Host',
            ),
            onChanged: (val) => setState(() {
              a.host = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Path',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Path',
            ),
            onChanged: (val) => setState(() {
              a.path = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Username',
            ),
            onChanged: (val) => setState(() {
              a.username = val;
            }),
          ),
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Password',
            ),
            onChanged: (val) => setState(() {
              a.password = val;
            }),
          ),
          CheckboxListTile(
            title: const Text('Use HTTPS'),
            value: a.https,
            onChanged: (val) => setState(() {
              a.https = val!;
            }),
          ),
        ],
      ),
      "URL": Column(
        children: [
          PlatformTextField(
            material: (_, __) => MaterialTextFieldData(
              decoration: const InputDecoration(
                labelText: 'URL',
              ),
            ),
            cupertino: (_, __) => CupertinoTextFieldData(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              placeholder: 'Full url',
            ),
            onChanged: (val) => setState(() {
              a.url = val;
            }),
          ),
        ],
      )
    };
  }

  @override
  Widget build(BuildContext context) {
    var builders = getBuilders();
    Widget content;

    if (storageType.isEmpty) {
      content = Column(
        children: [
          ListView.builder(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            itemCount: builders.keys.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(builders.keys.elementAt(index)),
              onTap: () => setState(() {
                storageType = builders.keys.elementAt(index);
              }),
            ),
          ),
          ButtonBar(
            children: [
              PlatformElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              )
            ],
          )
        ],
      );
    } else {
      var fields = builders[storageType]!;
      content = Column(children: [
        PlatformTextFormField(
          material: (_, __) => MaterialTextFormFieldData(
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
          ),
          cupertino: (_, __) => CupertinoTextFormFieldData(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4.0),
            ),
            placeholder: 'Name',
          ),
          onChanged: (val) => setState(() {
            _storeConfig.name = val;
          }),
        ),
        fields,
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
        ButtonBar(children: [
          PlatformElevatedButton(
            onPressed: valid()
                ? () => setState(() {
                      storageType = "";
                    })
                : null,
            child: const Text("Test"),
          ),
          PlatformElevatedButton(
            onPressed: valid()
                ? () => setState(() {
                      _storeConfig.creatorid = Profile.current.identity.id;
                      _storeConfig.url = getUrl();
                      _storeConfig.quota = _mapSliderToValue(_sliderValue);

                      Navigator.of(context).pop(_storeConfig);
                    })
                : null,
            child: const Text("Add"),
          ),
          PlatformElevatedButton(
            onPressed: () => setState(() {
              storageType = "";
              a = Args();
            }),
            child: const Text("Back"),
          )
        ])
      ]);
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text("Add Store"),
      ),
      body: SafeArea(
        child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: content),
      ),
    );
  }
}
