import 'dart:io';
import 'package:flutter/material.dart';

class UniqueFileImage extends FileImage {
  final int fileSize;

  UniqueFileImage(File file)
      : fileSize = file.lengthSync(),
        super(file, scale: 1.0);

  @override
  bool operator ==(Object other) {
    return other is UniqueFileImage &&
        other.file.path == file.path &&
        other.fileSize == fileSize;
  }

  @override
  int get hashCode => Object.hash(file.path, fileSize);
}
