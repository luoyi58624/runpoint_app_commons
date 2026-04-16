import 'dart:async';

import 'package:el_dart/el_dart.dart';
import 'package:el_flutter/el_flutter.dart';
import 'package:el_ui/el_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_plugin/flutter_exit_plugin.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

final ShorebirdUpdater _updater = ShorebirdUpdater();
bool _updating = false;

Future<void> $shorebirdUpdate(
  BuildContext context,
  UpdateTrack track,
  String downloadedTitle,
  String downloadedContent,
  String restartNowText,
  String laterText,
  bool showHint,
) async {
  void showPromat() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(downloadedTitle),
          content: Text(downloadedContent),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(laterText)),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FlutterExitPlugin.restartApp();
              },
              child: Text(restartNowText),
            ),
          ],
        );
      },
    );
  }

  if (_updating) return;
  if (!_updater.isAvailable) return;

  _updating = true;
  try {
    UpdateStatus status = await _updater.checkForUpdate(track: track);

    el.message.primary(status.name);

    // 若存在更新，则发起更新请求
    bool updateSuccess = false;
    if (status == UpdateStatus.outdated) {
      await _updater.update(track: track);
      updateSuccess = true;
    }

    // 如果更新成功、或者更新是待重启，则显示弹窗提示用户重启
    if (updateSuccess || status == UpdateStatus.restartRequired) {
      if (!context.mounted) return;
      if (!showHint) return;

      showPromat();
    }
  } catch (e) {
    ElLog.w((e));
  } finally {
    _updating = false;
  }
}
