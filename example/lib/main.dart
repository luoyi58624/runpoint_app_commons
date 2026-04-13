import 'package:flutter/material.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import 'src/pages/app_update.dart';

void main() async {
  await el.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          ListTileGroupWidget(children: [('App 更新', () => context.push(AppUpdatePage()))]),
        ],
      ),
    );
  }
}
