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
/// 正常 release（不传 `--target-version`）会自动递增版本号，并在成功后写回 version.json。
/// 使用 `--target-version` 的 release 不会修改 version.json（仅可能写入 version-temp.json 用于断点续跑进度）。
///
/// 指定远程版本发 patch / 补发 release 时，使用 `--target-version x.y.z+xx`（与 Shorebird 远程 release 版本一致）：
/// * 仅 `--target-version`：对所有渠道；每个渠道实际版本号为 `x.y.z+(该渠道 version-id+xx)`。
/// * `--target-version` 且 `--version-id <id>`：只发布 `version.json` 中 `version-id` 等于 `<id>` 的那一个渠道。
/// * 仅 `--version-id` 而没有 `--target-version`：报错。
/// * `xx` 必须小于等于 `version.json` 里该 flavor 的 `build-number`（不允许发尚未发版的更高 xx）。
///
/// 示例：
/// * dart run ./scripts/release.dart --action=patch --flavor=sit --target-version 1.0.0+0
/// * dart run ./scripts/release.dart --action=patch --flavor=sit --target-version 1.0.0+0 --version-id 10000
/// * dart run ./scripts/release.dart --action=release --flavor=sit --target-version 1.0.0+0
/// * dart run ./scripts/release.dart --action=release --flavor=sit --target-version 1.0.0+0 --version-id 10000
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
