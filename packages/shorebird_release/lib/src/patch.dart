import 'dart:io';

import 'common.dart';
import 'models.dart';
import 'summary.dart';

Future<void> run(List<String> args) async {
  final parsed = parseFlavorArgs(args);
  final flavor = parsed.flavor;
  args = parsed.restArgs;
  final parsedRemote = parseRemoteReleaseArgs(args);
  final overrideName = parsedRemote.versionName;
  final xx = parsedRemote.buildSegment;
  final userVersionId = parsedRemote.versionId;
  args = parsedRemote.restArgs;

  if (userVersionId != null && (overrideName == null || xx == null)) {
    stderr.writeln('指定了 --version-id 时必须同时指定 --target-version <x.y.z+xx>');
    exit(1);
  }

  final c = ctx();

  final root = readJsonFile(c.versionJson);
  final raw = root[flavor];
  if (raw is! Map) {
    stderr.writeln('version.json 缺少 flavor=$flavor 的配置节点');
    exit(1);
  }
  final cfg = FlavorModel.fromJson(Map<String, dynamic>.from(raw));
  final currentName = cfg.versionName.trim();
  if (currentName.isEmpty) {
    stderr.writeln('version.json 中 version-name 不能为空');
    exit(1);
  }

  final cfgBuild = cfg.buildNumber;
  final hasOverride = overrideName != null && xx != null;
  if (hasOverride) {
    validateTargetVersionSegmentAgainstJson(
      segmentXx: xx,
      jsonBuildNumber: cfgBuild,
    );
  }

  late final String name;
  late final int build;
  if (hasOverride) {
    name = overrideName;
    build = xx;
  } else {
    name = currentName;
    build = cfgBuild;
  }

  final channels = cfg.channelVersionIds();
  if (channels.isEmpty) {
    stderr.writeln('version.json 中 channels 不能为空（至少一个渠道）');
    exit(1);
  }

  final channelsToProcess = hasOverride && userVersionId != null
      ? resolveChannelsByVersionId(channels, userVersionId)
      : channels;

  final isDryRun = args.contains('--dry-run') || args.contains('-n');

  final summary = Summary();
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
    final releaseVersion = '$name+${base + build}';

    if (!isDryRun && completed.contains(ch)) {
      stdout.writeln('已完成，跳过: channel=$ch release-version=$releaseVersion');
      summary.skipped++;
      continue;
    }

    stdout.writeln('---- patch channel=$ch release-version=$releaseVersion ----');
    final patchArgs = <String>[
      'patch',
      'android',
      '--flavor',
      flavor,
      '--release-version',
      releaseVersion,
      '--dart-define',
      'channel=$ch',
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
    'patch 完成：flavor=$flavor（本次使用 version-name=$name、segment=$build；不写回 version.json）',
  );
  summary.print(
    flavor: flavor,
    action: 'patch',
    total: total,
    isDryRun: isDryRun,
  );
}
