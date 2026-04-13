import 'package:android_package_installer/android_package_installer.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

final http = ElHttp(options: BaseOptions(baseUrl: 'http://192.168.1.67:8087'));

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
              final result = await http.get('/version');

              if (El.compareNum(El.safeInt(info.buildNumber), El.safeInt(result['data']), .less)) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('New Version'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          context.pop();
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final dir = await getTemporaryDirectory();
                          final apkPath = p.join(dir.path, 'app_update.apk');
                          await http.dio.download('/uploads/app.apk', apkPath);
                          int? statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
                          if (statusCode != null) {
                            PackageInstallerStatus installationStatus = PackageInstallerStatus.byCode(statusCode);
                            print(installationStatus.name);
                          }
                        },
                        child: Text('Update'),
                      ),
                    ],
                  ),
                );
              }
            },
            icon: Icon(Icons.download),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(onPressed: () {}, child: Text('hello')),
      ),
    );
  }
}
