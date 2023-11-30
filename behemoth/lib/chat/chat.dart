import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:behemoth/common/common.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import 'package:behemoth/common/image.dart';
import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/common/progress.dart';
import 'package:behemoth/woland/types.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as ph;

class Chat extends StatefulWidget {
  final Safe safe;
  final String privateId;

  const Chat(this.safe, this.privateId, {Key? key}) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  List<types.Message> _messages = [];
  DateTime _from = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _to = DateTime.now();
  Timer? _timer;
  DateTime _lastSync = DateTime(0);
  DateTime _lastMessage = DateTime(0);
  late types.User _currentUser;
  final Map<String, types.User> _users = {};
  final Set<String> _loaded = {};
  final double _pageThresold = isDesktop ? 40 : 20;
  bool _isLastPage = false;
  late Safe _safe;
  final FocusNode _focusNode = FocusNode();
  late String _picsFolder;
  DateTime _lastPeerMessage = DateTime(0);

  @override
  void initState() {
    super.initState();
    _safe = widget.safe;
    _picsFolder = ph.join(documentsFolder, _safe.name, ".gallery");
    var currentUser = Profile.current().identity;
    _currentUser = types.User(
        id: currentUser.id,
        firstName: currentUser.nick,
        lastName: currentUser.email);

    Future.delayed(const Duration(seconds: 3), _refresh);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _timer ??=
            Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void _refresh() async {
    if (!mounted) return;

    var now = DateTime.now();
    var diff = now.difference(_lastPeerMessage).inSeconds;
    var diff2 = now.difference(_lastSync).inSeconds;
    if (diff < 20 || diff2 > 60) {
      if (await _safe.syncBucket("chat", SyncOptions()) > 0) {
        _loadMoreMessages();
      }
      _lastSync = now;
    }
  }

  types.Message _convertHtml(Header h, types.User user) {
    return types.CustomMessage(
        id: h.name,
        author: user,
        createdAt: h.modTime.millisecondsSinceEpoch,
        metadata: {
          'mime': h.attributes.contentType,
          'data': h.attributes.extra['data'],
        });
  }

  types.Message _convertText(Header h, types.User user) {
    return types.TextMessage(
        id: h.name,
        text: h.attributes.extra['text'],
        author: user,
        createdAt: h.modTime.millisecondsSinceEpoch);
  }

  types.Message _convertLibraryFile(Header h, types.User user) {
    var text = h.attributes.extra['text'];
    return types.FileMessage(
        author: user,
        createdAt: h.modTime.millisecondsSinceEpoch,
        id: h.name,
        mimeType: h.attributes.contentType,
        name: ph.basename(text),
        uri: text,
        size: 1);
  }

  types.Message _convertEmbeddedImage(Header h, types.User user) {
    var size =
        h.attributes.thumbnail.isEmpty ? h.size : h.attributes.thumbnail.length;
    var file = File(ph.join(_picsFolder, "${h.fileId}"));
    file.parent.createSync(recursive: true);
    var stat = FileStat.statSync(file.path);
    if (h.size != stat.size) {
      if (h.attributes.thumbnail.isNotEmpty) {
        file.writeAsBytesSync(h.attributes.thumbnail);
      }
      _safe
          .getFile("chat", h.name, file.path, GetOptions(fileId: h.fileId))
          .then((value) {});
    }

    return types.ImageMessage(
      author: user,
      createdAt: h.modTime.millisecondsSinceEpoch,
      id: h.name,
      name: h.name,
      size: size,
      uri: file.path,
      metadata: {
        'header': h,
        'file': file,
      },
    );
  }

  types.Message _convertInvite(Header h, types.User user) {
    var sender = Identity.fromJson(h.attributes.extra['sender']);
    return types.CustomMessage(
        id: h.name,
        author: user,
        createdAt: h.modTime.millisecondsSinceEpoch,
        metadata: {
          'mime': h.attributes.contentType,
          'access': h.attributes.extra['access'],
          'name': h.attributes.extra['name'],
          'sender': sender,
        });
  }

  types.Message _convert(Header h) {
    try {
      var user = _users.putIfAbsent(h.creator, () {
        Identity i = getCachedIdentity(h.creator);
        return types.User(id: h.creator, firstName: i.nick, lastName: i.email);
      });
      var contentType = h.attributes.contentType;
      _loaded.add(h.name);

      if (contentType == 'text/html') {
        return _convertHtml(h, user);
      }
      if (contentType == 'application/x-behemoth-invite') {
        return _convertInvite(h, user);
      }
      if (contentType.startsWith('text/')) {
        return _convertText(h, user);
      }
      if (contentType.startsWith("image/")) {
        return _convertEmbeddedImage(h, user);
      }
      if (contentType.startsWith("application/") ||
          contentType.startsWith('text/')) {
        return _convertLibraryFile(h, user);
      }
      return types.TextMessage(
          id: h.name,
          text: "Unsupported message with content type $contentType",
          createdAt: h.modTime.millisecondsSinceEpoch,
          author: types.User(id: h.creator));
    } catch (err) {
      return types.TextMessage(
          id: h.name,
          createdAt: h.modTime.millisecondsSinceEpoch,
          text: "Error: $err",
          author: types.User(id: h.creator));
    }
  }

  _listFiles(Chat widget, DateTime after, DateTime before) async {
    var options = ListOptions(
        after: after,
        before: before,
        limit: isDesktop ? 40 : 20,
        orderBy: "modTime",
        reverseOrder: true);

    if (widget.privateId.isNotEmpty) {
      options.privateId = widget.privateId;
    } else {
      options.noPrivate = true;
    }
    return _safe.listFiles("chat", options);
  }

  _loadMoreMessages([bool showProgress = false]) async {
    _to = DateTime.now();
    var headers = showProgress
        // ignore: use_build_context_synchronously
        ? await progressDialog<List<Header>>(
            context, "Getting messages", _listFiles(widget, _from, _to))
        : await _listFiles(widget, _from, _to);

    if (!mounted) return;
    if (headers == null || headers.isEmpty) {
      return;
    }

    headers = headers.reversed.toList();
    var anyNew = false;
    for (var header in headers) {
      if (!_loaded.contains(header.name)) {
        if (header.modTime.isAfter(_lastPeerMessage) &&
            header.creator != _safe.currentUser.id) {
          _lastPeerMessage = header.modTime;
        }
        _messages.insert(0, _convert(header));
        _loaded.add(header.name);
        anyNew = true;
      }
    }

    _isLastPage =
        _from.millisecondsSinceEpoch == 0 && headers.length < _pageThresold;
    _from = headers.last.modTime;
    if (_from.isAfter(_lastMessage)) {
      _lastMessage = _from;
    }
    if (anyNew) {
      setState(() {
        _messages = _messages;
      });
    }
  }

  Widget _customMessageBuilder(types.CustomMessage message,
      {required int messageWidth}) {
    var mime = message.metadata?['mime'];
    switch (mime) {
      case 'text/html':
        var data = message.metadata?['data'];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chat.UserName(author: message.author),
              html.Html(
                data: data,
                style: {'*': html.Style(fontSize: html.FontSize(14))},
              ),
            ],
          ),
        );
      case 'application/x-behemoth-invite':
        var access = message.metadata?['access'] as String;
        var name = message.metadata?['name'] as String;
        var sender = message.metadata?['sender'] as Identity;

        return Card(
          color: Colors.blue,
          margin: const EdgeInsets.all(4.0),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Invite to join $name from ${sender.nick}",
                  style: const TextStyle(
                    backgroundColor: Colors.blue,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                if (sender.id != _safe.currentUser.id)
                  PlatformElevatedButton(
                    onPressed: () async {
                      await progressDialog(
                          context, "Joining $name", Coven.join(access),
                          successMessage: "Joined $name",
                          errorMessage: "Failed to join $name");
                    },
                    child: const Text('Join'),
                  ),
              ],
            ),
          ),
        );
      default:
        return Text("unsupported type $mime");
    }
  }

  Future<void> _handleEndReached() async {
    var after = _from.add(-const Duration(days: -1));
    var before = _from;
    var headers = await progressDialog<List<Header>>(
        context, "Getting messages", _listFiles(widget, after, before));

    setState(() {
      if (headers == null || headers.isEmpty) {
        _isLastPage = true;
        return;
      }

      for (var header in headers.reversed) {
        if (!_loaded.contains(header.name)) {
          _messages.add(_convert(header));
          _loaded.add(header.name);
        }
      }
      _isLastPage = headers.length < _pageThresold;
      _from = headers.first.modTime;
    });
  }

  void _handleSendPressed(types.PartialText message) async {
    var name = '${Snowflake(nodeId: 0).generate()}';
    var putOptions = PutOptions(
      contentType: "text/plain",
      private: widget.privateId,
      meta: {'text': message.text},
    );

    var header = await _safe.putBytes("chat", name, Uint8List(0), putOptions);

    final textMessage = types.TextMessage(
      author: _currentUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: header.name,
      text: message.text,
    );

    _loaded.add(name);
    _addMessage(textMessage);
  }

  void _handleAttachmentPressed(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: isMobile ? 300 : 200,
          child: ListView(
            children: [
              if (isMobile)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () {
                      Navigator.pop(context);
                      _handleCameraSelection(context);
                    },
                  ),
                ),
              const SizedBox(
                height: 4,
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageSelection(context);
                  },
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.file_copy),
                  title: const Text('File'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleFileSelection();
                  },
                ),
              ),
              const SizedBox(
                height: 4,
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

  void _addFile(String filePath) async {
    var contentType = lookupMimeType(filePath) ?? '';
    var options = PutOptions(contentType: contentType, async: true);

    var size = File(filePath).lengthSync();
    var name = ph.basename(filePath);
    var header = await _safe.putFile("chat", name, filePath, options);

    final message = types.FileMessage(
      author: _currentUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: name,
      mimeType: header.attributes.contentType,
      name: name,
      size: size,
      uri: "file://$name",
    );
    _loaded.add(name);

    _addMessage(message);
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: "file to send",
        initialDirectory: documentsFolder);

    for (var file in result!.files) {
      _addFile(file.path!);
      // var name = ph.basename(localPath);
      // sp.librarySend(_poolName, localPath, "uploads/$name", true, []);
      // final mimeType = lookupMimeType(localPath);

      // var uri = "library:/uploads/$name";
      // var id = sp.chatSend(_poolName, mimeType!, uri, Uint8List(0), _private);

      // final message = types.FileMessage(
      //   author: _currentUser,
      //   createdAt: DateTime.now().millisecondsSinceEpoch,
      //   id: "$id",
      //   mimeType: mimeType,
      //   name: name,
      //   size: result.files.single.size,
      //   uri: uri,
      // );
      // _loaded.add("$id");

      // _addMessage(message);
    }
  }

  void _addImage(XFile xfile) async {
    final bytes = await xfile.readAsBytes();
    final image = await decodeImageFromList(bytes);

    var name = ph.basename(xfile.path);
    var options = PutOptions(async: true);
    options.autoThumbnail = true;
    options.contentType = lookupMimeType(xfile.path) ?? '';

    var header = await _safe.putFile("chat", name, xfile.path, options);

    final message = types.ImageMessage(
      author: _currentUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      height: image.height.toDouble(),
      id: name,
      name: xfile.name,
      size: bytes.length,
      uri: xfile.path,
      width: image.width.toDouble(),
      updatedAt: header.modTime.millisecondsSinceEpoch,
    );

    _addMessage(message);
  }

  void _handleCameraSelection(BuildContext context) async {
    for (var xfile in await pickImage(ImageSource.camera)) {
      _addImage(xfile);
    }
  }

  void _handleImageSelection(BuildContext context) async {
    for (var xfile in await pickImage(ImageSource.gallery, multiple: true)) {
      _addImage(xfile);
    }
  }

  void _handleMessageTap(BuildContext context, types.Message message) async {
    if (message is types.FileMessage) {
      if (message.uri.startsWith('library:/')) {
        var folder = message.uri.replaceFirst("library:/", "");
        var idx = folder.lastIndexOf('/');
        folder = idx == -1 ? "" : folder.substring(0, idx);

        //   Navigator.pushNamed(context, "/apps/library",
        //       arguments: LibraryArgs(_poolName, folder));
      }
    }
  }

  Future<bool?> _inlineImagesDialog() async {
    return showPlatformDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Images or Files?'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('The dropped files contain images'),
                Text('Would you like to inline as images or add as files?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Inlined Images'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            TextButton(
              child: const Text('Files'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      },
    );
  }

  void _dropFiles(List<XFile> files) async {
    var imageFiles = files.where((f) {
      var mimeType = lookupMimeType(f.path);
      return mimeType.toString().startsWith("image/");
    });
    var inlineImages =
        imageFiles.isNotEmpty ? await _inlineImagesDialog() ?? false : false;

    for (var f in files) {
      if (inlineImages && imageFiles.contains(f)) {
        _addImage(f);
      } else {
        _addFile(f.path);
      }
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  void _addMessage(types.Message message) {
    setState(() {
      _loaded.add(message.id);
      _messages.insert(0, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    _loadMoreMessages();
    var chatWidget = Focus(
      focusNode: _focusNode,
      child: DropTarget(
        onDragDone: (details) async {
          _dropFiles(details.files);
        },
        child: chat.Chat(
          messages: _messages,
          onAttachmentPressed: () {
            _handleAttachmentPressed(context);
          },
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          onEndReached: _handleEndReached,
          onEndReachedThreshold: _pageThresold,
          isLastPage: _isLastPage,
          showUserAvatars: true,
          showUserNames: true,
          user: _currentUser,
          customMessageBuilder: _customMessageBuilder,
        ),
      ),
    );

    return chatWidget;
  }
}
