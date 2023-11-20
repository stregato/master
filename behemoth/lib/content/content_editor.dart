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

  Future<bool> loadMarkdownContent() async {
    if (_textEditingController != null) {
      return true;
    }
    setState(() {
      _textEditingController = TextEditingController(
          text: _markdownFile.existsSync()
              ? _markdownFile.readAsStringSync()
              : '_Click on Edit_');
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
        trailingActions: [
          PlatformIconButton(
            onPressed: () => saveMarkdownContent(context),
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SafeArea(
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
                    Column(
                      children: [
                        Expanded(
                          child: PlatformTextField(
                            controller: _textEditingController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Expanded(
                          child: Markdown(data: _textEditingController!.text),
                        ),
                      ],
                    ),
                  ])
                : const CatProgressIndicator('Loading file...');
          },
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
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_document), label: "Preview+Edit"),
        ],
      ),
    );
  }
}
