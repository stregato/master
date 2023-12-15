import 'dart:async';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

var _sentences = [
  "Manuscripts don't burn.",
  "Everything will turn out right",
  "Follow me, reader!",
  "Cowardice is the most terrible of vices.",
  "With the truth, one cannot live.",
  "One can never predict a cat.",
  "Happiness is the most insidious prison of all.",
];

Future<T?> progressDialog<T>(
    BuildContext context, String message, Future<T> task,
    {String? successMessage,
    String? errorMessage,
    Function()? getProgress,
    bool catchException = true}) async {
  var sentence = _sentences[DateTime.now().microsecond % _sentences.length];
  return showPlatformDialog(
      context: context,
      builder: (_) => FutureBuilder<T>(
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                Navigator.pop(context, snapshot.data);
                if (successMessage != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    showPlatformSnackbar(context, successMessage,
                        backgroundColor: Colors.green);
                  });
                }
              }
              if (snapshot.hasError) {
                Navigator.pop(context);
                if (errorMessage != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    showPlatformSnackbar(context, errorMessage,
                        backgroundColor: Colors.red);
                  });
                }
              }
              return PlatformScaffold(
                appBar: PlatformAppBar(
                  title: Text(sentence),
                ),
                body: CatProgressIndicator(message),
              );
            },
            future: task,
          ));
}

class ProgressDialog extends StatefulWidget {
  final String message;
  final Function? getProgress;
  const ProgressDialog(this.message, this.getProgress, {Key? key})
      : super(key: key);

  @override
  // ignore: no_logic_in_create_state
  State<ProgressDialog> createState() => ProgressState();
}

class ProgressState extends State<ProgressDialog> {
  //double? _progress;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    if (widget.getProgress != null) {
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (Timer t) => setState(() {
          // if (widget.getProgress != null) {
          //   var getProgress = widget.getProgress!;
          //   _progress = getProgress();
          // }
        }),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // The background color
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: CatProgressIndicator(widget.message),
      ),
    );
  }
}
