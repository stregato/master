import 'dart:io';
import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path/path.dart';

class ContentEditor extends StatefulWidget {
  const ContentEditor({super.key});

  @override
  State<ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<ContentEditor> {
  late File _markdownFile;
  TextEditingController? _textEditingController;
  bool _ready = false;
  int _currentPanelIdx = 0;
  bool _isDirty = false;

  Future<bool> loadMarkdownContent() async {
    if (_textEditingController != null) {
      return true;
    }
    setState(() {
      _textEditingController = TextEditingController(
          text: _markdownFile.existsSync()
              ? _markdownFile.readAsStringSync()
              : '_Click on Edit_');
      _textEditingController!.addListener(() {
        _isDirty = true;
      });
      _ready = true;
    });
    return true;
  }

  Future<void> saveMarkdownContent(BuildContext context) async {
    final String updatedContent = _textEditingController!.text;
    await _markdownFile.writeAsString(updatedContent);
    if (mounted) {
      showPlatformSnackbar(context, 'Markdown file saved.',
          backgroundColor: Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    var filename = args['filename'] ?? '';
    _markdownFile = File(filename);

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(basename(filename)),
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) {
            return;
          }
          if (!_isDirty) {
            Navigator.of(context).pop();
            return;
          }
          final result = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Save changes?'),
              content:
                  const Text('Do you want to save the changes before exiting?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop('discard'),
                  child: const Text('Discard'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('save'),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          if (result == 'save' && mounted) {
            saveMarkdownContent(context);
          }
          // If save or discard, pop the screen
          if (result != null && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: FutureBuilder<bool>(
            future: loadMarkdownContent(),
            builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
              return _ready
                  ? IndexedStack(index: _currentPanelIdx, children: [
                      Markdown(data: _textEditingController!.text),
                      Expanded(
                        child: PlatformTextField(
                          controller: _textEditingController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                    ])
                  : const CatProgressIndicator('Loading file...');
            },
          ),
        ),
      ),
      bottomNavBar: PlatformNavBar(
        currentIndex: _currentPanelIdx,
        itemChanged: (idx) {
          setState(() {
            _currentPanelIdx = idx;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.preview), label: "Preview"),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: "Edit"),
        ],
      ),
    );
  }
}
