import 'dart:async';

import 'package:margarita/woland/woland.dart';
import 'package:flutter/material.dart';

Future<T?> progressDialog<T>(
    BuildContext context, String message, Future<T> task,
    {String? successMessage,
    String? errorMessage,
    Function()? getProgress,
    bool catchException = true}) async {
  return showDialog(
      context: context,
      builder: (_) => FutureBuilder(
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                Navigator.pop(context, snapshot.data);
                return Container();
              } else if (snapshot.hasError) {
                Navigator.pop(context, snapshot.error);
                return Container();
              } else if (snapshot.connectionState == ConnectionState.done) {
                Navigator.pop(context);
                return Container();
              } else {
                return ProgressDialog(message, getProgress);
              }
            },
            future: task,
          )).onError((error, stackTrace) {
    if (successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green, content: Text(successMessage)));
    }
    return null;
  }).then((value) {
    if (value is CException || value is Error) {
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content: Text("$errorMessage: $value")));
      }
      if (catchException) {
        return null;
      } else {
        throw value;
      }
    }
    if (successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green, content: Text(successMessage)));
    }
    return value;
  });
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
  double? _progress;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    if (widget.getProgress != null) {
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (Timer t) => setState(() {
          if (widget.getProgress != null) {
            var getProgress = widget.getProgress!;
            _progress = getProgress();
          }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The loading indicator
            CircularProgressIndicator(value: _progress),
            const SizedBox(
              height: 15,
            ),
            // Some text
            Text(widget.message)
          ],
        ),
      ),
    );
  }
}
