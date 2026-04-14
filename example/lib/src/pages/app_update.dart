import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

class AppUpdatePage extends StatelessWidget {
  const AppUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Update'),
        actionsPadding: .only(right: 8),
        actions: [
          IconButton(
            onPressed: () async {
              final info = await PackageInfo.fromPlatform();
              final result = await ElHttp.instance.get('http://192.168.1.67:8087/version');
              if (!context.mounted) return;

              if (ElDartUtil.compareNum(info.buildNumber, result.data['data'], .less)) {
                await appUpdate(context, downloadUrl: 'http://192.168.1.67:8087/uploads/app.apk');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already up to date')));
              }
            },
            icon: Icon(Icons.download),
          ),
        ],
      ),
      // body: ListViewDemoWidget(),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('哈喽哈喽')));
      //   },
      //   child: Icon(Icons.add),
      // ),
    );
  }
}
