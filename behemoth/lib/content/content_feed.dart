import 'dart:io';
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

class ContentFeed extends StatefulWidget {
  const ContentFeed({super.key});

  @override
  State<ContentFeed> createState() => _ContentFeedState();
}

class _ContentFeedState extends State<ContentFeed> {
  int _offset = 0;
  List<Header> _headers = [];
  late Safe _safe;
  String _dir = "";
  final Map<int, Widget> _cache = {};
  final List<Player> _players = [];
  final Map<int, Set<String>> _likes = {};
  final ScrollController _scrollController = ScrollController();
  bool _reload = true;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  Future<bool> _cleanUp() async {
    for (var p in _players) {
      await p.stop();
      await p.dispose();
    }
    _players.clear();
    return true;
  }

  void _handleScroll() {
    var pos = _scrollController.position.pixels;
    if (pos == _scrollController.position.maxScrollExtent) {
      setState(() {
        _offset += 5;
        _reload = true;
      });
    }
    if (pos == _scrollController.position.minScrollExtent) {
      setState(() {
        _reload = true;
      });
    }
  }

  Widget _getImageWidget(Header h) {
    if (h.attributes.thumbnail.isNotEmpty) {
      return Image.memory(
        h.attributes.thumbnail,
        fit: BoxFit.cover,
      );
    }

    var localpath = join(documentsFolder, _safe.name, _dir, basename(h.name));
    var localfile = File(localpath);
    if (!localfile.existsSync()) {
      return Text("Missing image ${h.name}");
    }

    return Image.file(localfile, fit: BoxFit.cover);
  }

  Widget _getVideoWidget(
    Header h,
  ) {
    var player = Player();
    var controller = VideoController(player);
    var localpath = join(documentsFolder, _safe.name, _dir, basename(h.name));
    var localfile = File(localpath);
    if (!localfile.existsSync()) {
      return Text("Missing video ${h.name}");
    }

    player.open(Media(localpath), play: false);
    player.play();
    _players.add(player);
    return Video(controller: controller);
  }

  Widget _getWidget(Header h) {
    var mime = h.attributes.contentType;
    if (mime.startsWith("image/")) {
      return _getImageWidget(h);
    } else if (mime.startsWith("video/")) {
      return _getVideoWidget(h);
    }
    return Container();
  }

  Future _readLikes() async {
    var cu = _safe.currentUser.id;
    var headers = await _safe.listFiles(
        "content",
        ListOptions(
          dir: _dir,
          tags: ['like'],
        ));
    for (var h in headers) {
      var ids = <int>[];
      try {
        var byteList = await _safe.getBytes("content", h.name, GetOptions());
        ids = Uint64List.view(byteList.buffer).toList();
      } catch (e) {
        // ignore
      }
      for (var id in ids) {
        _likes.putIfAbsent(id, () => {}).add(cu);
      }
    }
  }

  Future _read() async {
    if (!_reload) {
      return;
    }
    await _readLikes();
    var headers = await _safe.listFiles(
        "content",
        ListOptions(
          dir: _dir,
          tags: ['media'],
          reverseOrder: true,
          orderBy: 'modTime',
          limit: 5,
          offset: _offset,
        ));

    for (var h in headers) {
      if (_headers.contains(h)) {
        continue;
      }
      try {
        var localpath =
            join(documentsFolder, _safe.name, _dir, basename(h.name));
        var localfile = File(localpath);
        if (!localfile.existsSync()) {
          await _safe.getFile("content", h.name, localpath, GetOptions());
        }
        _headers.add(h);
      } catch (e) {
        continue;
      }
    }
    _headers.sort((a, b) => b.modTime.compareTo(a.modTime));
    _reload = false;
  }

  void _addMedia(BuildContext context, String mediaType) async {
    List<XFile> xfiles;
    switch (mediaType) {
      case "image":
        xfiles = await pickImage(ImageSource.gallery);
        break;
      case "video":
        xfiles = await pickVideo();
        break;
      default:
        return;
    }

    for (var xfile in xfiles) {
      var name = "$_dir/${basename(xfile.name)}";
      var localpath =
          join(documentsFolder, _safe.name, _dir, basename(xfile.name));
      xfile.saveTo(localpath);
      var options = PutOptions(
          tags: ['media'],
          contentType: lookupMimeType(xfile.path) ?? '',
          source: localpath);
      _safe.putFile("content", name, localpath, options).then((h) {
        setState(() {
          _pending--;
          _headers = [h, ..._headers];
        });
      });
      setState(() {
        _pending++;
      });
    }
  }

  void _handleAttachmentPressed(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _addMedia(context, 'image');
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
                    _addMedia(context, 'video');
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

  _setLiking(int fileId, bool liking) async {
    var cu = _safe.currentUser.id;
    var name = "content/$_dir/$cu";
    var headers = await _safe.listFiles(
        "content",
        ListOptions(
          dir: _dir,
          name: name,
        ));
    var ids = <int>{};
    if (headers.isNotEmpty) {
      try {
        var byteList = await _safe.getBytes("content", name, GetOptions());
        ids = Uint64List.view(byteList.buffer).toSet();
      } finally {}
    }
    if (liking) {
      ids.add(fileId);
    }
    if (!liking) {
      ids.remove(fileId);
    }
    var byteList = Uint64List.fromList(ids.toList());
    var options = PutOptions(tags: ['like'], replace: true);
    await _safe.putBytes(
        "content", name, byteList.buffer.asUint8List(), options);

    var likes = _likes.putIfAbsent(fileId, () => {});
    setState(() {
      if (liking) {
        likes.add(cu);
      } else {
        likes.remove(cu);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dir.isEmpty) {
      var args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _safe = args["safe"] as Safe;
      _dir = args["folder"] as String;
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_dir.substring(0, _dir.length - 5),
            style: const TextStyle(fontSize: 18)),
        trailingActions: [
          const NewsIcon(),
          PlatformIconButton(
              onPressed: () {}, icon: const Icon(Icons.exit_to_app)),
        ],
      ),
      body: WillPopScope(
        onWillPop: _cleanUp,
        child: FutureBuilder(
            future: _read(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CatProgressIndicator("Loading...");
              }

              return SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        PlatformIconButton(
                            onPressed: _read, icon: const Icon(Icons.refresh)),
                        const SizedBox(width: 10),
                        PlatformIconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _handleAttachmentPressed(context),
                        ),
                      ],
                    ),
                    if (_pending > 0)
                      Container(
                        margin: const EdgeInsets.all(32),
                        child: Text(
                          "Loading $_pending...",
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _headers.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _headers.length) {
                            return const Column(children: [
                              SizedBox(height: 80),
                              Text("Pull for more",
                                  style: TextStyle(fontSize: 20)),
                              SizedBox(height: 80),
                            ]);
                          }

                          var h = _headers[index];
                          var w =
                              _cache.putIfAbsent(h.fileId, () => _getWidget(h));
                          var width = MediaQuery.of(context).size.width * 0.9;
                          var height = w is Video ? width * 9.0 / 16.0 : null;
                          var likes = _likes[h.fileId] ?? {};
                          var liking = likes.contains(_safe.currentUser.id);

                          return Card(
                            elevation: 3.0,
                            margin: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                    width: width - 20,
                                    height: height,
                                    child: w),
                                SizedBox(
                                    width: 20.0, // Adjust the width as needed
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (liking)
                                              IconButton(
                                                icon: const Icon(Icons.thumb_up,
                                                    color: Colors.green),
                                                onPressed: () {
                                                  _setLiking(h.fileId, !liking);
                                                },
                                              )
                                            else
                                              IconButton(
                                                icon: const Icon(Icons.thumb_up,
                                                    color: Colors.black),
                                                onPressed: () {
                                                  _setLiking(h.fileId, !liking);
                                                },
                                              ),
                                            Text("(${likes.length})"),
                                          ]),
                                    )),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
      ),
    );
  }
}
