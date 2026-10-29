import 'package:image_picker/image_picker.dart';

import 'package:printer_app/models/id_card.dart' as card;

/// 相册 / 拍照来源封装（基于 image_picker）。
///
/// 隐私说明：仅在本地读取用户选择的图片，不做任何网络上传。
class ImagePickerSource {
  final ImagePicker _picker = ImagePicker();

  /// 相册多选。
  Future<List<card.ImportedImage>> pickMultipleFromAlbum() async {
    final files = await _picker.pickMultiImage();
    return _toImported(files);
  }

  /// 相机拍照（单张）。
  Future<card.ImportedImage?> takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return null;
    final imported = await _toImported([file]);
    return imported.first;
  }

  Future<List<card.ImportedImage>> _toImported(List<XFile> files) async {
    final result = <card.ImportedImage>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      result.add(card.ImportedImage(
        path: f.path,
        source: card.ImageSource.camera, // 本方法同时服务相册多选与拍照
        bytes: bytes,
      ));
    }
    return result;
  }
}
