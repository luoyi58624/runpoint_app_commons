import 'package:android_package_installer/android_package_installer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

/// App 更新
Future<void> appUpdate(
  BuildContext context, {
  required String downloadUrl,
  bool force = false,
}) async {
  final dir = await getTemporaryDirectory();
  if (!context.mounted) return;
  final apkPath = p.join(dir.path, 'app_update.apk');

  final progress = ValueNotifier<_DownloadProgress>(
    _DownloadProgress.initial(),
  );
  final isDownloading = ValueNotifier<bool>(false);
  final errorText = ValueNotifier<String?>(null);
  CancelToken? cancelToken;
  var isDisposed = false;

  void safeSetDownloading(bool v) {
    if (isDisposed) return;
    isDownloading.value = v;
  }

  void safeSetError(String? v) {
    if (isDisposed) return;
    errorText.value = v;
  }

  void safeSetProgress(_DownloadProgress v) {
    if (isDisposed) return;
    progress.value = v;
  }

  String? validateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'Invalid download URL.';
    if (!uri.hasScheme) return 'Invalid download URL (missing scheme).';
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return 'Unsupported URL scheme: $scheme';
    }
    if (uri.host.isEmpty) return 'Invalid download URL (missing host).';
    return null;
  }

  Future<String?> preflightDownloadUrl(String url) async {
    final urlErr = validateUrl(url);
    if (urlErr != null) return urlErr;

    final dio = ElHttp.instance.dio;

    try {
      final r = await dio.head<dynamic>(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final cl = r.headers.value(Headers.contentLengthHeader);
      final contentLength = cl == null ? null : int.tryParse(cl);
      if (contentLength != null && contentLength <= 0) {
        return 'Invalid package size.';
      }

      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 405 && status != 501) {
        // Not a "method not allowed" style error -> treat as unreachable.
        return 'Package URL is not reachable (${status ?? e.type.name}).';
      }
    } catch (_) {
      // ignore and fall back
    }

    try {
      final r = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
          headers: const {'Range': 'bytes=0-0'},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (r.data == null || r.data!.isEmpty) {
        return 'Package URL is not reachable.';
      }
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      return 'Package URL is not reachable (${status ?? e.type.name}).';
    } catch (e) {
      return 'Package URL is not reachable ($e).';
    }
  }

  Future<void> startDownload(BuildContext dialogContext) async {
    if (isDownloading.value) return;
    safeSetDownloading(true);
    safeSetError(null);
    safeSetProgress(_DownloadProgress.initial());
    cancelToken = CancelToken();

    try {
      final preflightErr = await preflightDownloadUrl(downloadUrl);
      if (preflightErr != null) {
        safeSetError(preflightErr);
        return;
      }

      await ElHttp.instance.dio.download(
        downloadUrl,
        apkPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          safeSetProgress(
            _DownloadProgress(received: received, total: total),
          );
        },
      );

      if (dialogContext.mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }

      await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      SystemNavigator.pop();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      safeSetError('Download failed: ${e.message ?? e.type.name}');
    } catch (e) {
      safeSetError('Update failed: $e');
    } finally {
      safeSetDownloading(false);
      cancelToken = null;
    }
  }

  final dialogClosed = showDialog<void>(
    context: context,
    barrierDismissible: !force,
    useRootNavigator: true,
    builder: (context) {
      return PopScope(
        canPop: !force,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && !force && isDownloading.value) {
            cancelToken?.cancel('User cancelled');
          }
        },
        child: AlertDialog(
          title: const Text('New Version'),
          content: SizedBox(
            width: 320,
            child: ValueListenableBuilder<bool>(
              valueListenable: isDownloading,
              builder: (context, downloading, _) {
                if (!downloading) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: errorText,
                    builder: (context, err, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You need to update it immediately in order to continue using it.',
                          ),
                          if (err != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              err,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                }

                return ValueListenableBuilder<_DownloadProgress>(
                  valueListenable: progress,
                  builder: (context, p, _) {
                    final ratio = p.ratio;
                    final percentText = ratio == null
                        ? '...'
                        : '${(ratio * 100).toStringAsFixed(0)}%';
                    final detailText = p.detailText;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Downloading...'),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          percentText,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detailText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: isDownloading,
              builder: (context, downloading, _) {
                if (downloading) {
                  if (force) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: () {
                      cancelToken?.cancel('User cancelled');
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    child: const Text('Cancel'),
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!force)
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('Cancel'),
                      ),
                    TextButton(
                      onPressed: () => startDownload(context),
                      child: const Text('Update'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );

  try {
    await dialogClosed;
  } finally {
    isDisposed = true;
    progress.dispose();
    isDownloading.dispose();
    errorText.dispose();
  }
}

class _DownloadProgress {
  const _DownloadProgress({required this.received, required this.total});

  factory _DownloadProgress.initial() =>
      const _DownloadProgress(received: 0, total: -1);

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
