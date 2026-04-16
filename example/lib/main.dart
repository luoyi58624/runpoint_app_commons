import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import 'list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  el.init();
  nextTick(() {
    AppUpdateUtil.shorebirdUpdate(el.context);
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', navigatorKey: el.navigatorKey, home: HomePage());
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
    String jsonString = await rootBundle.loadString("assets/config/channel.json");
    config.value = jsonDecode(jsonString);
    ElLog.i(config.value);
  }

  @override
  void initState() {
    super.initState();
    readJson();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ObsBuilder(
          builder: (context) {
            return Text('Home');
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
