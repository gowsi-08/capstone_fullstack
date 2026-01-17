import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({Key? key}) : super(key: key);

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  List<String> _results = [];

  void _onTextChanged(String q, AppState state) {
    final lower = q.toLowerCase();
    final keys = state.roomPositions.keys;
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final matches = keys.where((k) => k.toLowerCase().contains(lower)).toList();
    setState(() => _results = matches);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _controller,
            onChanged: (v) => _onTextChanged(v, state),
            decoration: const InputDecoration(
              hintText: 'Search destination (e.g., Network LAB)',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // Search results
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    // select destination in provider
                    context.read<AppState>().setSelectedDestination(item);
                    // clear results and search text
                    setState(() {
                      _controller.clear();
                      _results = [];
                    });
                    // optionally close keyboard
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
