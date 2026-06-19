import 'package:flutter/material.dart';

class AddressInput extends StatefulWidget {
  final Function(String) onSearch;

  const AddressInput({super.key, required this.onSearch});

  @override
  State<AddressInput> createState() => _AddressInputState();
}

class _AddressInputState extends State<AddressInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Enter Eircode (e.g., D02 X123)',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blueAccent),
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  widget.onSearch(_controller.text.trim());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}