import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/image.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/news_icon.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';

class ContentFeed extends StatefulWidget {
  const ContentFeed({super.key});

  @override
  State<ContentFeed> createState() => _ContentFeedState();
}

class _ContentFeedState extends State<ContentFeed> {
  int _offset = 0;
  int _end = 0;
  List<Header> _headers = [];
  late Safe _safe;
  String _folder = "";
  final Map<int, Widget> _cache = {};
  List<Widget> _items = [];
  final List<Player> _players = [];

  @override
  void dispose() {
    for (var p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  Future<Widget> _getImageWidget(Header h) async {
    if (h.attributes.thumbnail.isNotEmpty) {
      return Image.memory(
        h.attributes.thumbnail,
        fit: BoxFit.cover,
      );
    }

    var localpath =
        join(documentsFolder, _safe.name, _folder, basename(h.name));
    var localfile = File(localpath);
    if (!localfile.existsSync()) {
      await _safe.getFile(h.name, localpath, GetOptions());
    }

    return Image.file(localfile, fit: BoxFit.cover);
  }

  Future<Widget> _getVideoWidget(
    Header h,
  ) async {
    var localpath =
        join(documentsFolder, _safe.name, _folder, basename(h.name));
    var localfile = File(localpath);
    if (!localfile.existsSync()) {
      await _safe.getFile(h.name, localpath, GetOptions());
    }

    var player = Player();
    _players.add(player);
    var controller = VideoController(player);
    player.open(Media(localpath), play: false);
    return Video(controller: controller);
  }

  Future<Widget> _getWidget(Header h) async {
    var mime = h.attributes.contentType;
    if (mime.startsWith("image/")) {
      return _getImageWidget(h);
    } else if (mime.startsWith("video/")) {
      return _getVideoWidget(h);
    }
    return Container();
  }

  Future _read() async {
    _headers = await _safe.listFiles(
        "content/$_folder",
        ListOptions(
          reverseOrder: true,
          orderBy: 'modTime',
          limit: 5,
          offset: _offset,
        ));
    var items = <Widget>[];
    var updated = false;
    for (var h in _headers) {
      var w = _cache[h.fileId];
      if (w == null) {
        updated = true;
        w = await _getWidget(h);
        _cache[h.fileId] = w;
      }
      items.add(w);
    }
    if (updated) {
      setState(() {
        _items = items;
      });
    }
  }

  void _addMedia(String mediaType) async {
    List<XFile> xfiles;
    switch (mediaType) {
      case "image":
        xfiles = await pickImage();
        break;
      case "video":
        xfiles = await pickVideo();
        break;
      default:
        return;
    }

    for (var xfile in xfiles) {
      var name = "content/$_folder/${basename(xfile.name)}";
      var localpath =
          join(documentsFolder, _safe.name, _folder, basename(xfile.name));
      await xfile.saveTo(localpath);
      var options = PutOptions(
          contentType: lookupMimeType(xfile.path) ?? '', source: localpath);
      await _safe.putFile(name, localpath, options);
    }

    _read();
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
                    _addMedia('image');
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
                    _addMedia('video');
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
      body: FutureBuilder(
          future: _read(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CatProgressIndicator("Loading...");
            }
            return Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                        onPressed: _read, icon: const Icon(Icons.refresh)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _handleAttachmentPressed(context),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      var w = _items[index];
                      var width = MediaQuery.of(context).size.width * 0.9;
                      var height = w is Video ? width * 9.0 / 16.0 : null;
                      return Card(
                        elevation: 3.0,
                        margin: const EdgeInsets.all(8.0),
                        child: Center(
                          child:
                              SizedBox(width: width, height: height, child: w),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }),
    );
  }
}
