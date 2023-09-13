import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'dart:typed_data';

import 'package:margarita/common/common.dart';
import 'package:snowflake_dart/snowflake_dart.dart';

import 'package:margarita/common/image.dart';
import 'package:margarita/common/io.dart';
import 'package:margarita/common/profile.dart';
import 'package:margarita/common/progress.dart';
import 'package:margarita/woland/woland_def.dart';
import 'package:margarita/woland/woland.dart';
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
  final String safeName;
  final String privateId;
  const Chat(this.safeName, this.privateId, {Key? key}) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final List<types.Message> _messages = [];
  DateTime _from = DateTime.now().add(-const Duration(days: 1));
  DateTime _to = DateTime.now();
  Timer? timer;
  DateTime _lastMessage = DateTime.now();
  late types.User _currentUser;
  final Map<String, types.User> _users = {};
  final Set<String> _loaded = {};
  final double _pageThresold = isDesktop ? 40 : 20;
  bool _isLastPage = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
      const Duration(seconds: 30),
      (Timer t) {
        var diff = DateTime.now().difference(_lastMessage).inSeconds;
        if (diff < 20 || diff > 50) {
          _loadMoreMessages();
        }
      },
    );
  }

  void _setUsers() {
    var profile = Profile.current();
    var currentUser = profile.identity;
    var users = getUsers(widget.safeName);
    _currentUser = types.User(
        id: currentUser.id,
        firstName: currentUser.nick,
        lastName: currentUser.email);

    for (var id in users.keys) {
      Identity i = getCachedIdentity(id);
      _users[id] = types.User(id: id, firstName: i.nick, lastName: i.email);
    }
  }

  @override
  void dispose() {
    super.dispose();
    timer?.cancel();
    timer = null;
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
    var file = File("$temporaryFolder/${h.name}");
    file.parent.createSync(recursive: true);
    var stat = FileStat.statSync(file.path);
    if (h.size != stat.size) {
      if (h.attributes.thumbnail.isNotEmpty) {
        file.writeAsBytesSync(h.attributes.thumbnail);
      } else {
        var options = GetOptions();
        options.fileId = h.fileId;
        getFile(widget.safeName, h.name, file.path, options);
      }
    }

    return types.ImageMessage(
      author: user,
      createdAt: h.modTime.millisecondsSinceEpoch,
      id: h.name,
      name: h.name,
      size: size,
      uri: file.path,
    );
  }

  types.Message _convert(Header h) {
    try {
      var user = _users[h.creator] ?? types.User(id: h.creator);
      var contentType = h.attributes.contentType;
      _loaded.add(h.name);

      if (contentType == 'text/html') {
        return _convertHtml(h, user);
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

  static _listFiles(Chat widget, DateTime after, DateTime before) {
    var options =
        ListOptions(after: after, before: before, limit: isDesktop ? 40 : 20);

    if (widget.privateId.isNotEmpty) {
      options.privateId = widget.privateId;
    } else {
      options.noPrivate = true;
    }
    return Isolate.run<List<Header>>(
        () => listFiles(widget.safeName, "chat", options));
  }

  _loadMoreMessages([bool showProgress = false]) async {
    if (timer == null) {
      return;
    }
    _to = DateTime.now();
    var headers = showProgress
        // ignore: use_build_context_synchronously
        ? await progressDialog<List<Header>>(
            context, "Getting messages", _listFiles(widget, _from, _to))
        : await _listFiles(widget, _from, _to);

    if (headers == null || headers.isEmpty) {
      return;
    }

    headers = headers.reversed.toList();

    setState(() {
      for (var header in headers) {
        if (!_loaded.contains(header.name)) {
          _messages.insert(0, _convert(header));
          _loaded.add(header.name);
        }
      }

      _isLastPage =
          _from.millisecondsSinceEpoch == 0 && headers.length < _pageThresold;
      if (_from.microsecondsSinceEpoch == 0) {
        _from = headers.first.modTime;
      }
      _from = headers.last.modTime;
      _lastMessage = DateTime.now();
    });
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

  void _handleSendPressed(types.PartialText message) {
    var name = 'chat/${Snowflake(nodeId: 0).generate()}';
    var putOptions = PutOptions();
    putOptions.contentType = "text/plain";
    putOptions.meta = {'text': message.text};

    var header = putBytes(widget.safeName, name, Uint8List(0), putOptions);

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
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection(context);
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addFile(String filePath) async {
    var options = PutOptions();
    options.contentType = lookupMimeType(filePath) ?? '';

    var size = File(filePath).lengthSync();
    var name = 'chat/${ph.basename(filePath)}';
    var header = putFile(widget.safeName, name, filePath, options);

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

    var name = "chat/${ph.basename(xfile.path)}";
    var options = PutOptions();
    options.autoThumbnail = true;
    options.contentType = lookupMimeType(xfile.path) ?? '';

    var header = putFile(widget.safeName, name, xfile.path, options);

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

  void _handleImageSelection(BuildContext context) async {
    XFile? xfile = await pickImage();

    if (xfile != null) {
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
    return showDialog<bool>(
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
    if (_users.isEmpty) {
      _setUsers();
      Future.delayed(
          const Duration(milliseconds: 10), () => _loadMoreMessages(true));
    }

    return Column(
      children: [
        DropTarget(
          onDragDone: (details) async {
            _dropFiles(details.files);
          },
          child: Expanded(
            child: chat.Chat(
              messages: _messages,
              onAttachmentPressed: () {
                _handleAttachmentPressed(context);
              },
              onMessageTap: _handleMessageTap,
              onPreviewDataFetched: _handlePreviewDataFetched,
              onSendPressed: _handleSendPressed,
              onEndReached: _handleEndReached,
              // onEndReachedThreshold: _pageThresold,
              isLastPage: _isLastPage,
              showUserAvatars: true,
              showUserNames: true,
              user: _currentUser,
              customMessageBuilder: _customMessageBuilder,
            ),
          ),
        ),
      ],
    );
  }
}
