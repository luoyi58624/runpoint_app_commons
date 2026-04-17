import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._();

  static const env = appFlavor ?? (kReleaseMode ? 'prod' : 'sit');
  static const isProdEnv = env == 'prod';
  static const isSitEnv = env == 'sit';

  static const baseUrl = isSitEnv
      // ? 'http://192.168.1.80:8087' // 测试环境
      // ? 'http://192.168.1.77:8087' // 测试环境
      ? 'http://43.198.63.15:8087' // 测试环境
      // ? 'https://backend.11kumar.click' // 测试环境
      : 'https://api.kumarpay-in.com'; // 生产环境
  // const baseUrl = 'https://api.kumarpay-in.com';
}
