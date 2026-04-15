library;

import 'dart:io';

import 'src/patch.dart' as impl_patch;
import 'src/release.dart' as impl_release;

/// 运行基于 Shorebird 热更新的版本发布脚本
///
/// * 发布包请添加 --action release
/// * 发布补丁请添加 --action patch
///
/// 提示：这个库只适用于 runpoint-web-h5 项目，此项目不仅要区分 sit、prod 等环境包，
/// 还要支持 prod 打多个不同的渠道包，每个渠道包对应一个邀请码，例如：10001、10002、20001、20002，
/// 对于这种需求，此方法的作用是统一 release 输出所有渠道包到 dist 文件夹下，每个渠道包的版本号以 10000 为基准，
/// 发布到 Shorebird 热更新平台，后续每进行一次 release 整包更新，所有包的版本号均 +1，
/// 例如：10001、20001、30001、40001，而 patch 则统一对所有渠道包打补丁。
///
/// 如何使用？创建一个 scripts 目录，添加一个 dart 文件、和一个 version.json 版本配置文件，
/// dart 文件只需要写入以下内容即可：
/// ```dart
/// Future<void> main(List<String> args) => runShorebirdRelease(args);
/// ```
/// 而 version.json 可以参照本库的模板填写即可。
///
/// 运行示例：
/// * dart run ./scripts/release.dart --action=patch --flavor=sit
/// * dart run ./scripts/release.dart --action=release --flavor=sit
/// * dart run ./scripts/release.dart --action=patch --flavor=prod
/// * dart run ./scripts/release.dart --action=release --flavor=prod
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
    stderr.writeln(
      '用法: dart run ./scripts/run.dart --action=<release|patch> --flavor=<sit|prod> [args...]',
    );
    exit(1);
  }

  if (action == 'release') {
    await impl_release.run(rest);
  } else {
    await impl_patch.run(rest);
  }
}
