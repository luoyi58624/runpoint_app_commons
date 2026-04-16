import 'dart:convert';
import 'dart:io';

import 'context.dart';

String? _shorebirdExecutable;

({String flavor, List<String> restArgs}) parseFlavorArgs(List<String> args) {
  String? value;
  final rest = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--flavor=')) {
      value = a.substring('--flavor='.length).trim();
      continue;
    }
    rest.add(a);
  }

  final out = (value ?? '').trim();
  if (out.isEmpty) {
    stderr.writeln('运行脚本请指定 flavor，例如：--flavor=sit');
    exit(1);
  }
  return (flavor: out, restArgs: rest);
}

({String? patchVersion, List<String> restArgs}) parsePatchVersionArgs(List<String> args) {
  String? value;
  final rest = <String>[];

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--patch-version') {
      final next = (i + 1) < args.length ? args[i + 1] : null;
      if (next == null || next.trim().isEmpty) {
        stderr.writeln(
          '用法: --patch-version <x.y.z[+code]>，例如 --patch-version 1.0.2 或 --patch-version 1.0.1+1001',
        );
        exit(1);
      }
      value = next.trim();
      i++; // consume next
      continue;
    }
    if (a.startsWith('--patch-version=')) {
      value = a.substring('--patch-version='.length).trim();
      continue;
    }
    rest.add(a);
  }

  final out = value?.trim();
  if (out == null || out.isEmpty) return (patchVersion: null, restArgs: rest);
  // 支持两种：
  // 1) x.y.z（只覆盖 version-name，build-number 仍取 version.json）
  // 2) x.y.z+code（直接作为 shorebird --release-version 使用）
  final plus = out.indexOf('+');
  if (plus < 0) {
    parseSemver3(out);
    return (patchVersion: out, restArgs: rest);
  }
  final name = out.substring(0, plus).trim();
  final codeRaw = out.substring(plus + 1).trim();
  parseSemver3(name);
  final code = int.tryParse(codeRaw);
  if (code == null || code < 0) {
    stderr.writeln('patch-version 的 +code 必须为非负整数，当前为: "$out"');
    exit(1);
  }
  return (patchVersion: out, restArgs: rest);
}

({String name, int code}) parseReleaseVersion(String releaseVersion) {
  final raw = releaseVersion.trim();
  final idx = raw.indexOf('+');
  if (idx <= 0 || idx == raw.length - 1) {
    stderr.writeln('release-version 必须是 x.y.z+code，例如 1.0.1+1001；当前为: "$releaseVersion"');
    exit(1);
  }
  final name = raw.substring(0, idx).trim();
  final codeRaw = raw.substring(idx + 1).trim();
  parseSemver3(name);
  final code = int.tryParse(codeRaw);
  if (code == null || code < 0) {
    stderr.writeln('release-version 的 code 必须为非负整数，当前为: "$releaseVersion"');
    exit(1);
  }
  return (name: name, code: code);
}

Map<String, dynamic> readJsonFile(File file) {
  if (!file.existsSync()) return <String, dynamic>{};
  final text = file.readAsStringSync(encoding: utf8).trim();
  if (text.isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return <String, dynamic>{};
}

void writeJsonFile(File file, Map<String, dynamic> map) {
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(map)}\n', encoding: utf8);
}

Map<String, dynamic> requireFlavorSection(Map<String, dynamic> root, String flavor) {
  final sec = root[flavor];
  if (sec is Map<String, dynamic>) return sec;
  if (sec is Map) return Map<String, dynamic>.from(sec);
  stderr.writeln('version.json 缺少 flavor=$flavor 的配置节点');
  exit(1);
}

Map<String, dynamic> getOrCreateFlavorSection(Map<String, dynamic> root, String flavor) {
  final sec = root[flavor];
  if (sec is Map<String, dynamic>) return sec;
  if (sec is Map) return Map<String, dynamic>.from(sec);
  final created = <String, dynamic>{};
  root[flavor] = created;
  return created;
}

String requireVersionName(Map<String, dynamic> map) {
  final name = map['version-name']?.toString().trim() ?? '';
  if (name.isEmpty) {
    stderr.writeln('version.json 中 version-name 不能为空');
    exit(1);
  }
  return name;
}

String sanitizeFileName(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return 'app';
  final out = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  return out.replaceAll(RegExp(r'[\. ]+$'), '_');
}

String requireAppName(Map<String, dynamic> map) {
  final v = map['apk-name']?.toString().trim() ?? '';
  if (v.isEmpty) {
    stderr.writeln('version.json 中 apk-name 不能为空');
    exit(1);
  }
  return sanitizeFileName(v);
}

Map<String, int> requireChannels(Map<String, dynamic> map) {
  // 新格式：
  // "channels": [ { "xiaomi": { "version-id": 10000 } }, { "oppo": { "version-id": 20000 } } ]
  final raw = map['channels'];
  if (raw is! List || raw.isEmpty) {
    stderr.writeln('version.json 中 channels 必须为非空数组（每项为 {渠道: {version-id}}）');
    exit(1);
  }

  final out = <String, int>{};
  for (final item in raw) {
    if (item is! Map) {
      stderr.writeln('version.json 中 channels 每一项必须是对象，当前为: "$item"');
      exit(1);
    }
    if (item.isEmpty) continue;
    if (item.length != 1) {
      stderr.writeln('version.json 中 channels 每一项只能包含 1 个渠道键，当前为: "$item"');
      exit(1);
    }
    final entry = item.entries.first;
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    final v = entry.value;
    int? base;
    if (v is Map) {
      final rawId = v['version-id'];
      if (rawId is int) base = rawId;
      if (rawId is String) base = int.tryParse(rawId.trim());
    }
    if (base == null || base < 0) {
      stderr.writeln(
        'version.json 中 channels 渠道 "$key" 的 version-id 必须为非负整数，当前为: "$v"',
      );
      exit(1);
    }
    out[key] = base;
  }
  if (out.isEmpty) {
    stderr.writeln('version.json 中 channels 不能为空（至少一个渠道）');
    exit(1);
  }
  return out;
}

List<String> readApkTargetPlatforms(Map<String, dynamic> map) {
  final raw = map['apk-platform'];
  if (raw is! List || raw.isEmpty) return const <String>[];

  String normalize(String v) {
    final s = v.trim().toLowerCase();
    switch (s) {
      case 'arm':
      case 'armeabi-v7a':
      case 'android-arm':
        return 'android-arm';
      case 'arm64':
      case 'arm64-v8a':
      case 'android-arm64':
        return 'android-arm64';
      case 'x64':
      case 'x86_64':
      case 'android-x64':
      case 'x86':
        return 'android-x64';
      default:
        return '';
    }
  }

  final out = <String>{};
  for (final e in raw) {
    final v = normalize(e.toString());
    if (v.isEmpty) {
      stderr.writeln('version.json 中 apk-platform 存在不支持的值: "$e"（支持 arm/arm64/x64）');
      exit(1);
    }
    out.add(v);
  }
  return out.toList()..sort();
}

int parseBuildNumber(Map<String, dynamic> map) {
  final v = map['build-number'];
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

({int major, int minor, int patch}) parseSemver3(String versionName) {
  final raw = versionName.trim();
  final parts = raw.split('.');
  if (parts.length != 3) {
    stderr.writeln('version-name 必须是 x.y.z（三段），当前为: "$versionName"');
    exit(1);
  }
  final major = int.tryParse(parts[0]) ?? -1;
  final minor = int.tryParse(parts[1]) ?? -1;
  final patch = int.tryParse(parts[2]) ?? -1;
  if (major < 0 || minor < 0 || patch < 0) {
    stderr.writeln('version-name 只能包含非负整数，例如 1.0.0；当前为: "$versionName"');
    exit(1);
  }
  return (major: major, minor: minor, patch: patch);
}

String formatSemver3(({int major, int minor, int patch}) v) =>
    '${v.major}.${v.minor}.${v.patch}';

String bumpPatch(String versionName) {
  final v = parseSemver3(versionName);
  return formatSemver3((major: v.major, minor: v.minor, patch: v.patch + 1));
}

String _quoteArgForShell(String arg) {
  final needsQuotes = arg.isEmpty || RegExp(r'[\s"&|<>^]').hasMatch(arg);
  if (!needsQuotes) return arg;
  return '"${arg.replaceAll('"', r'\"')}"';
}

String formatCliCommand(String exe, List<String> args) =>
    (<String>[exe, ...args]).map(_quoteArgForShell).join(' ');

bool looksLikeFailureText(String text) {
  return <String>[
    'Unauthorized.'
    'Could not find app with id:',
    'This app may not exist or you may not have permission to view it.',
    'Release not found:',
    'Patches can only be published for existing releases.',
    'UnpatchableChangeException',
    'Your app contains asset changes',
    'Failed to build',
    'It looks like you have an existing',
    'Please bump your version number',
    'Missing argument',
    'Unhandled exception',
    '\nError:',
    '\nERROR:',
  ].any(text.contains);
}

Future<String> _resolveShorebirdExecutable() async {
  if (_shorebirdExecutable != null) return _shorebirdExecutable!;

  final locator = Platform.isWindows ? 'where' : 'which';
  final result = await Process.run(locator, const ['shorebird'], runInShell: true);
  if (result.exitCode == 0) {
    final out = (result.stdout ?? '').toString();
    final lines = out
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      var candidate = lines.first;
      if (Platform.isWindows) {
        final file = File(candidate);
        final dir = file.parent;
        final ps1 = File.fromUri(dir.uri.resolve('shorebird.ps1'));
        if (ps1.existsSync()) {
          candidate = ps1.path;
        } else {
          final bat = File.fromUri(dir.uri.resolve('shorebird.bat'));
          if (bat.existsSync()) {
            candidate = bat.path;
          }
        }
      }
      _shorebirdExecutable = candidate;
      return _shorebirdExecutable!;
    }
  }

  _shorebirdExecutable = 'shorebird';
  return _shorebirdExecutable!;
}

Future<({int exitCode, String output})> runShorebirdCapture(
  List<String> args, {
  required String workingDirectory,
  bool echo = false,
}) async {
  final exe = await _resolveShorebirdExecutable();
  final isWindows = Platform.isWindows;
  final lower = exe.toLowerCase();
  final isCmdShim =
      isWindows && (lower.endsWith('.cmd') || lower.endsWith('.bat'));
  final isPs1Shim = isWindows && lower.endsWith('.ps1');

  final process = await Process.start(
    isPs1Shim
        ? 'powershell'
        : isCmdShim
            ? 'cmd'
            : exe,
    isPs1Shim
        ? <String>[
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            exe,
            ...args,
          ]
        : isCmdShim
            ? <String>['/c', exe, ...args]
            : args,
    workingDirectory: workingDirectory,
    runInShell: false,
  );

  final combined = StringBuffer();
  final outSub = process.stdout.transform(utf8.decoder).listen((chunk) {
    combined.write(chunk);
    if (echo) stdout.write(chunk);
  });
  final errSub = process.stderr.transform(utf8.decoder).listen((chunk) {
    combined.write(chunk);
    if (echo) stderr.write(chunk);
  });

  final code = await process.exitCode;
  await outSub.cancel();
  await errSub.cancel();

  final text = combined.toString();
  final normalizedExit = (code == 0 && looksLikeFailureText(text)) ? 1 : code;
  return (exitCode: normalizedExit, output: text);
}

bool looksLikeR8FileLockFailure(String output) {
  final lower = output.toLowerCase();
  if (!lower.contains('minify') || !lower.contains('r8')) return false;
  if (!lower.contains('filesystemexception')) return false;
  return lower.contains('classes.dex') || lower.contains('dex\\') || lower.contains('dex/');
}

Future<void> stopGradleDaemons(String repoRootPath) async {
  final androidDir = Directory.fromUri(Directory(repoRootPath).uri.resolve('android/'));
  if (!androidDir.existsSync()) return;

  final isWindows = Platform.isWindows;
  final gradlew =
      File.fromUri(androidDir.uri.resolve(isWindows ? 'gradlew.bat' : 'gradlew'));
  if (!gradlew.existsSync()) return;

  try {
    await Process.run(
      isWindows ? gradlew.path : './gradlew',
      const ['--stop'],
      workingDirectory: androidDir.path,
      runInShell: isWindows,
    );
  } catch (_) {
    // best-effort
  }
}

RepoContext ctx() => resolveRepoContext();

