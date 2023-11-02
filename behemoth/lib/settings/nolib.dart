import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoLib extends StatelessWidget {
  final String err;
  const NoLib(this.err, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Icon(
            Icons.heart_broken,
            size: 100.0, // Adjust the size as needed
            color: Colors.red, // You can change the color
          ),
          const SizedBox(height: 16.0),
          const Text(
            'No Woland inside',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 24.0), // Add spacing
          ElevatedButton(
            onPressed: () {
              // Close the application
              SystemNavigator.pop();
            },
            child: const Text('Quit'),
          ),
          const Spacer(),
          Text(err,
              style: const TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey,
                  decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}
