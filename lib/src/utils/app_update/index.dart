import 'package:flutter/widgets.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'apk_update.dart';
import 'shorebird.dart';

class AppUpdateUtil {
  AppUpdateUtil._();

  /// 从服务端下载 apk 进行整包更新
  static Future<void> apkUpdate(BuildContext context, {required String downloadUrl, bool force = false}) async =>
      $apkUpdate(context, downloadUrl, force);

  /// 安装 shorebird 热更新补丁
  static Future<void> shorebirdUpdate(
    BuildContext context, {
    UpdateTrack track = UpdateTrack.stable,
    String downloadedTitle = 'Update Finish',
    String downloadedContent = 'The patch has been downloaded. Do you want to restart?',
    String restartNowText = 'Restart Now',
    String laterText = 'Later',
    bool showHint = true,
  }) async =>
      $shorebirdUpdate(context, track, downloadedTitle, downloadedContent, restartNowText, laterText, showHint);
}
