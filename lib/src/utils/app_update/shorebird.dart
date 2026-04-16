import 'dart:async';

import 'package:el_dart/el_dart.dart';
import 'package:el_flutter/el_flutter.dart';
import 'package:el_ui/el_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_plugin/flutter_exit_plugin.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

final ShorebirdUpdater _updater = ShorebirdUpdater();
bool _updating = false;

final RegExp _autoUpdateFalse = RegExp(r'^auto_update\s*:\s*false\s*$', caseSensitive: false);

/// 与工程根目录 `shorebird.yaml` 中 `auto_update: false` 一致：未注释的显式关闭才视为手动补丁模式。
bool _shorebirdYamlDeclaresAutoUpdateFalse(String content) {
  for (final fullLine in content.split('\n')) {
    var line = fullLine.trimLeft();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    final inlineComment = line.indexOf(' #');
    if (inlineComment != -1) {
      line = line.substring(0, inlineComment).trimRight();
    }
    if (_autoUpdateFalse.hasMatch(line.trim())) return true;
  }
  return false;
}

/// 从打包资源读取 `shorebird.yaml`；读取失败时按「需手动触发补丁」处理，避免未配置资源时永远不装补丁。
Future<bool> _shorebirdManualPatchMode() async {
  try {
    final raw = await rootBundle.loadString('shorebird.yaml');
    return _shorebirdYamlDeclaresAutoUpdateFalse(raw);
  } catch (_) {
    return true;
  }
}

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
    final manualPatch = await _shorebirdManualPatchMode();

    if (manualPatch) {
      final status = await _updater.checkForUpdate(track: track);

      el.message.primary(status.name);

      var updateSuccess = false;
      if (status == UpdateStatus.outdated) {
        await _updater.update(track: track);
        updateSuccess = true;
      }

      if (updateSuccess || status == UpdateStatus.restartRequired) {
        if (!context.mounted) return;
        if (!showHint) return;
        showPromat();
      }
    } else {
      for (var i = 0; i < 3; i++) {
        if (!context.mounted) return;
        final status = await _updater.checkForUpdate(track: track);

        el.message.primary(status.name);

        if (status == UpdateStatus.restartRequired) {
          if (!context.mounted) return;
          if (!showHint) return;
          showPromat();
          return;
        }
        if (i < 2) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      }
    }
  } catch (e) {
    ElLog.w((e));
  } finally {
    _updating = false;
  }
}
