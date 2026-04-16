library;

import 'dart:io';

import 'src/patch.dart' as impl_patch;
import 'src/release.dart' as impl_release;

/// 运行基于 Shorebird 热更新的版本发布脚本，本库可以一键打包所有渠道 apk、一键发布所有渠道补丁，
/// 如果有一个包运行失败，重新运行会跳过已成功发布的渠道包。
///
/// 如何使用？在项目 scripts 目录中，添加 dart、version.json 文件，version.json 可以参照模板修改，
/// dart 文件写入以下内容：
/// ```dart
/// Future<void> main(List<String> args) => runShorebirdRelease(args);
/// ```
///
/// 执行命令：
/// * dart run ./scripts/release.dart --action=release --flavor=sit                  // 发布 sit 环境的所有渠道包
/// * dart run ./scripts/release.dart --action=patch --flavor=sit                    // 发布 sit 环境的所有补丁
/// * dart run ./scripts/release.dart --action=release --flavor=prod                 // 发布 prod 环境的所有渠道包
/// * dart run ./scripts/release.dart --action=patch --flavor=prod                   // 发布 prod 环境的所有补丁
///
/// 提示：若要对之前发布的版本打补丁，可以使用 --patch-version 参数：
/// * dart run ./scripts/release.dart --action=patch --flavor=sit --patch-version 1.0.1+1     // 发布所有渠道补丁
/// * dart run ./scripts/release.dart --action=patch --flavor=sit --patch-version 1.0.1+1001  // 发布目标渠道补丁
Future<void> runShorebirdRelease(List<String> args) async {
  String? action;
  final rest = <String>[];

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--action=')) {
      action = a.substring('--action='.length).trim();
      continue;
    }
    rest.add(a);
  }

  if (action != 'release' && action != 'patch') {
    stderr.writeln('用法: dart run ./scripts/run.dart --action=<release|patch> --flavor=<sit|prod> [args...]');
    exit(1);
  }

  if (action == 'release') {
    await impl_release.run(rest);
  } else {
    await impl_patch.run(rest);
  }
}
