import 'package:behemoth/common/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class Status extends StatelessWidget {
  final Coven _coven;

  const Status(this._coven, {super.key});

  Widget _getBody(BuildContext context) {
    if (!_coven.isOpen) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
          ),
          Icon(Icons.error),
          SizedBox(
            height: 20,
          ),
          Text("Non connected yet",
              style: TextStyle(color: Colors.red, fontSize: 16)),
          Spacer(),
        ],
      );
    }

    var safe = _coven.safe;

    if (!safe.connected) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
          ),
          Icon(Icons.link_off),
          SizedBox(
            height: 20,
          ),
          Text("Non connected yet",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          Spacer(),
        ],
      );
    }

    if (safe.connected && safe.permission == 0) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
          ),
          Icon(Icons.link_off),
          SizedBox(
            height: 20,
          ),
          Text("Waiting for Admin to approve",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          Spacer(),
        ],
      );
    }

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Spacer(),
        Icon(Icons.link),
        SizedBox(
          height: 20,
        ),
        Text(
          "Successfully connected",
          style: TextStyle(color: Colors.green, fontSize: 16),
        ),
        SizedBox(
          height: 10,
        ),
        Spacer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("State of ${_coven.name}"),
      ),
      body: Center(child: _getBody(context)),
    );
  }
}
