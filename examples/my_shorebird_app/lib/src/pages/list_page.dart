import 'package:flutter/material.dart';

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List Page')),
      body: ListView.builder(
        itemCount: 1000,
        itemBuilder: (context, index) => ListTile(onTap: () {}, title: Text('item - ${index + 1}')),
      ),
    );
  }
}
