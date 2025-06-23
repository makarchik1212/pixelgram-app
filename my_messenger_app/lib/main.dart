import 'package:flutter/material.dart';

void main() {
  runApp(const MyMessengerApp());
}

class MyMessengerApp extends StatelessWidget {
  const MyMessengerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой мессенджер',
      home: MessengerHome(),
    );
  }
}

class MessengerHome extends StatefulWidget {
  @override
  _MessengerHomeState createState() => _MessengerHomeState();
}

class _MessengerHomeState extends State<MessengerHome> {
  final TextEditingController _friendNumberController = TextEditingController();
  final List<String> messages = [];

  void _addFriend() {
    final friendNumber = _friendNumberController.text.trim();
    if (friendNumber.isNotEmpty) {
      setState(() {
        messages.add('Добавлен друг с номером: $friendNumber');
        _friendNumberController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мой мессенджер'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _friendNumberController,
              decoration: InputDecoration(
                labelText: 'Номер друга',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addFriend,
              child: const Text('Добавить друга'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  return ListTile(
                    title: Text(messages[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

