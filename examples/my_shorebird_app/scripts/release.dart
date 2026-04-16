import 'package:shorebird_release/shorebird_release.dart';

/// 执行命令：
/// * dart run ./scripts/release.dart --action=patch --flavor=sit
/// * dart run ./scripts/release.dart --action=release --flavor=sit
/// * dart run ./scripts/release.dart --action=patch --flavor=prod
/// * dart run ./scripts/release.dart --action=release --flavor=prod
Future<void> main(List<String> args) => runShorebirdRelease(args);
