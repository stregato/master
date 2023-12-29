import 'package:flutter/material.dart';

class CatProgressIndicator extends StatelessWidget {
  final String message;
  const CatProgressIndicator(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons8-waiting-cat.gif',
                width: 200, // Adjust the width and height as needed
              ),
              const SizedBox(
                  height: 30), // Adjust the spacing between the image and text
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
