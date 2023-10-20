import 'package:behemoth/common/common.dart';
import 'package:behemoth/common/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

Future<List<XFile>> pickImage({bool multiple = false}) async {
  if (isDesktop) {
    var pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'JPEG',
          'JPG',
          'PNG',
          'GIF'
        ],
        allowMultiple: multiple,
        dialogTitle: "choose image",
        initialDirectory: picturesFolder);

    var xfiles = <XFile>[];
    for (var file in pickerResult?.files ?? []) {
      xfiles.add(XFile(file.path!, length: file.size));
    }
    return xfiles;
  }

  if (multiple) {
    return await ImagePicker().pickMultiImage(
      imageQuality: 70,
      maxWidth: 1440,
    );
  }

  var xfile = await ImagePicker().pickImage(
    imageQuality: 70,
    maxWidth: 1440,
    source: ImageSource.gallery,
  );
  return (xfile != null) ? [xfile] : [];
}

Future<List<XFile>> pickVideo({bool multiple = false}) async {
  if (isDesktop) {
    var pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4',
          'MP4',
          'mov',
          'MOV',
          'avi',
          'AVI',
          'mkv',
          'MKV',
          'wmv',
          'WMV'
        ],
        allowMultiple: multiple,
        dialogTitle: "choose video",
        initialDirectory: picturesFolder);

    return pickerResult == null
        ? []
        : pickerResult.files
            .map((e) => XFile(e.path!, length: e.size))
            .toList();
  }
  if (multiple) {
    return await ImagePicker().pickMultipleMedia();
  }
  var xfile = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
  );

  return (xfile != null) ? [xfile] : [];
}

Future<XFile?> pickAudio() async {
  if (isDesktop) {
    var pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'MP3',
          'wav',
          'WAV',
          'ogg',
          'OGG',
          'flac',
          'FLAC',
          'm4a',
          'M4A',
          'aac',
          'AAC',
          'wma',
          'WMA'
        ],
        dialogTitle: "choose audio",
        initialDirectory: picturesFolder);

    var single = pickerResult?.files.single;
    if (single == null) {
      return null;
    }

    return XFile(single.path!, length: single.size);
  } else {
    return await ImagePicker().pickVideo(
      maxDuration: const Duration(minutes: 5),
      source: ImageSource.gallery,
    );
  }
}
