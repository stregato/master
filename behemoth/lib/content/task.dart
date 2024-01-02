import 'package:intl/intl.dart';

class Task {
  String description;
  String assigned;
  String issuer;
  String state;
  int complexity;
  List<String> comments;
  String priority;
  DateTime dueDate;

  Task({
    required this.issuer,
    this.description = '',
    this.assigned = '',
    this.state = 'todo',
    this.complexity = 1,
    List<String>? comments,
    this.priority = 'medium',
    DateTime? dueDate,
  })  : comments = comments ?? [],
        dueDate = dueDate ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      description: json['description'],
      assigned: json['assigned'],
      issuer: json['issuer'],
      state: json['state'],
      complexity: json['complexity'],
      comments: List<String>.from(json['comments']),
      priority: json['priority'],
      dueDate: DateFormat('yyyy-MM-dd').parse(json['dueDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'assigned': assigned,
      'issuer': issuer,
      'state': state,
      'complexity': complexity,
      'comments': comments,
      'priority': priority,
      'dueDate': DateFormat('yyyy-MM-dd').format(dueDate),
    };
  }
}
