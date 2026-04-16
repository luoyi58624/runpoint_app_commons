import 'dart:io';

import 'common.dart';
import 'models.dart';
import 'summary.dart';

Future<void> run(List<String> args) async {
  final parsed = parseFlavorArgs(args);
  final flavor = parsed.flavor;
  args = parsed.restArgs;
  final parsedTargetVersion = parseTargetVersionArgs(args);
  final overrideName = parsedTargetVersion.versionName;
  final overrideBuild = parsedTargetVersion.buildNumber;
  args = parsedTargetVersion.restArgs;
  final c = ctx();

  final root = readJsonFile(c.versionJson);
  final raw = root[flavor];
  if (raw is! Map) {
    stderr.writeln('version.json 缺少 flavor=$flavor 的配置节点');
    exit(1);
  }
  final cfg = FlavorModel.fromJson(Map<String, dynamic>.from(raw));
  final currentName = cfg.versionName.trim();
  final name = (overrideName ?? currentName).trim();
  if (name.isEmpty) {
    stderr.writeln('version.json 中 version-name 不能为空');
    exit(1);
  }
  final cfgBuild = cfg.buildNumber;
  // 规则：
  // - 若传了 --target-version x.y.z+xx 且 xx > version.json 的 build-number，则认为 xx 是“绝对 release code”，只发布 1 个补丁：x.y.z+xx
  // - 否则认为 xx 是 build-number（可覆盖当前 build-number），按每个渠道 version-id+xx 计算 release-version
  final isSinglePatch = overrideBuild != null && overrideBuild > cfgBuild;
  final build = isSinglePatch ? overrideBuild : (overrideBuild ?? cfgBuild);
  final channels = cfg.channelVersionIds();
  if (channels.isEmpty) {
    stderr.writeln('version.json 中 channels 不能为空（至少一个渠道）');
    exit(1);
  }
  final isDryRun = args.contains('--dry-run') || args.contains('-n');

  final summary = Summary();
  const singleKey = '__single__';
  final channelsToProcess = isSinglePatch ? <String, int>{singleKey: 0} : channels;
  final total = channelsToProcess.length;

  final progressKey = 'patch-progress';
  final expectedProgressId = '$name+$build';
  final tempRoot = readJsonFile(c.versionTempJson);
  final tempSec = getOrCreateFlavorSection(tempRoot, flavor);
  final progress = (tempSec[progressKey] is Map)
      ? (tempSec[progressKey] as Map)
      : null;
  final progressId = progress?['id']?.toString() ?? '';
  final completed = <String>{
    if (progressId == expectedProgressId &&
        progress?['completed-channels'] is List)
      ...(progress!['completed-channels'] as List).map((e) => e.toString()),
  };

  for (final entry in channelsToProcess.entries) {
    final ch = entry.key;
    final base = entry.value;
    final releaseVersion =
        isSinglePatch ? '$name+$build' : '$name+${base + build}';

    if (!isDryRun && completed.contains(ch)) {
      stdout.writeln('已完成，跳过: channel=$ch release-version=$releaseVersion');
      summary.skipped++;
      continue;
    }

    stdout.writeln(
      '---- patch channel=${isSinglePatch ? "(single)" : ch} release-version=$releaseVersion ----',
    );
    final patchArgs = <String>[
      'patch',
      'android',
      '--flavor',
      flavor,
      '--release-version',
      releaseVersion,
      if (!isSinglePatch) ...[
        '--dart-define',
        'channel=$ch',
      ],
      if (isDryRun) '--dry-run',
      '--',
      '--no-tree-shake-icons',
    ];

    stdout.writeln('> ${formatCliCommand("shorebird", patchArgs)}');
    final result = await runShorebirdCapture(
      patchArgs,
      workingDirectory: c.repoRoot.path,
      echo: true,
    );
    final codeExit = result.exitCode;

    if (codeExit != 0) {
      final lower = result.output.toLowerCase();
      final missingRemoteTarget = lower.contains('release not found:') ||
          lower.contains('patches can only be published for existing releases.') ||
          lower.contains('channel not found') ||
          lower.contains('no channel') ||
          lower.contains('could not find channel');
      if (missingRemoteTarget) {
        stderr.writeln(
          '远程未找到目标渠道/版本，跳过继续: channel=$ch release-version=$releaseVersion exit=$codeExit',
        );
        summary.skipped++;
        continue;
      }
      if (result.output.contains('UnpatchableChangeException') ||
          result.output.contains('Your app contains asset changes')) {
        stderr.writeln('');
        stderr.writeln('检测到 Shorebird 服务端验证失败：存在 asset 变更，patch 无法发布。');
        stderr.writeln('这类变更无法通过 patch 下发，需要先创建新的 release。');
        stderr.writeln('');
        stderr.writeln(
          '请先执行：dart run ./scripts/run.dart --action=release --flavor=$flavor',
        );
        stderr.writeln(
          '然后再执行：dart run ./scripts/run.dart --action=patch --flavor=$flavor',
        );
        stderr.writeln('');
      }

      summary.failed++;
      summary.failedDetails.add(
        '渠道=$ch | release-version=$releaseVersion | exit=$codeExit',
      );
      stderr.writeln(
        'shorebird patch 失败: channel=$ch release-version=$releaseVersion exit=$codeExit',
      );
      summary.print(
        flavor: flavor,
        action: 'patch',
        total: total,
        isDryRun: isDryRun,
      );
      exit(codeExit);
    }

    summary.ok++;
    if (!isDryRun) {
      completed.add(ch);
      final tempRoot2 = readJsonFile(c.versionTempJson);
      final sec2 = getOrCreateFlavorSection(tempRoot2, flavor);
      sec2[progressKey] = <String, dynamic>{
        'id': expectedProgressId,
        'version-name': name,
        'build': build,
        'completed-channels': completed.toList()..sort(),
        'updated-at': DateTime.now().toUtc().toIso8601String(),
      };
      tempRoot2[flavor] = sec2;
      writeJsonFile(c.versionTempJson, tempRoot2);
    }
  }

  if (isDryRun) {
    stdout.writeln('patch dry-run 完成：未修改 ${c.versionJson.path}');
    summary.print(
      flavor: flavor,
      action: 'patch',
      total: total,
      isDryRun: isDryRun,
    );
    return;
  }

  // 清理断点续发进度
  final tempRoot2 = readJsonFile(c.versionTempJson);
  final tempSec2 = getOrCreateFlavorSection(tempRoot2, flavor);
  tempSec2.remove(progressKey);
  tempRoot2[flavor] = tempSec2;
  writeJsonFile(c.versionTempJson, tempRoot2);

  stdout.writeln(
    'patch 完成：flavor=$flavor（本次使用 build-number=$build，version-name=$name；不写回 version.json）',
  );
  summary.print(
    flavor: flavor,
    action: 'patch',
    total: total,
    isDryRun: isDryRun,
  );
}
