import 'dart:async';

import 'package:behemoth/common/cat_progress_indicator.dart';
import 'package:behemoth/common/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

Future<T?> progressDialog<T>(
    BuildContext context, String message, Future<T> task,
    {String? successMessage,
    String? errorMessage,
    Function()? getProgress,
    bool catchException = true}) async {
  return showPlatformDialog(
      context: context,
      builder: (_) => FutureBuilder<T>(
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (successMessage != null) {
                  Future.delayed(Duration.zero, () {
                    showPlatformSnackbar(context, successMessage,
                        backgroundColor: Colors.green);
                    Navigator.pop(context, snapshot.data);
                  });
                }
              }
              if (snapshot.hasError) {
                if (errorMessage != null) {
                  Future.delayed(Duration.zero, () {
                    showPlatformSnackbar(context, errorMessage,
                        backgroundColor: Colors.red);
                    Navigator.pop(context);
                  });
                }
              }
              return const CatProgressIndicator("Loading...");
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
