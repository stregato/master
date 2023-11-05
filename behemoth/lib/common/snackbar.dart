import 'package:behemoth/common/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void showPlatformSnackbar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration? duration,
}) {
  if (isApple) {
    // Display a Cupertino-style Snackbar on iOS
    showCupertinoSnackbar(context, message,
        backgroundColor: backgroundColor, duration: duration);
  } else {
    // Display a Material-style Snackbar on Android
    showMaterialSnackbar(context, message,
        backgroundColor: backgroundColor, duration: duration);
  }
}

void showCupertinoSnackbar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration? duration,
}) {
  final overlayState = Overlay.of(context);

  OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (BuildContext context) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: CupertinoSnackbar(
          message: message,
          backgroundColor: backgroundColor ?? CupertinoColors.systemGrey,
        ),
      );
    },
  );

  overlayState.insert(overlayEntry);

  // Remove the overlay after a delay (e.g., 3 seconds)
  Future.delayed(duration ?? const Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}

void showMaterialSnackbar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration? duration,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );
}

class CupertinoSnackbar extends StatelessWidget {
  final String message;
  final Color backgroundColor;

  const CupertinoSnackbar({
    super.key,
    required this.message,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor.withOpacity(0.9),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                message,
                style: const TextStyle(color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Example usage:
// showPlatformSnackbar(context, 'This is a customized Snackbar', backgroundColor: Colors.blue);
