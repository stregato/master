import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:behemoth/chat/unique_file_image.dart';
import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:behemoth/coven/cockpit.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:share_plus/share_plus.dart';
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
  final Coven coven;
  final String room;
  final String privateId;

  const Chat(this.coven, this.room, this.privateId, {Key? key})
      : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  List<types.Message> _messages = [];
  DateTime _from = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _to = DateTime.now();
  Timer? _timer;
  DateTime _lastSync = DateTime(0);
  DateTime _lastMessage = DateTime(0);
  late types.User _currentUser;
  final Map<String, types.User> _users = {};
  final Set<int> _loaded = {};
  final double _pageThresold = isDesktop ? 40 : 20;
  bool _isLastPage = false;
  late Safe _safe;
  late String _room;
  late String _bucket;
  final FocusNode _focusNode = FocusNode();
  late String _picsFolder;
  DateTime _lastAction = DateTime(0);
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    var currentUser = widget.coven.identity;
    _safe = widget.coven.safe;
    _room = widget.room;
    _picsFolder = ph.join(documentsFolder, _safe.name, _room, ".gallery");
    _bucket = "rooms/$_room/chat";
    _currentUser = types.User(
        id: currentUser.id,
        firstName: currentUser.nick,
        lastName: currentUser.email);

    Future.delayed(const Duration(seconds: 3), _refresh);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _timer ??=
            Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
        _touch();
        _refresh();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _lastAction = DateTime.now();
    }
  }

  void _touch() async {
    _lastAction = DateTime.now();
  }

  Future<bool> _sync() async {
    return await _safe.syncBucket(_bucket, SyncOptions()) > 0;
  }

  void _refresh() async {
    if (!mounted) return;
    _refreshCount++;

    var now = DateTime.now();
    var diff = now.difference(_lastAction).inSeconds;
    var diff2 = now.difference(_lastSync).inSeconds;
    var syncNeeded =
        diff2 > 600 || diff < 60 || _refreshCount > (1 + diff / 60);

    if (syncNeeded) {
      if (await _sync()) {
        Cockpit.visitRoom(widget.coven, _room, privateId: widget.privateId);
        _loadMoreMessages();
      }
      _lastSync = now;
      _refreshCount = 0;
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

  types.Message _convertImage(Header h, types.User user) {
    var size =
        h.attributes.thumbnail.isEmpty ? h.size : h.attributes.thumbnail.length;

    var file = File(ph.join(_picsFolder, "${h.fileId}"));
    file.parent.createSync(recursive: true);
    var stat = FileStat.statSync(file.path);
    if (stat.type == FileSystemEntityType.notFound) {
      if (h.attributes.thumbnail.isNotEmpty) {
        file.writeAsBytesSync(h.attributes.thumbnail);
      }

      // _safe
      //     .getFile(_bucket, h.name, file.path, GetOptions(fileId: h.fileId))
      //     .then((_) => setState(() {}));
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
        return _convertImage(h, user);
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
        privateId: widget.privateId,
        reverseOrder: true);
    return _safe.listFiles(_bucket, options);
  }

  _loadMoreMessages() async {
    _to = DateTime.now().add(const Duration(seconds: 10));
    var headers = await _listFiles(widget, _from, _to);
    if (headers == null || headers.isEmpty) {
      return;
    }

    headers = headers.reversed.toList();
    var newMessages = <types.Message>[];
    for (var header in headers) {
      if (!_loaded.contains(header.fileId)) {
        if (header.modTime.isAfter(_lastAction) &&
            header.creator != _safe.currentUser.id) {
          _lastAction = header.modTime;
        }
        newMessages.insert(0, _convert(header));
        _loaded.add(header.fileId);
      }
    }

    _isLastPage =
        _from.millisecondsSinceEpoch == 0 && headers.length < _pageThresold;
    _from = headers.last.modTime;
    if (_from.isAfter(_lastMessage)) {
      _lastMessage = _from;
    }
    if (newMessages.isNotEmpty) {
      setState(() {
        _messages = [...newMessages, ..._messages];
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
                          context, "Joining $name", Coven.join(access, ""),
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
    await _safe.syncBucket(_bucket, SyncOptions());
    if (!mounted) return;

    var headers = await _listFiles(widget, after, before);
    if (headers == null || headers.isEmpty) {
      _isLastPage = true;
      return;
    }

    setState(() {
      for (var header in headers.reversed) {
        if (!_loaded.contains(header.fileId)) {
          _messages.add(_convert(header));
          _loaded.add(header.fileId);
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

    await _safe.putBytes(_bucket, name, Uint8List(0), putOptions);

    // final textMessage = types.TextMessage(
    //   author: _currentUser,
    //   createdAt: DateTime.now().millisecondsSinceEpoch,
    //   id: header.name,
    //   text: message.text,
    // );

//    _loaded.add(header.fileId);
//    _addMessage(textMessage);
    _touch();
    Cockpit.visitRoom(widget.coven, _room, privateId: widget.privateId);
    _loadMoreMessages();
  }

  void _handleAttachmentPressed(BuildContext context) {
    _touch();

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
                      _handleImageSelection(context, ImageSource.camera);
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
                    _handleImageSelection(context, ImageSource.gallery);
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
    var options = PutOptions(
        contentType: contentType, async: true, private: widget.privateId);

    var size = File(filePath).lengthSync();
    var name = ph.basename(filePath);
    var header = await _safe.putFile(_bucket, name, filePath, options);

    final message = types.FileMessage(
      author: _currentUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: name,
      mimeType: header.attributes.contentType,
      name: name,
      size: size,
      uri: "file://$name",
    );
    // _loaded.add(name);
    // _loaded.add(message.id);
    _messages.insert(0, message);
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: "file to send",
        initialDirectory: documentsFolder);

    for (var file in result!.files) {
      _addFile(file.path!);
    }
    setState(() {
      _messages = _messages;
    });

    Cockpit.visitRoom(widget.coven, _room, privateId: widget.privateId);
  }

  Future<void> _addImage(XFile xfile) async {
    //final bytes = await xfile.readAsBytes();
    //final image = await decodeImageFromList(bytes);

    var name = ph.basename(xfile.path);
//    var stat = File(xfile.path).statSync();

    var options = PutOptions(
      async: true,
      private: widget.privateId,
      autoThumbnail: true,
      thumbnailWidth: 512,
      contentType: lookupMimeType(xfile.path) ?? '',
    );
    await _safe.putFile(_bucket, name, xfile.path, options);

    // var message = types.ImageMessage(
    //   author: _currentUser,
    //   createdAt: DateTime.now().millisecondsSinceEpoch,
    //   //height: image.height.toDouble(),
    //   id: "${header.fileId}",
    //   name: xfile.name,
    //   size: stat.size,
    //   //size: bytes.length,
    //   uri: xfile.path,
    //   //width: image.width.toDouble(),
    //   updatedAt: header.modTime.millisecondsSinceEpoch,
    // );
    // setState(() {
    //   _messages = [..._messages, message];
    // });
  }

  // void _handleCameraSelection(BuildContext context) async {
  //   List<types.Message> messages = [];
  //   for (var xfile in await pickImage(ImageSource.camera)) {
  //     messages.add(await _addImage(xfile));
  //   }
  //   setState(() {
  //     _messages = [..._messages, ...messages];
  //   });
  //   Cockpit.visitRoom(widget.coven, _room, privateId: widget.privateId);
  // }

  void _handleImageSelection(
      BuildContext context, ImageSource imageSource) async {
    var xfiles = await pickImage(imageSource, multiple: true);

    Future<void> pushImages(context, xfiles) async {
      if (xfiles.isEmpty) return;

      var xfile = xfiles.removeLast();
      Future.delayed(Duration.zero, () async {
        await _addImage(xfile);
        await _loadMoreMessages();
        pushImages(context, xfiles);
      });
    }

    if (mounted) {
      pushImages(context, xfiles);
    }

    Cockpit.visitRoom(widget.coven, _room, privateId: widget.privateId);
  }

  Future<void> _downloadImage(
      BuildContext context, types.Message message) async {
    var h = message.metadata?['header'] as Header?;
    var file = message.metadata?['file'] as File?;
    var stat = file?.statSync();
    if (file != null && stat?.size != h?.size) {
      var task = _safe.getFile(
          _bucket, h!.name, file.path, GetOptions(fileId: h.fileId));
      await progressDialog(context, "downloading image", task,
          errorMessage: "Cannot download image");
    }
  }

  void _handleMessageTap(BuildContext context, types.Message message) async {
    _touch();

    if (message is types.FileMessage) {
      if (message.uri.startsWith('library:/')) {
        var folder = message.uri.replaceFirst("library:/", "");
        var idx = folder.lastIndexOf('/');
        folder = idx == -1 ? "" : folder.substring(0, idx);

        //   Navigator.pushNamed(context, "/apps/library",
        //       arguments: LibraryArgs(_poolName, folder));
      }
    }
    if (message is types.ImageMessage) {
      await _downloadImage(context, message);
    }
  }

  void _handleMessageDownload(
      BuildContext context, types.Message message) async {
    _touch();

    if (message is types.ImageMessage) {
      await _downloadImage(context, message);
      var file = message.metadata?['file'] as File?;
      var name = message.name;
      if (file == null && mounted) {
        showPlatformSnackbar(context, "Image not yet downloaded",
            backgroundColor: Colors.red);
      }

      if (file != null && file.existsSync()) {
        if (isDesktop && mounted) {
          var filepath = ph.join(downloadFolder, name);
          file.copySync(filepath);
          showPlatformSnackbar(context, "Saved to $filepath");
        } else {
          var xfiles = [XFile(file.path)];
          Share.shareXFiles(xfiles);
        }
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
    _touch();

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

  // void _addMessage(types.Message message) {
  //   setState(() {
  //     _loaded.add(message.id);
  //     _messages.insert(0, message);
  //   });
  // }

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
          imageProviderBuilder: (
              {required conditional, required imageHeaders, required uri}) {
            return UniqueFileImage(File(uri));
          },
          onAttachmentPressed: () {
            _handleAttachmentPressed(context);
          },
          onMessageTap: _handleMessageTap,
          onMessageLongPress: _handleMessageDownload,
          onMessageDoubleTap: _handleMessageDownload,
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
