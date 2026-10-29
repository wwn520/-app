import 'package:printer_app/image_import/image_picker_source.dart';
import 'package:printer_app/image_import/share_receiver.dart';
import 'package:printer_app/models/id_card.dart';

/// 统一导入入口：把多种来源归一化为 [ImportedImage] 列表。
class ImportManager {
  final ImagePickerSource _pickerSource;
  final ShareReceiver _shareReceiver;

  ImportManager(this._pickerSource, this._shareReceiver);

  /// 按来源导入图片。
  Future<List<ImportedImage>> pickFrom(ImageSource source) async {
    switch (source) {
      case ImageSource.album:
        return _pickerSource.pickMultipleFromAlbum();
      case ImageSource.camera:
        final img = await _pickerSource.takePhoto();
        return img == null ? [] : [img];
      case ImageSource.share:
        return _shareReceiver.getInitialSharedImages();
    }
  }
}
