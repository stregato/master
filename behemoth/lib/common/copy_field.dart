import 'package:flutter/material.dart';
import 'package:behemoth/common/share_data.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class CopyField extends StatelessWidget {
  final String _label;
  final String _value;
  const CopyField(this._label, this._value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PlatformTextField(
            readOnly: true,
            material: (context, platform) => MaterialTextFieldData(
              decoration: InputDecoration(
                labelText: _label,
                border: const OutlineInputBorder(),
              ),
            ),
            controller: TextEditingController(text: _value),
          ),
        ),
        PlatformIconButton(
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
