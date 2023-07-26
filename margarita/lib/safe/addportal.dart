import 'package:margarita/navigation/bar.dart';
import 'package:flutter/material.dart';

class AddPortal extends StatelessWidget {
  const AddPortal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Portal"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, "/addPortal/add");
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(height: 20),
                      Icon(Icons.join_full),
                      SizedBox(height: 10),
                      Text("Add Existing"),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, "/addPortal/create");
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(height: 20),
                      Icon(Icons.create),
                      SizedBox(height: 10),
                      Text("Create"),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: const MainNavigationBar(null),
    );
  }
}
