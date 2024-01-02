import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class ContentEditor extends StatefulWidget {
  const ContentEditor({super.key});

  @override
  State<ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<ContentEditor> {
  TextEditingController? _textEditingController;
  String _content = '';
  int _currentPanelIdx = 0;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _content = args['content'] ?? '';
    var title = args['title'] ?? '';
    var tabs = args['tabs'] ?? <String>[];
    _textEditingController ??= TextEditingController(text: _content);

    var stack = <Widget>[];
    var navBar = <BottomNavigationBarItem>[];
    for (var tab in tabs) {
      if (tab == 'preview') {
        stack.add(
          Markdown(
            data: _textEditingController?.text ?? '',
            onTapText: () {
              setState(() {
                _currentPanelIdx = 1;
              });
            },
          ),
        );
        navBar.add(
          const BottomNavigationBarItem(
              icon: Icon(Icons.preview), label: "Preview"),
        );
      }
      if (tab == 'edit') {
        stack.add(
          Expanded(
            child: PlatformTextField(
              controller: _textEditingController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
        );
        navBar.add(
          const BottomNavigationBarItem(icon: Icon(Icons.edit), label: "Edit"),
        );
      }
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(title),
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) {
            return;
          }
          if (_content == _textEditingController?.text) {
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
            Navigator.of(context).pop(_textEditingController?.text);
            return;
          }
          if (result != null && mounted) {
            Navigator.of(context).pop(_content);
          }
        },
        child: SafeArea(
          child: IndexedStack(index: _currentPanelIdx, children: stack),
        ),
      ),
      bottomNavBar: navBar.length >= 2
          ? PlatformNavBar(
              currentIndex: _currentPanelIdx,
              itemChanged: (idx) {
                setState(() {
                  _currentPanelIdx = idx;
                });
              },
              items: navBar,
            )
          : null,
    );
  }
}
