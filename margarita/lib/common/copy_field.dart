import 'package:flutter/material.dart';
import 'package:margarita/common/share_data.dart';

class CopyField extends StatelessWidget {
  final String _label;
  final String _value;
  const CopyField(this._label, this._value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: _label,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _value),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ShareData(_label, _value)));
          },
        ),
      ],
    );
  }
}
