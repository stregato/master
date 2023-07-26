//import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:margarita/woland/woland.dart' as sp;

class Reset extends StatefulWidget {
  const Reset({Key? key}) : super(key: key);

  @override
  State<Reset> createState() => _Reset();
}

class _Reset extends State<Reset> {
  int _fullReset = 5;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.all(14)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Major Issue"),
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                "Possible corrupted database. You can try a factory reset"),
            const SizedBox(
              height: 14,
            ),
            ElevatedButton.icon(
                style: buttonStyle,
                label: Text("Factory Reset (click $_fullReset times)"),
                icon: const Icon(Icons.restore),
                onPressed: () => setState(() {
                      if (_fullReset == 0) {
                        sp.factoryReset();
                        _fullReset = 5;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                backgroundColor: Colors.green,
                                content:
                                    Text("Full Reset completed! Good luck")));
                        Navigator.pushReplacementNamed(context, "/setup");
                      } else {
                        _fullReset--;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: Colors.red,
                            duration: const Duration(milliseconds: 300),
                            content:
                                Text("$_fullReset clicks to factory reset!")));
                      }
                    })),
          ],
        ),
      ),
    );
  }
}
