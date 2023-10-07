import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:numpad/numpad.dart';

class Pad extends StatefulWidget {
  final void Function(Int) onSelect;

  const Pad(this.onSelect, {super.key});

  @override
  State<Pad> createState() => _PadState();
}

class _PadState extends State<Pad> {
  String _code = "";
  bool _invalid = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        if (_invalid) const Text("Invalid or expired code"),
        NumPad(
          textStyle: const TextStyle(
            fontSize: 18,
          ),
          onTap: (val) {
            if (val == 99 && _code.isNotEmpty) {
              setState(() {
                _code = _code.substring(0, _code.length - 1);
              });
            }
            if (val != 99 && _code.length < 5) {
              setState(() {
                _code = "$_code$val";
                _invalid = false;
              });
            }
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: ElevatedButton(
            onPressed: _code.length == 5
                ? () {
                    //widget.onSelect()
                  }
                : null,
            child: Text(
              "Connect to $_code",
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ],
    );
  }
}
