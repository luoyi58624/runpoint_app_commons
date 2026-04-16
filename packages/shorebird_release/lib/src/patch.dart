import 'dart:io';

import 'common.dart';
import 'models.dart';
import 'summary.dart';

Future<void> run(List<String> args) async {
  final parsed = parseFlavorArgs(args);
  final flavor = parsed.flavor;
  args = parsed.restArgs;
  final parsedPatchVersion = parsePatchVersionArgs(args);
  final patchVersion = parsedPatchVersion.patchVersion;
  args = parsedPatchVersion.restArgs;
  final c = ctx();

  final root = readJsonFile(c.versionJson);
  final raw = root[flavor];
  if (raw is! Map) {
    stderr.writeln('version.json 缺少 flavor=$flavor 的配置节点');
    exit(1);
  }
  final cfg = FlavorModel.fromJson(Map<String, dynamic>.from(raw));
  final currentName = cfg.versionName.trim();
  final name = (patchVersion ?? currentName).trim();
  if (name.isEmpty) {
    stderr.writeln('version.json 中 version-name 不能为空');
    exit(1);
  }
  if (patchVersion != null && patchVersion != currentName) {
    stdout.writeln('patch-version: $currentName -> $patchVersion');
  }
  final build = cfg.buildNumber;
  final channels = cfg.channelVersionIds();
  if (channels.isEmpty) {
    stderr.writeln('version.json 中 channels 不能为空（至少一个渠道）');
    exit(1);
  }
  final isDryRun = args.contains('--dry-run') || args.contains('-n');

  final summary = Summary();

  final progressKey = 'patch-progress';
  final expectedProgressId = '$name+$build';
  final tempRoot = readJsonFile(c.versionTempJson);
  final tempSec = getOrCreateFlavorSection(tempRoot, flavor);
  final progress = (tempSec[progressKey] is Map) ? (tempSec[progressKey] as Map) : null;
  final progressId = progress?['id']?.toString() ?? '';
  final completed = <String>{
    if (progressId == expectedProgressId && progress?['completed-channels'] is List)
      ...(progress!['completed-channels'] as List).map((e) => e.toString()),
  };

  for (final entry in channels.entries) {
    final ch = entry.key;
    final base = entry.value;
    final code = base + build;
    final releaseVersion = '$name+$code';

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
      if (result.output.contains('UnpatchableChangeException') ||
          result.output.contains('Your app contains asset changes')) {
        stderr.writeln('');
        stderr.writeln('检测到 Shorebird 服务端验证失败：存在 asset 变更，patch 无法发布。');
        stderr.writeln('这类变更无法通过 patch 下发，需要先创建新的 release。');
        stderr.writeln('');
        stderr.writeln('请先执行：dart run ./scripts/run.dart --action=release --flavor=$flavor');
        stderr.writeln('然后再执行：dart run ./scripts/run.dart --action=patch --flavor=$flavor');
        stderr.writeln('');
      }

      summary.failed++;
      summary.failedDetails
          .add('渠道=$ch | release-version=$releaseVersion | exit=$codeExit');
      stderr.writeln(
        'shorebird patch 失败: channel=$ch release-version=$releaseVersion exit=$codeExit',
      );
      summary.print(
        flavor: flavor,
        action: 'patch',
        total: channels.length,
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
      total: channels.length,
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
    'patch 完成：flavor=$flavor（对应 build-number=$build），本次使用 version-name=$name（不写回 version.json）',
  );
  summary.print(
    flavor: flavor,
    action: 'patch',
    total: channels.length,
    isDryRun: isDryRun,
  );
}

