import 'package:flutter/material.dart';

class RateMe extends StatefulWidget {
  final int initialCount;
  final bool hasRated;
  final Icon icon;
  final Color color;
  final Function(int, bool) onChanged;

  const RateMe({
    super.key,
    required this.initialCount,
    required this.hasRated,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  State<RateMe> createState() => _RateMeState();
}

class _RateMeState extends State<RateMe> {
  late int count;
  late bool hasRated;

  @override
  void initState() {
    super.initState();
    count = widget.initialCount;
    hasRated = widget.hasRated;
  }

  void _toggleRate() {
    setState(() {
      if (hasRated) {
        count--;
      } else {
        count++;
      }
      hasRated = !hasRated;
      widget.onChanged(count, hasRated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: widget.icon,
          color: hasRated ? widget.color : Colors.grey,
          onPressed: _toggleRate,
        ),
        Text('($count)'),
      ],
    );
  }
}
