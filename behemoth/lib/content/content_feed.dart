import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/checkbox2.dart';
import 'package:behemoth/common/image.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/rate_me.dart';
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

class Feedback {
  int fileId;
  String id;
  String comment;

  Feedback({this.fileId = 0, this.id = "", this.comment = ""});
  Feedback.fromJson(this.id, Map<String, dynamic> json)
      : fileId = json['f'],
        comment = json['c'];

  Map<String, dynamic> toJson() => {'f': fileId, 'c': comment};
}

class _ContentFeedState extends State<ContentFeed> {
  int _offset = 0;
  List<Header> _headers = [];
  late Safe _safe;
  late String _room;
  String _dir = "";
  final Map<int, Widget> _cache = {};
  final Set<Header> _checked = {};
  final List<Player> _players = [];
  final ScrollController _scrollController = ScrollController();
  //bool _reload = true;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _cleanUp(bool _) async {
    for (var p in _players) {
      await p.stop();
      await p.dispose();
    }
    _players.clear();
  }

  void _handleScroll() {
    var pos = _scrollController.position.pixels;
    if (pos == _scrollController.position.maxScrollExtent) {
      setState(() {
        _offset += 5;
        //   _reload = true;
      });
    }
    if (pos == _scrollController.position.minScrollExtent) {
      setState(() {
        //     _reload = true;
      });
    }
  }

  Widget _getImageWidget(Header h) {
    if (h.attributes.thumbnail.isNotEmpty) {
      return InteractiveViewer(
        child: Image.memory(
          h.attributes.thumbnail,
          fit: BoxFit.cover,
        ),
      );
    }

    var localpath =
        join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
    var localfile = File(localpath);
    if (!localfile.existsSync()) {
      return Text("Missing image ${h.name}");
    }

    return InteractiveViewer(
      child: Image.file(localfile, fit: BoxFit.cover),
    );
  }

  Widget _getVideoWidget(
    Header h,
  ) {
    var player = Player();
    var controller = VideoController(player);
    var localpath =
        join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
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

  // Future _readFeedbacks() async {
  //   var cu = _safe.currentUser.id;
  //   var feedbacks = <int, List<Feedback>>{};
  //   var headers = _safe.listFiles(
  //       "rooms/$_room/content",
  //       ListOptions(
  //         dir: _dir,
  //         suffix: ".feedback",
  //       ));
  //   for (var h in headers) {
  //     var fb = <Feedback>[];
  //     try {
  //       var byteList = await _safe.getBytes(
  //           "rooms/$_room/content", h.name, GetOptions(noCache: true));
  //       var content = utf8.decode(byteList.toList());
  //       var decoded = jsonDecode(content) as List;
  //       fb = decoded.map((v) {
  //         var f = v as Map<String, dynamic>;
  //         return Feedback.fromJson(h.creator, f);
  //       }).toList();
  //       if (h.creator == cu) {
  //         _myFeedback = fb.toList();
  //       }
  //       for (var f in fb) {
  //         feedbacks.putIfAbsent(f.fileId, () => []).add(f);
  //       }
  //     } catch (e) {
  //       // ignore
  //     }
  //   }
  //   _feedbacks = feedbacks;
  // }

  Future _read() async {
    var headers = _safe.listFiles(
        "rooms/$_room/content",
        ListOptions(
          dir: _dir,
          tags: ['media'],
          reverseOrder: true,
          orderBy: 'modTime',
          limit: 5,
          offset: _offset,
        ));

    for (var h in headers) {
      var found = _headers.where((h2) => h2.fileId == h.fileId);
      if (found.isNotEmpty) {
        continue;
      }
      try {
        var localpath =
            join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
        var localfile = File(localpath);
        if (!localfile.existsSync()) {
          await _safe.getFile(
              "rooms/$_room/content", h.name, localpath, GetOptions());
        }
        _headers.add(h);
      } catch (e) {
        continue;
      }
    }
    _headers.sort((a, b) => b.modTime.compareTo(a.modTime));
//    await _readFeedbacks();
//    _reload = false;
  }

  void _addMedia(BuildContext context, String mediaType) async {
    List<XFile> xfiles;
    switch (mediaType) {
      case "image":
        xfiles = await pickImage(ImageSource.gallery, multiple: true);
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
          join(documentsFolder, _safe.name, _room, _dir, basename(xfile.name));
      xfile.saveTo(localpath);
      var options = PutOptions(
          tags: ['media'],
          contentType: lookupMimeType(xfile.path) ?? '',
          source: localpath);
      _safe.putFile("rooms/$_room/content", name, localpath, options).then((h) {
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

  void _writeFeedback(String name, String symbol) {
    var bucket = "rooms/$_room/content";
    var headers = _safe.listFiles(bucket, ListOptions(name: name));

    if (headers.isEmpty) {
      return;
    }
    var h = headers.first;
    var extra = h.attributes.meta;
    extra.putIfAbsent(symbol, () => []);
    extra[symbol].add(_safe.currentUser.id);
    _safe.putBytes(
        bucket,
        name,
        Uint8List(0),
        PutOptions(
            onlyHeader: true,
            meta: extra,
            tags: h.attributes.tags,
            thumbnail: h.attributes.thumbnail,
            contentType: h.attributes.contentType));
  }

  void _comment(Header h) {}

  void _check(Header h) {
    if (_checked.contains(h)) {
      _checked.remove(h);
    } else {
      _checked.add(h);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dir.isEmpty) {
      var args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _safe = args["safe"] as Safe;
      _room = args["room"] as String;
      _dir = args["folder"] as String;
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_dir.substring(0, _dir.length - 5),
            style: const TextStyle(fontSize: 18)),
        trailingActions: [
//          const NewsIcon(),
          PlatformIconButton(
              onPressed: () {}, icon: const Icon(Icons.exit_to_app)),
        ],
      ),
      body: PopScope(
        onPopInvoked: _cleanUp,
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

                          var extra = h.attributes.meta;
                          var hearts = extra['❤️'] ?? [];
                          var iHearts =
                              hearts.contains(_safe.currentUser.id) ?? false;
                          var likes = extra['👍'] ?? [];
                          var iLike =
                              likes.contains(_safe.currentUser.id) ?? false;

                          return Card(
                            elevation: 3.0,
                            margin: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                w,
                                const SizedBox(
                                  height: 2,
                                ),
                                Row(children: [
                                  Checkbox2(
                                      initialValue: _checked.contains(h),
                                      onChanged: (_) => _check(h)),
                                  const SizedBox(width: 10),
                                  const Spacer(),
                                  RateMe(
                                      initialCount: likes.length,
                                      hasRated: iLike,
                                      icon: const Icon(Icons.thumb_up),
                                      color: Colors.green,
                                      onChanged: (_, __) =>
                                          _writeFeedback(h.name, "👍")),
                                  RateMe(
                                      initialCount: hearts.length,
                                      hasRated: iHearts,
                                      icon: const Icon(Icons.favorite),
                                      color: Colors.red,
                                      onChanged: (_, __) =>
                                          _writeFeedback(h.name, "❤️")),
                                  IconButton(
                                      onPressed: () => _comment(h),
                                      icon: const Icon(Icons.comment)),
                                ]),
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
