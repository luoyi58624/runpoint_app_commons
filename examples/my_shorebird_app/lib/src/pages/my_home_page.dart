import 'package:flutter/material.dart';
import 'package:my_shorebird_app/src/pages/list_page.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import '../../flavors.dart';

class MyHomePage extends HookWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final count = useObs(0);
    return Scaffold(
      appBar: AppBar(
        title: Text(F.title),
        actions: [
          IconButton(
            onPressed: () {
              count.value++;
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Text('Hello ${F.title}'),
            ElevatedButton(
              onPressed: () {
                count.value++;
              },
              child: ObsBuilder(
                builder: (context) {
                  return Text('count: ${count.value}');
                },
              ),
            ),
            TextButton(
              onPressed: () {
                count.value++;
              },
              child: ObsBuilder(
                builder: (context) {
                  return Text('count: ${count.value}');
                },
              ),
            ),
            FilledButton(
              onPressed: () {
                count.value++;
              },
              child: ObsBuilder(
                builder: (context) {
                  return Text('count: ${count.value}');
                },
              ),
            ),
            OutlinedButton(
              onPressed: () {
                count.value++;
              },
              child: ObsBuilder(
                builder: (context) {
                  return Text('count: ${count.value}');
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => ListPage()));
              },
              child: Text('列表'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          count.value--;
        },
        child: Icon(Icons.remove),
      ),
    );
  }
}
