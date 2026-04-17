import 'package:runpoint_app_commons/runpoint_app_commons.dart';

part 'api.dart';

final http = _Http();

class _Http extends ElHttp {
  @override
  BaseOptions get options => super.options.copyWith(
    connectTimeout: Duration(seconds: El.kReleaseMode ? 30 : 10), // 连接超时
    receiveTimeout: Duration(seconds: El.kReleaseMode ? 30 : 10), // 响应超时
    baseUrl: AppConfig.baseUrl,
  );
}
