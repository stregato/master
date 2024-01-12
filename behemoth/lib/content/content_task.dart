import 'package:behemoth/common/profile.dart';
import 'package:behemoth/content/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class ContentTask extends StatefulWidget {
  const ContentTask({super.key});

  @override
  State<ContentTask> createState() => _ContentTaskState();
}

class _ContentTaskState extends State<ContentTask> {
  final _formKey = GlobalKey<FormState>();
  Task _task = Task(issuer: "");
  late List<String> _users;
  final _priorities = ['low', 'medium', 'high'];
  String _newComment = '';
  bool _isDirty = false;

  Widget _getBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            TextFormField(
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
              initialValue: _task.description,
              onChanged: (value) {
                setState(() {
                  _isDirty = true;
                  _task.description = value;
                });
              },
            ),
            DropdownButtonFormField(
              value: _task.assigned,
              decoration: const InputDecoration(labelText: 'Assigned'),
              items: [
                const DropdownMenuItem(value: "", child: Text("")),
                ..._users.map((String id) {
                  return DropdownMenuItem(
                      value: id, child: Text(getCachedIdentity(id).nick));
                })
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _isDirty = true;
                  _task.assigned = newValue!;
                });
              },
            ),
            TextFormField(
              initialValue: getCachedIdentity(_task.issuer).nick,
              decoration: const InputDecoration(labelText: 'Issuer'),
              readOnly: true,
            ),
            ButtonBar(
              alignment: MainAxisAlignment.start,
              children: <String>['todo', 'ongoing', 'done'].map((String state) {
                return ElevatedButton(
                  onPressed: () => setState(() {
                    _task.state = state;
                    _isDirty = true;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _task.state == state ? Colors.blue : Colors.grey,
                  ),
                  child: Text(state),
                );
              }).toList(),
            ),
            Row(children: [
              const Text("Complexity"),
              Expanded(
                child: Slider(
                  value: _task.complexity.toDouble(),
                  min: 1,
                  max: 21,
                  divisions: 20,
                  label: _task.complexity.round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _isDirty = true;
                      _task.complexity = value.round();
                    });
                  },
                ),
              ),
            ]),
            DropdownButtonFormField(
              value: _task.priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: _priorities.map((String priority) {
                return DropdownMenuItem(value: priority, child: Text(priority));
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _task.priority = newValue!;
                  _isDirty = true;
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Due Date'),
                    initialValue:
                        _task.dueDate.toLocal().toString().split(' ')[0],
                    readOnly: true,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _task.dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null && pickedDate != _task.dueDate) {
                      setState(() {
                        _task.dueDate = pickedDate;
                        _isDirty = true;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            ..._task.comments.map((comment) => ListTile(title: Text(comment))),
            Row(children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'New Comment'),
                  onSaved: (value) {
                    _newComment = value ?? '';
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    if (_newComment.isNotEmpty) {
                      setState(() {
                        _task.comments.add(_newComment);
                        _newComment = '';
                        _isDirty = true;
                      });
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    var title = args['name'] as String;
    _isDirty = args['create'] ?? false;
    if (_task.issuer.isEmpty) {
      _task = args['task'] as Task;
      _users = args['users'] as List<String>;
    }
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: TextFormField(
          initialValue: title,
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) {
            return;
          }

          if (!_isDirty) {
            Navigator.of(context).pop();
            return;
          }

          final result = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Save changes?'),
              content:
                  const Text('Do you want to save the changes before exiting?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop('discard'),
                  child: const Text('Discard'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('save'),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          if (result == 'save' && mounted) {
            Navigator.of(context).pop(_task);
          } else if (result != null && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: _getBody(context),
        ),
      ),
    );
  }
}
