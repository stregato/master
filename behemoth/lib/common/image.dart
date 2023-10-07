import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> pickImage() async {
  if (isDesktop) {
    var pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: "choose image",
        initialDirectory: picturesFolder);

    var single = pickerResult?.files.single;
    if (single == null) {
      return null;
    }

    return XFile(single.path!, length: single.size);
  } else {
    return await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
  }
}
