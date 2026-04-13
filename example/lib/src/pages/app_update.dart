import 'package:android_package_installer/android_package_installer.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

final http = ElHttp(options: BaseOptions(baseUrl: 'http://192.168.1.67:8087'));

class AppUpdatePage extends StatelessWidget {
  const AppUpdatePage({super.key});

  Future<void> _downloadAndInstallApk(BuildContext context) async {
    final dir = await getTemporaryDirectory();
    if (!context.mounted) return;
    final apkPath = p.join(dir.path, 'app_update.apk');

    final cancelToken = CancelToken();
    final progress = ValueNotifier<_DownloadProgress>(_DownloadProgress.initial());

    final downloadFuture = http.dio.download(
      '/uploads/app.apk',
      apkPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        progress.value = _DownloadProgress(received: received, total: total);
      },
    );

    final dialogClosed = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Downloading'),
          content: ValueListenableBuilder<_DownloadProgress>(
            valueListenable: progress,
            builder: (context, p, _) {
              final ratio = p.ratio;
              final percentText = ratio == null ? '...' : '${(ratio * 100).toStringAsFixed(0)}%';
              final detailText = p.detailText;
              return SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 12),
                    Text(percentText, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(detailText, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!cancelToken.isCancelled) cancelToken.cancel('User cancelled');
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    try {
      await downloadFuture;
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialogClosed;

      final statusCode = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
      if (statusCode != null) {
        final installationStatus = PackageInstallerStatus.byCode(statusCode);
        // ignore: avoid_print
        print(installationStatus.name);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.message ?? e.type.name}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      progress.dispose();
    }
  }

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
              if (!context.mounted) return;

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
                          context.pop();
                          await _downloadAndInstallApk(context);
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

class _DownloadProgress {
  const _DownloadProgress({required this.received, required this.total});

  factory _DownloadProgress.initial() => const _DownloadProgress(received: 0, total: -1);

  final int received;
  final int total;

  double? get ratio {
    if (total <= 0) return null;
    final v = received / total;
    if (v.isNaN || v.isInfinite) return null;
    return v.clamp(0, 1);
  }

  String get detailText {
    if (total <= 0) return '${_fmtBytes(received)} / ...';
    return '${_fmtBytes(received)} / ${_fmtBytes(total)}';
  }

  static String _fmtBytes(int bytes) {
    const k = 1024.0;
    final b = bytes.toDouble();
    if (b < k) return '$bytes B';
    final kb = b / k;
    if (kb < k) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / k;
    if (mb < k) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / k;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
