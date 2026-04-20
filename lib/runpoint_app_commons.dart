library;

import 'package:el_flutter/el_flutter.dart';

export 'package:el_dart/el_dart.dart';
export 'package:el_dart/ext.dart';
export 'package:el_flutter/el_flutter.dart';
export 'package:el_flutter/ext.dart';

export 'package:get_storage/get_storage.dart';

export 'src/utils/app_update/index.dart';

export 'src/widgets/simple_widgets.dart';

Future<void> init() async {
  await el.init();
  ElLoadingUtil.defaultCloseModel = ElLoadingCloseModel(
    title: 'Close Loading',
    content: 'Are you sure you want to close it?',
    cancel: 'Cancel',
    confirm: 'Confirm',
  );
}
