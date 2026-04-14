import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import 'list_page.dart';

void main() {
  runApp(const MyApp());
}

final _navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', navigatorKey: _navigatorKey, home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final count = Obs(0);
  final config = Obs<Map>({});

  void readJson() async {
    String jsonString = await rootBundle.loadString("assets/config.json");
    config.value = jsonDecode(jsonString);
  }

  @override
  void initState() {
    super.initState();
    readJson();
    // 启动后手动触发一次更新检查（避免阻塞首帧渲染）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      AppUpdateUtil.checkShorebirdUpdate(ctx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ObsBuilder(
          builder: (context) {
            return Text('Home - ${config.value['channel']}');
          },
        ),
        actionsPadding: .only(right: 8),
        actions: [
          IconButton(
            onPressed: () {
              count.value++;
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
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
              child: Text('列表页面'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FlutterExitPlugin.exitApp();
              },
              child: const Text('退出'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await FlutterExitPlugin.restartApp();
              },
              child: const Text('重启'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          count.value--;
        },
        child: const Icon(Icons.remove),
      ),
    );
  }
}
