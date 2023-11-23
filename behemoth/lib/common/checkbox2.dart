import 'package:flutter/material.dart';

class CheckboxController extends ChangeNotifier {
  bool _isChecked;

  CheckboxController({bool initialValue = false}) : _isChecked = initialValue;

  bool get isChecked => _isChecked;

  set isChecked(bool newValue) {
    if (_isChecked != newValue) {
      _isChecked = newValue;
      notifyListeners();
    }
  }
}

class Checkbox2 extends StatefulWidget {
  final ValueChanged<bool> onChanged;
  final bool initialValue;

  const Checkbox2(
      {Key? key, required this.onChanged, this.initialValue = false})
      : super(key: key);

  @override
  State<Checkbox2> createState() => _Checkbox2State();
}

class _Checkbox2State extends State<Checkbox2> {
  late final CheckboxController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CheckboxController(initialValue: widget.initialValue);
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    widget.onChanged(_controller.isChecked);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    super.dispose();
  }

  CheckboxController get controller => _controller;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: _controller.isChecked,
      onChanged: (bool? newValue) {
        _controller.isChecked = newValue ?? false;
      },
    );
  }
}
