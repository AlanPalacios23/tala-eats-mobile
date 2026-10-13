import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/failures.dart';
import '../repositories.dart';

/// Selección de fotos con `image_picker` y copia al almacenamiento privado de
/// la app. La integración real puede subir el archivo devuelto a storage
/// remoto y reemplazar la referencia por la URL resultante.
class LocalMediaRepository implements MediaRepository {
  LocalMediaRepository({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == MediaSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: purpose == MediaPurpose.restaurantCover ? 1920 : 1440,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('denied') || code.contains('permission')) {
        throw const AppFailure(FailureKind.permissionDenied);
      }
      throw const AppFailure(FailureKind.media);
    }
    if (file == null) return null;

    try {
      return await _persist(
        file.path,
        purpose == MediaPurpose.restaurantCover ? 'restaurant' : 'product',
      );
    } on FileSystemException {
      throw const AppFailure(FailureKind.media);
    }
  }

  Future<String> _persist(String sourcePath, String prefix) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const AppFailure(FailureKind.media);
    }
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}restaurant_media',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot >= 0 ? sourcePath.substring(dot) : '.jpg';
    final target = File(
      '${directory.path}${Platform.pathSeparator}'
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await source.copy(target.path);
    return target.path;
  }
}
