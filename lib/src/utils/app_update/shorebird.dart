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
  if (_updating) return;
  if (!_updater.isAvailable) return;

  _updating = true;
  try {
    el.message.show('检查热更新');
    final status = await _updater.checkForUpdate(track: track);
    if (status != UpdateStatus.outdated) return;

    el.message.primary('开始热更新');
    await _updater.update(track: track);

    el.message.success('update success');
    el.message.show('context: ${context.mounted}');

    if (!context.mounted) return;

    el.message.show('showHint: $showHint');
    if (!showHint) return;

    el.message.show('显示弹窗');
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
  } catch (e) {
    ElLog.w((e));
  } finally {
    _updating = false;
  }
}
