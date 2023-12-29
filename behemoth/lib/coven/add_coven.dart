import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class AddCoven extends StatelessWidget {
  const AddCoven({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text("Add Coven"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: PlatformElevatedButton(
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
                child: PlatformElevatedButton(
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
      //bottomNavigationBar: const NewsNavigationBar(),
    );
  }
}
