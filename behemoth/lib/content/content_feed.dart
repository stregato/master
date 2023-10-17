import 'dart:io';
import 'dart:typed_data';

import 'package:behemoth/common/image.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';

class ContentFeed extends StatefulWidget {
  const ContentFeed({super.key});

  @override
  State<ContentFeed> createState() => _ContentFeedState();
}

class _ContentFeedState extends State<ContentFeed> {
  int _start = 0;
  int _end = 0;
  List<Header> _headers = [];
  List<Widget> _items = [];
  late Safe _safe;
  String _folder = "";

  Future<Widget> _getImageWidget(Header h) async {
    if (h.attributes.thumbnail.isNotEmpty) {
      return Image.memory(
        h.attributes.thumbnail,
        fit: BoxFit.cover,
      );
    }

    var localpath = join(documentsFolder, _safe.name, _folder, h.name);
    var localfile = File(localpath);
    if (!localfile.existsSync()) {
      await _safe.getFile(h.name, localpath, GetOptions());
    }

    return Image.file(localfile, fit: BoxFit.cover);
  }

  Future<Widget?> _getWidget(Header h) async {
    var mime = h.attributes.contentType;
    if (mime.startsWith("image/")) {
      return _getImageWidget(h);
    }
    return null;
  }

  Future _read() async {
    _headers = await _safe.listFiles("content/$_folder", ListOptions());
    var items = <Widget>[];
    for (var h in _headers) {
      Widget? w = await _getWidget(h);
      if (w != null) {
        items.add(w);
      }
    }
    setState(() {
      _items = items;
    });
  }

  void _addImage() async {
    XFile? xfile = await pickImage();
    if (xfile == null) {
      return;
    }
    final bytes = await xfile.readAsBytes();
//    final image = await decodeImageFromList(bytes);

    var name = "content/$_folder/${basename(xfile.name)}";
    var options = PutOptions(
        autoThumbnail: true, contentType: lookupMimeType(xfile.path) ?? '');
    var header = await _safe.putFile(name, xfile.path, options);
    setState(() {
      _items.add(Image.memory(bytes, fit: BoxFit.cover));
      _headers.add(header);
    });
  }

  void _handleAttachmentPressed(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _addImage();
                  },
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.movie),
                  title: const Text('Video'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_folder.isEmpty) {
      var args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _safe = args["safe"] as Safe;
      _folder = args["folder"] as String;
      _read();
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_folder.substring(0, _folder.length - 5),
            style: const TextStyle(fontSize: 18)),
        trailingActions: [
          const NewsIcon(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.exit_to_app)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 3.0,
                  margin: const EdgeInsets.all(8.0),
                  child: _items[index],
                );
              },
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () => _handleAttachmentPressed(context),
                  child: const Text('Add'),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
