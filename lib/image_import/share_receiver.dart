import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:printer_app/models/id_card.dart';

/// 系统/微信分享接收（基于 receive_sharing_intent，无需 OpenSDK）。
///
/// 通过系统分享把图片「分享到」本 App 后，从这里取回图片路径。
class ShareReceiver {
  /// 监听后续分享（App 已在后台被唤起时的流式分享）。
  Stream<List<ImportedImage>> get shareStream =>
      ReceiveSharingIntent.instance.getMediaStream().map(_toImported);

  /// 获取冷启动时携带的分享图片。
  Future<List<ImportedImage>> getInitialSharedImages() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    return _toImported(media);
  }

  List<ImportedImage> _toImported(List<SharedMediaFile> media) {
    return media
        .where((m) => m.type == SharedMediaType.image)
        .map((m) => ImportedImage(
              path: m.path,
              source: ImageSource.share,
              bytes: null, // 分享通常只给路径，使用时再读取
            ))
        .toList();
  }
}
