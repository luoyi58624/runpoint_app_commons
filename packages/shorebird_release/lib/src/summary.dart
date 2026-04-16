import 'dart:io';

class Summary {
  int ok = 0;
  int skipped = 0;
  int failed = 0;
  final List<String> failedDetails = <String>[];

  void print({
    required String flavor,
    required String action,
    required int total,
    required bool isDryRun,
  }) {
    final title = '$action 结果汇总（flavor=$flavor${isDryRun ? " dry-run" : ""}）';
    stdout.writeln('');
    stdout.writeln('╔${'═' * (title.length + 2)}╗');
    stdout.writeln('║ $title ║');
    stdout.writeln('╠${'═' * (title.length + 2)}╣');
    stdout.writeln('║ 总计: $total');
    stdout.writeln('║ 成功: $ok');
    stdout.writeln('║ 跳过: $skipped');
    stdout.writeln('║ 失败: $failed');
    if (failedDetails.isNotEmpty) {
      stdout.writeln('╠${'─' * (title.length + 2)}╣');
      stdout.writeln('║ 失败明细:');
      for (final d in failedDetails) {
        stdout.writeln('║ - $d');
      }
    }
    stdout.writeln('╚${'═' * (title.length + 2)}╝');
    stdout.writeln('');
  }
}

