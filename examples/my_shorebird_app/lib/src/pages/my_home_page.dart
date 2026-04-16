import 'package:flutter/material.dart';
import 'package:my_shorebird_app/src/pages/list_page.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import '../../flavors.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(F.title),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.add))],
      ),
      body: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Text('Hello ${F.title}'),
            ElevatedButton(
              onPressed: () {
                FlutterExitPlugin.restartApp();
              },
              child: Text('重启'),
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
    );
  }
}
