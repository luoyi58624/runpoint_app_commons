import 'dart:io';

class RepoContext {
  RepoContext({
    required this.repoRoot,
    required this.scriptsDir,
  });

  final Directory repoRoot;
  final Directory scriptsDir;

  File get versionJson => File.fromUri(scriptsDir.uri.resolve('version.json'));
  File get versionTempJson =>
      File.fromUri(scriptsDir.uri.resolve('version.temp.json'));
}

RepoContext resolveRepoContext() {
  // 优先从当前工作目录查找（通常从仓库根运行）。
  Directory fromCwd = Directory.current;
  for (var i = 0; i < 6; i++) {
    final scripts = Directory.fromUri(fromCwd.uri.resolve('scripts/'));
    final v = File.fromUri(scripts.uri.resolve('version.json'));
    if (v.existsSync()) {
      return RepoContext(repoRoot: fromCwd, scriptsDir: scripts);
    }
    final parent = fromCwd.parent;
    if (parent.path == fromCwd.path) break;
    fromCwd = parent;
  }

  // 回退：从脚本自身路径向上找
  final scriptFile = File.fromUri(Platform.script);
  Directory base = scriptFile.parent;
  for (var i = 0; i < 8; i++) {
    final scripts = Directory.fromUri(base.uri.resolve('scripts/'));
    final v = File.fromUri(scripts.uri.resolve('version.json'));
    if (v.existsSync()) {
      return RepoContext(repoRoot: base, scriptsDir: scripts);
    }
    final parent = base.parent;
    if (parent.path == base.path) break;
    base = parent;
  }

  throw StateError('无法定位仓库根目录（找不到 scripts/version.json）');
}

