import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// FilePicker nəticəsindən Dio multipart (web + desktop).
Future<MultipartFile?> multipartFromPlatformFile(
  PlatformFile file, {
  required String fallbackName,
}) async {
  final name = file.name.isNotEmpty ? file.name : fallbackName;

  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return MultipartFile.fromBytes(file.bytes!, filename: name);
  }

  if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
    return MultipartFile.fromFile(file.path!, filename: name);
  }

  return null;
}
