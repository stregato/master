import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class AddStorage extends StatefulWidget {
  const AddStorage({super.key});

  @override
  State<AddStorage> createState() => _AddStorageState();
}

class Storage {
  String url;
  bool public;

  Storage(this.url, this.public);
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

class _AddStorageState extends State<AddStorage> {
  String storageType = "";
  Args a = Args();

  String getUrl() {
    switch (storageType) {
      case "S3":
        return "s3://${a.host}/${a.bucket}?accessKey=${a.accessKey}&secret=${a.secret}&verbose=${a.verbose}";
      case "SFTP":
        var u = "sftp://";
        if (a.username.isNotEmpty && a.password.isNotEmpty) {
          u += "${a.username}:${a.password}@";
        } else if (a.username.isNotEmpty) {
          u += "${a.username}@";
        }
        u += "${a.host}/${a.path}";
        if (a.key.isNotEmpty) {
          u += "?key=${a.key}";
        }
        return u;
      case "WebDAV":
        var u = a.https ? "davs://" : "dav://";
        if (a.username.isNotEmpty && a.password.isNotEmpty) {
          u += "${a.username}:${a.password}@";
        }
        u += "${a.host}/${a.path}";
        return u;
      case "Folder":
        return "file://${a.path}";
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
      case "Folder":
        return a.path.isNotEmpty;
      default:
        return false;
    }
  }

  Map<String, Widget> getBuilders() {
    return {
      "S3": Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Host'),
            onChanged: (val) => setState(() {
              a.host = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Bucket'),
            onChanged: (val) => setState(() {
              a.bucket = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Access Key'),
            onChanged: (val) => setState(() {
              a.accessKey = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Secret'),
            onChanged: (val) => setState(() {
              a.secret = val;
            }),
          ),
        ],
      ),
      "SFTP": Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Host'),
            onChanged: (val) => setState(() {
              a.host = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Path'),
            onChanged: (val) => setState(() {
              a.path = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Username'),
            onChanged: (val) => setState(() {
              a.username = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Password'),
            onChanged: (val) => setState(() {
              a.password = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Key'),
            onChanged: (val) => setState(() {
              a.key = val;
            }),
          ),
        ],
      ),
      "WebDAV": Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Host'),
            onChanged: (val) => setState(() {
              a.host = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Path'),
            onChanged: (val) => setState(() {
              a.path = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Username'),
            onChanged: (val) => setState(() {
              a.username = val;
            }),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Password'),
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
      "Folder": Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Path'),
            onChanged: (val) => setState(() {
              a.path = val;
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
        fields,
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
                      Navigator.of(context).pop(Storage(getUrl(), a.public_));
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
        title: const Text("Add Storage"),
      ),
      body: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: content),
    );
  }
}
