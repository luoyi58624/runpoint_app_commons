import 'dart:async';

import 'package:el_dart/el_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_plugin/flutter_exit_plugin.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

final ShorebirdUpdater _updater = ShorebirdUpdater();
bool _updating = false;

Future<void> $checkShorebirdUpdate(
  BuildContext context,
  UpdateTrack track,
  String downloadedTitle,
  String downloadedContent,
  String restartNowText,
  String laterText,
) async {
  if (_updating) return;
  if (!_updater.isAvailable) return;

  _updating = true;
  try {
    final status = await _updater.checkForUpdate(track: track);
    if (status != UpdateStatus.outdated) return;

    await _updater.update(track: track);

    if (!context.mounted) return;

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
