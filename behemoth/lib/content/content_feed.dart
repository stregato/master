import 'dart:async';
import 'dart:io';

import 'package:behemoth/common/checkbox2.dart';
import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/image.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/rate_me.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';

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

const itemsPerRead = 3;

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
  int _pendingUploads = 0;
  final List<Header> _pendingDownloads = [];
  double _pos = 0.0;
  bool _noMore = false;

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
    if (pos > _scrollController.position.maxScrollExtent - 128 && !_noMore) {
      setState(() {
        _offset += itemsPerRead;
        _pos = pos - 100;
        _read();
      });
    }
    if (pos == _scrollController.position.minScrollExtent) {
      setState(() {
        _offset = 0;
        _pos = pos;
        _read();
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

  Future _read() async {
    var headers = _safe.listFiles(
        "rooms/$_room/content",
        ListOptions(
          dir: _dir,
          tags: ['media'],
          reverseOrder: true,
          orderBy: 'modTime',
          limit: itemsPerRead,
          offset: _offset,
        ));

    if (headers.length < itemsPerRead) {
      _noMore = true;
    }
    headers.sort((a, b) => b.modTime.compareTo(a.modTime));
    for (var h in headers) {
      var found = _headers.where((h2) => h2.fileId == h.fileId);
      if (found.isNotEmpty) {
        continue;
      }
      try {
        var localpath =
            join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
        var localfile = File(localpath);
        _headers.add(h);
        var stat = localfile.statSync();
        if (stat.type == FileSystemEntityType.notFound || stat.size != h.size) {
          _pendingDownloads.add(h);
        } else {
          _cache.putIfAbsent(h.fileId, () => _getWidget(h));
        }
      } catch (e) {
        continue;
      }
    }
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

    setState(() {
      _pendingUploads += xfiles.length;
    });
    for (var xfile in xfiles) {
      var name = "$_dir/${basename(xfile.name)}";
      var localpath =
          join(documentsFolder, _safe.name, _room, _dir, basename(xfile.name));
      xfile.saveTo(localpath);
      var options = PutOptions(
          tags: ['media'],
          contentType: lookupMimeType(xfile.path) ?? '',
          source: localpath);
      var h =
          await _safe.putFile("rooms/$_room/content", name, localpath, options);
      var w = _getWidget(h);
      setState(() {
        _cache.putIfAbsent(h.fileId, () => w);
        _pendingUploads--;
        _headers = [h, ..._headers];
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

  void _share(BuildContext context) async {
    var headers = _checked.toList();
    var files = headers
        .map((h) => XFile(
            join(documentsFolder, _safe.name, _room, _dir, basename(h.name))))
        .toList();
    if (isDesktop) {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      for (var f in files) {
        f.saveTo(join(selectedDirectory!, basename(f.path)));
      }
      if (mounted) {
        showPlatformSnackbar(
            context, "${files.length} files saved to $selectedDirectory");
      }
    } else {
      Share.shareXFiles(files);
    }
  }

  void _writeFeedback(String name, String symbol) {
    var bucket = "rooms/$_room/content";
    var headers = _safe.listFiles(bucket, ListOptions(name: name));

    if (headers.isEmpty) {
      return;
    }
    var h = headers.first;
    var meta = h.attributes.meta;
    meta.putIfAbsent(symbol, () => []);
    if (meta[symbol].contains(_safe.currentUser.id)) {
      meta[symbol].remove(_safe.currentUser.id);
    } else {
      meta[symbol].add(_safe.currentUser.id);
    }
    h.attributes.meta = meta;
    _safe.patch(bucket, h, PatchOptions(async: true));
  }

  void _comment(BuildContext context, Header h) async {
    var textController = TextEditingController();

    var comment = await showPlatformDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add comment"),
          content: PlatformTextField(
            controller: textController,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                Navigator.pop(context, textController.text);
              },
            ),
          ],
        );
      },
    );
    if (comment is String) {
      var bucket = "rooms/$_room/content";
      h.attributes.meta.putIfAbsent("💬", () => []);
      h.attributes.meta["💬"].add(comment);
      _safe.patch(bucket, h, PatchOptions(async: true));
      setState(() {});
    }
  }

  void _delete(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files?'),
        content: Text('Do you want to delete ${_checked.length} files'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (result == 'delete') {
      Future.delayed(Duration.zero, () {
        for (var h in _checked.toList()) {
          h.deleted = true;
          _safe.patch("rooms/$_room/content", h, PatchOptions());
          _headers.remove(h);
          _checked.remove(h);
        }
        setState(() {});
      });
    }
  }

  void _check(Header h) {
    setState(() {
      if (_checked.contains(h)) {
        _checked.remove(h);
      } else {
        _checked.add(h);
      }
    });
  }

  ListView _getListView() {
    var listView = ListView.builder(
      controller: _scrollController,
      itemCount: _headers.length + 1,
      itemBuilder: (context, index) {
        if (index == _headers.length) {
          return _noMore
              ? const SizedBox(height: 100)
              : const Column(children: [
                  SizedBox(height: 80),
                  Text("Pull for more", style: TextStyle(fontSize: 20)),
                  SizedBox(height: 80),
                ]);
        }

        var h = _headers[index];
        var w = _cache[h.fileId];
        if (w == null) {
          return Card(
            elevation: 3.0,
            margin: const EdgeInsets.all(8.0),
            child: Row(children: [
              Text("Loading ${basename(h.name)}"),
              const Spacer(),
              const CircularProgressIndicator()
            ]),
          );
        }

        var extra = h.attributes.meta;
        var hearts = extra['❤️'] ?? [];
        var iHearts = hearts.contains(_safe.currentUser.id) ?? false;
        var likes = extra['👍'] ?? [];
        var iLike = likes.contains(_safe.currentUser.id) ?? false;
        var comments = extra['💬'] ?? [];

        return Card(
          key: ValueKey(_checked.contains(h)),
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
                    onChanged: (_, __) => _writeFeedback(h.name, "👍")),
                RateMe(
                    initialCount: hearts.length,
                    hasRated: iHearts,
                    icon: const Icon(Icons.favorite),
                    color: Colors.red,
                    onChanged: (_, __) => _writeFeedback(h.name, "❤️")),
                IconButton(
                    onPressed: () => _comment(context, h),
                    icon: const Icon(Icons.comment)),
              ]),
              ListView.builder(
                shrinkWrap: true,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  var comment = comments[index];
                  return ListTile(
                    title: Text(comment),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        comments.remove(comment);
                        h.attributes.meta["💬"] = comments;
                        _safe.patch("rooms/$_room/content", h, PatchOptions());
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_pos);
      }
    });
    if (_pendingDownloads.isNotEmpty) {
      Future.delayed(Duration.zero, () async {
        for (var h in _pendingDownloads) {
          await _safe.getFile(
              "rooms/$_room/content",
              h.name,
              join(documentsFolder, _safe.name, _room, _dir, basename(h.name)),
              GetOptions());
          var w = _getWidget(h);
          _cache.putIfAbsent(h.fileId, () => w);
          setState(() {});
        }
        _pendingDownloads.clear();
      });
    }

    return listView;
  }

  @override
  Widget build(BuildContext context) {
    if (_dir.isEmpty) {
      var args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _safe = args["safe"] as Safe;
      _room = args["room"] as String;
      _dir = args["folder"] as String;
      setState(() {
        _read();
      });
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_dir.substring(0, _dir.length - 5),
            style: const TextStyle(fontSize: 18)),
        trailingActions: [
          PlatformIconButton(
              onPressed: () {}, icon: const Icon(Icons.exit_to_app)),
        ],
      ),
      body: PopScope(
        onPopInvoked: _cleanUp,
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  PlatformIconButton(
                      onPressed: _checked.isNotEmpty
                          ? () {
                              setState(() {
                                _checked.clear();
                              });
                            }
                          : null,
                      icon: const Icon(Icons.clear_all)),
                  PlatformIconButton(
                      onPressed: _checked.isNotEmpty
                          ? () {
                              _share(context);
                            }
                          : null,
                      icon: isDesktop
                          ? const Icon(Icons.download)
                          : const Icon(Icons.share)),
                  PlatformIconButton(
                      onPressed:
                          _checked.isNotEmpty ? () => _delete(context) : null,
                      icon: const Icon(Icons.delete)),
                  PlatformIconButton(
                      onPressed: _read, icon: const Icon(Icons.refresh)),
                  const SizedBox(width: 10),
                  PlatformIconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _handleAttachmentPressed(context),
                  ),
                ],
              ),
              if (_pendingUploads > 0)
                Container(
                  margin: const EdgeInsets.all(32),
                  child: Text(
                    "Loading $_pendingUploads...",
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              Expanded(
                child: _getListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
