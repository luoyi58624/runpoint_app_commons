class FlavorModel {
  FlavorModel({
    required this.apkName,
    required this.versionName,
    required this.buildNumber,
    required this.apkPlatform,
    required this.channels,
  });

  final String apkName;
  final String versionName;
  final int buildNumber;
  final List<String> apkPlatform;
  final Map<String, ChannelModel> channels;

  factory FlavorModel.fromJson(Map<String, dynamic> json) {
    final apkName = (json['apk-name'] ?? '').toString();
    final versionName = (json['version-name'] ?? '').toString();
    final buildNumberRaw = json['build-number'];
    final buildNumber = buildNumberRaw is int ? buildNumberRaw : int.tryParse(buildNumberRaw?.toString() ?? '') ?? 0;

    final apkPlatformRaw = json['apk-platform'];
    final apkPlatform = apkPlatformRaw is List ? apkPlatformRaw.map((e) => e.toString()).toList() : <String>[];

    final channelsRaw = json['channels'];
    final channels = <String, ChannelModel>{};
    if (channelsRaw is Map) {
      for (final entry in channelsRaw.entries) {
        final name = entry.key.toString();
        final v = entry.value;
        if (v is Map) {
          channels[name] = ChannelModel.fromJson(name, Map<String, dynamic>.from(v));
        }
      }
    } else if (channelsRaw is List) {
      for (final item in channelsRaw) {
        if (item is! Map) continue;
        if (item.isEmpty) continue;
        if (item.length != 1) continue;
        final entry = item.entries.first;
        final name = entry.key.toString();
        if (entry.value is Map) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          channels[name] = ChannelModel.fromJson(name, m);
        }
      }
    }

    return FlavorModel(
      apkName: apkName,
      versionName: versionName,
      buildNumber: buildNumber,
      apkPlatform: apkPlatform,
      channels: channels,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apk-name': apkName,
      'version-name': versionName,
      'build-number': buildNumber,
      if (apkPlatform.isNotEmpty) 'apk-platform': apkPlatform,
      'channels': <String, dynamic>{
        for (final e in channels.entries) e.key: e.value.toJson(),
      },
    };
  }

  Map<String, int> channelVersionIds() => {
        for (final e in channels.entries) e.key: e.value.versionId,
      };
}

class ChannelModel {
  ChannelModel({
    required this.versionId,
  });

  final int versionId;

  factory ChannelModel.fromJson(String name, Map<String, dynamic> json) {
    final rawId = json['version-id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || id < 0) {
      throw StateError('channels["$name"]["version-id"] 必须为非负整数');
    }
    return ChannelModel(versionId: id);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version-id': versionId,
      };
}
