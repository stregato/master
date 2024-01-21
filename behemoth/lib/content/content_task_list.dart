import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:behemoth/common/io.dart';
import 'package:behemoth/common/profile.dart';
import 'package:behemoth/content/task.dart';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

class ContentTaskList extends StatefulWidget {
  const ContentTaskList({super.key});

  @override
  State<ContentTaskList> createState() => _ContentTaskListState();
}

const itemsPerRead = 30;

class _ContentTaskListState extends State<ContentTaskList> {
  int _offset = 0;
  final List<Header> _headers = [];
  late Safe _safe;
  late String _room;
  List<String> _users = [];
  String _dir = "";
  final ScrollController _scrollController = ScrollController();
  final int _pending = 0;
  double _pos = 0.0;
  bool _noMore = false;
  final List<Header> _downloads = [];

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

  Future _read() async {
    var headers = _safe.listFiles(
        "rooms/$_room/content",
        ListOptions(
          dir: _dir,
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
      var found = _headers.where((h2) => h2.name == h.name);
      if (found.isNotEmpty) {
        continue;
      }
      try {
        var localpath =
            join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
        var localfile = File(localpath);
        if (!localfile.existsSync()) {
          _downloads.add(h);
        }
        _headers.add(h);
      } catch (e) {
        continue;
      }
    }
  }

  Future<void> _newTask(BuildContext context) async {
    var textController = TextEditingController();

    var action = await showPlatformDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Name of the task:"),
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
              child: const Text('Create'),
              onPressed: () async {
                if (mounted) {
                  Navigator.of(context).pop('create');
                }
              },
            ),
          ],
        );
      },
    );
    if (action == 'create' && mounted) {
      var name = "${textController.text}.task";
      var content =
          await Navigator.pushNamed(context, "/content/task", arguments: {
        'name': textController.text,
        'task': Task(issuer: _safe.currentUser.id),
        'users': _users,
        'create': true,
      });
      if (content != null && content is Task) {
        var d = join(documentsFolder, _safe.name, _room, _dir, name);
        File(d).writeAsStringSync(jsonEncode(content));
        var h = await _safe.putFile(
            "rooms/$_room/content", join(_dir, name), d, PutOptions());
        setState(() {
          _headers.insert(0, h);
        });
      }
    }
  }

  Widget _getTaskWidget(BuildContext context, Header h) {
    var title = basenameWithoutExtension(h.name);
    var localpath =
        join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
    try {
      var data = File(localpath).readAsStringSync();
      var task = Task.fromJson(jsonDecode(data));
      var assignedTo = getCachedIdentity(task.assigned);
      var dueDate = Text(DateFormat.MEd().format(task.dueDate),
          style: TextStyle(
              color:
                  (task.dueDate.isAfter(DateTime.now()) && task.state != "done")
                      ? Colors.red
                      : Colors.white));
      var trailing = Column(
        children: [dueDate, Text(task.priority)],
      );
      return ListTile(
        title: Text(title),
        subtitle: Text("${assignedTo.nick} - ${task.state}"),
        leading: assignedTo.avatar.isNotEmpty
            ? CircleAvatar(
                backgroundImage: MemoryImage(assignedTo.avatar),
              )
            : null,
        trailing: trailing,
        onTap: () async {
          var modified =
              await Navigator.pushNamed(context, "/content/task", arguments: {
            "name": basenameWithoutExtension(h.name),
            "task": task,
            "users": _users,
          });

          if (modified is Task) {
            File(localpath).writeAsStringSync(jsonEncode(modified));
            await _safe.putFile(
                "rooms/$_room/content", h.name, localpath, PutOptions());
          }
          _read();
        },
      );
    } catch (e) {
      return ListTile(
          title: Text(title),
          subtitle: const Text("Corrupted: click on the bin to delete"),
          trailing: IconButton(
              onPressed: () {
                File(localpath).deleteSync();
                h.deleted = true;
                _safe.patch("rooms/$_room/content", h, PatchOptions());
              },
              icon: const Icon(Icons.delete)));
    }
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
        var localpath =
            join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
        var stat = File(localpath).statSync();
        if (stat.type == FileSystemEntityType.notFound || stat.size != h.size) {
          return Card(
              elevation: 3.0,
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Row(
                  children: [
                    Text(basenameWithoutExtension(h.name)),
                    const Spacer(),
                    const CircularProgressIndicator(),
                  ],
                ),
              ));
        }

        return Card(
          elevation: 3.0,
          margin: const EdgeInsets.all(8.0),
          child: _getTaskWidget(context, h),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_pos);
      }
    });
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
      _users = _safe.getUsersSync().keys.toList();
      setState(() {
        _read();
      });
    }

    if (_downloads.isNotEmpty) {
      Future.delayed(Duration.zero, () async {
        for (var h in _downloads) {
          var localpath =
              join(documentsFolder, _safe.name, _room, _dir, basename(h.name));
          await _safe.getFile(
              "rooms/$_room/content", h.name, localpath, GetOptions());
          setState(() {});
        }
      });
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(basenameWithoutExtension(_dir),
            style: const TextStyle(fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                PlatformIconButton(
                    onPressed: () {
                      setState(() {
                        _offset = 0;
                        _headers.clear();
                        _noMore = false;
                        _read();
                      });
                    },
                    icon: const Icon(Icons.refresh)),
                const SizedBox(width: 10),
                PlatformIconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _newTask(context),
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
              child: _getListView(),
            ),
          ],
        ),
      ),
    );
  }
}
