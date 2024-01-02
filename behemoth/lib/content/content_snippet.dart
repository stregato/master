import 'dart:convert';
import 'package:behemoth/woland/safe.dart';
import 'package:behemoth/woland/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ContentSnippet extends StatefulWidget {
  final Safe safe;
  final String bucket;
  final String name;
  const ContentSnippet(this.safe, this.bucket, this.name, {super.key});

  @override
  State<ContentSnippet> createState() => _ContentSnippetState();
}

class _ContentSnippetState extends State<ContentSnippet> {
  Future<String> loadMarkdownContent() async {
    Uint8List m = Uint8List(0);
    m = await widget.safe.getBytes(widget.bucket, widget.name, GetOptions());

    return utf8.decode(m);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: loadMarkdownContent(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading markdown'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 40.0,
              height: 40.0,
              child: CircularProgressIndicator(),
            ),
          );
        }
        var markdown = snapshot.data!;

        return Stack(
          children: <Widget>[
            Markdown(
              data: markdown,
              shrinkWrap: true,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () async {
                  var content = await Navigator.pushNamed(
                    context,
                    "/content/editor",
                    arguments: {
                      'title': 'Edit snippet',
                      'content': markdown,
                      'tabs': ['edit', 'preview'],
                    },
                  );

                  if (mounted &&
                      content != snapshot.data! &&
                      content != null &&
                      content is String) {
                    await widget.safe.putBytes(
                      widget.bucket,
                      widget.name,
                      utf8.encode(content),
                      PutOptions(),
                    );

                    setState(() {});
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
