import 'package:flutter/material.dart';

import 'package:behemoth/woland/woland_def.dart';

class AutocompleteIdentity extends StatelessWidget {
  final List<Identity> identities;
  final void Function(Identity identity) onSelect;

  const AutocompleteIdentity(
      {super.key, required this.identities, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Identity>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        return identities.where((identity) =>
            identity.nick.contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (identity) {
        onSelect(
            identity); // Call the onSelect callback with the selected identity
      },
      displayStringForOption: (identity) => identity.nick,
      fieldViewBuilder: (BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Type the name of a person',
          ),
        );
      },
      optionsViewBuilder: (BuildContext context,
          AutocompleteOnSelected<Identity> onSelected,
          Iterable<Identity> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              height: 200,
              child: ListView(
                children: options
                    .map((identity) => ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(identity.nick,
                                  style: const TextStyle(fontSize: 18)),
                              Text('${identity.id.substring(0, 16)}...',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              if (identity.email.isNotEmpty)
                                Text(identity.email,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.blue)),
                            ],
                          ),
                          trailing: CircleAvatar(
                            backgroundImage: MemoryImage(identity.avatar),
                          ),
                          onTap: () {
                            onSelected(identity);
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
