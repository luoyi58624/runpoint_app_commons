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

  final appName = sanitizeFileName(cfg.apkName);
  if (appName.trim().isEmpty) {
    stderr.writeln('version.json 中 apk-name 不能为空');
    exit(1);
  }
  final currentName = cfg.versionName.trim();
  if (currentName.isEmpty) {
    stderr.writeln('version.json 中 version-name 不能为空');
    exit(1);
  }
  final channels = cfg.channelVersionIds();
  if (channels.isEmpty) {
    stderr.writeln('version.json 中 channels 不能为空（至少一个渠道）');
    exit(1);
  }
  final apkTargetPlatforms = readApkTargetPlatforms(cfg.toJson());

  final distApkDir = Directory.fromUri(c.repoRoot.uri.resolve('dist/apk/$flavor/'));
  if (!distApkDir.existsSync()) distApkDir.createSync(recursive: true);
  final isDryRun = args.contains('--dry-run') || args.contains('-n');

  final beforeBuild = cfg.buildNumber;
  final hasTargetVersion = overrideName != null && overrideBuild != null;

  late final int build;
  late final String name;
  late final bool isSingleRelease;

  if (hasTargetVersion) {
    // 规则（与 patch 一致）：
    // - 若传了 --target-version x.y.z+xx 且 xx > version.json 的 build-number，则认为 xx 是“绝对 release code”，只执行一次：build-number=xx
    // - 否则认为 xx 是 build-number（可覆盖当前 build-number），按每个渠道 version-id+xx 计算 build-number
    isSingleRelease = overrideBuild > beforeBuild;
    build = overrideBuild;
    name = overrideName.trim();
    if (name.isEmpty) {
      stderr.writeln('version.json 中 version-name 不能为空');
      exit(1);
    }
  } else {
    // 正常递增：不写 --target-version 时由脚本自动 bump，结束后写回 version.json
    isSingleRelease = false;
    final isFirst = beforeBuild == -1;
    build = beforeBuild + 1;
    name = (isFirst ? currentName : bumpPatch(currentName)).trim();
    if (name.isEmpty) {
      stderr.writeln('version.json 中 version-name 不能为空');
      exit(1);
    }
  }

  stdout.writeln(
    'release: flavor=$flavor; version-name $currentName -> $name, build-number $beforeBuild -> $build${hasTargetVersion ? "（--target-version，不写回 version.json）" : ""}',
  );

  final summary = Summary();

  final progressKey = 'release-progress';
  final expectedProgressId = '$name+$build';
  final tempRoot = readJsonFile(c.versionTempJson);
  final tempSec = getOrCreateFlavorSection(tempRoot, flavor);
  final progress = (tempSec[progressKey] is Map) ? (tempSec[progressKey] as Map) : null;
  final progressId = progress?['id']?.toString() ?? '';
  final completed = <String>{
    if (progressId == expectedProgressId && progress?['completed-channels'] is List)
      ...(progress!['completed-channels'] as List).map((e) => e.toString()),
  };

  const singleKey = '__single__';
  final channelsToProcess = isSingleRelease ? <String, int>{singleKey: 0} : channels;
  final total = channelsToProcess.length;

  for (final entry in channelsToProcess.entries) {
    final ch = entry.key;
    final base = entry.value;
    final code = isSingleRelease ? build : (base + build);
    final releaseVersion = '$name+$code';
    final plannedOutApk = '$flavor/$ch/$appName.apk';

    if (!isDryRun && completed.contains(ch)) {
      stdout.writeln('已完成，跳过: channel=$ch release-version=$releaseVersion');
      summary.skipped++;
      continue;
    }

    stdout.writeln(
      '---- channel=${isSingleRelease ? "(single)" : ch} build-number=$code ----',
    );
    final releaseArgs = <String>[
      'release',
      'android',
      '--artifact',
      'apk',
      '--flavor',
      flavor,
      '--build-name',
      name,
      '--build-number',
      '$code',
      if (apkTargetPlatforms.isNotEmpty) ...[
        '--target-platform',
        apkTargetPlatforms.join(','),
      ],
      if (!isSingleRelease) ...[
        '--dart-define',
        'channel=$ch',
      ],
      if (isDryRun) '--dry-run',
      '--',
      '--no-tree-shake-icons',
    ];

    stdout.writeln('> ${formatCliCommand("shorebird", releaseArgs)}');
    var result = await runShorebirdCapture(
      releaseArgs,
      workingDirectory: c.repoRoot.path,
      echo: true,
    );

    var codeExit = result.exitCode;
    if (codeExit != 0 && looksLikeR8FileLockFailure(result.output)) {
      stderr.writeln(
        '检测到 R8 文件占用（classes.dex）导致失败，尝试停止 Gradle Daemon 后重试一次...',
      );
      await stopGradleDaemons(c.repoRoot.path);
      await Future<void>.delayed(const Duration(seconds: 2));
      stdout.writeln('> ${formatCliCommand("shorebird", releaseArgs)}');
      result = await runShorebirdCapture(
        releaseArgs,
        workingDirectory: c.repoRoot.path,
        echo: true,
      );
      codeExit = result.exitCode;
    }

    if (codeExit != 0) {
      summary.failed++;
      summary.failedDetails.add(
        '包=$plannedOutApk | release-version=$releaseVersion | exit=$codeExit',
      );
      stderr.writeln(
        'shorebird release 失败: channel=$ch release-version=$releaseVersion exit=$codeExit',
      );
      summary.print(
        flavor: flavor,
        action: 'release',
        total: total,
        isDryRun: isDryRun,
      );
      exit(codeExit);
    }

    final apkDir = Directory.fromUri(
      c.repoRoot.uri.resolve('build/app/outputs/flutter-apk/'),
    );
    if (!apkDir.existsSync()) {
      summary.failed++;
      summary.failedDetails.add('包=$plannedOutApk | 未找到 APK 输出目录');
      stderr.writeln('未找到 APK 输出目录: ${apkDir.path}');
      summary.print(
        flavor: flavor,
        action: 'release',
        total: total,
        isDryRun: isDryRun,
      );
      exit(1);
    }
    final apks = apkDir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.apk'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (apks.isEmpty) {
      summary.failed++;
      summary.failedDetails.add('包=$plannedOutApk | 未找到 APK 产物');
      stderr.writeln('未找到 APK 产物（目录下无 .apk）: ${apkDir.path}');
      summary.print(
        flavor: flavor,
        action: 'release',
        total: total,
        isDryRun: isDryRun,
      );
      exit(1);
    }

    final builtApk = apks.first;
    final outDir = Directory.fromUri(distApkDir.uri.resolve('$ch/'));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final outApk = File.fromUri(outDir.uri.resolve('$appName.apk'));
    builtApk.copySync(outApk.path);
    stdout.writeln('已输出: ${outApk.path}（来源: ${builtApk.path}）');
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
    stdout.writeln('release dry-run 完成：未修改 ${c.versionJson.path}');
    summary.print(
      flavor: flavor,
      action: 'release',
      total: total,
      isDryRun: isDryRun,
    );
    return;
  }

  if (isSingleRelease) {
    final tempRootSingle = readJsonFile(c.versionTempJson);
    final tempSecSingle = getOrCreateFlavorSection(tempRootSingle, flavor);
    tempSecSingle.remove(progressKey);
    tempRootSingle[flavor] = tempSecSingle;
    writeJsonFile(c.versionTempJson, tempRootSingle);

    stdout.writeln(
      'release 完成（single）：flavor=$flavor（本次使用 build-number=$build，version-name=$name；不写回 version.json）',
    );
    summary.print(
      flavor: flavor,
      action: 'release',
      total: total,
      isDryRun: isDryRun,
    );
    return;
  }

  if (hasTargetVersion) {
    final tempRoot3 = readJsonFile(c.versionTempJson);
    final tempSec3 = getOrCreateFlavorSection(tempRoot3, flavor);
    tempSec3.remove(progressKey);
    tempRoot3[flavor] = tempSec3;
    writeJsonFile(c.versionTempJson, tempRoot3);

    stdout.writeln(
      'release 完成（--target-version）：flavor=$flavor（本次 version-name=$name build-number=$build；不写回 version.json）',
    );
    summary.print(
      flavor: flavor,
      action: 'release',
      total: total,
      isDryRun: isDryRun,
    );
    return;
  }

  // 写回：只更新 flavor 节点的 build-number/version-name（仅正常递增、未传 --target-version）
  final updated = FlavorModel(
    apkName: cfg.apkName,
    versionName: name,
    buildNumber: build,
    apkPlatform: cfg.apkPlatform,
    channels: cfg.channels,
  );
  final root2 = readJsonFile(c.versionJson);
  root2[flavor] = updated.toJson();
  writeJsonFile(c.versionJson, root2);

  final tempRoot2 = readJsonFile(c.versionTempJson);
  final tempSec2 = getOrCreateFlavorSection(tempRoot2, flavor);
  tempSec2.remove(progressKey);
  tempRoot2[flavor] = tempSec2;
  writeJsonFile(c.versionTempJson, tempRoot2);

  stdout.writeln(
    'release 完成：flavor=$flavor 已写入 ${c.versionJson.path} version-name=$name build-number=$build',
  );
  summary.print(
    flavor: flavor,
    action: 'release',
    total: total,
    isDryRun: isDryRun,
  );
}
