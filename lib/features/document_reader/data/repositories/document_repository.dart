import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../domain/models/document_model.dart';

class DocumentRepository {
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        if (deviceInfo.version.sdkInt >= 30) {
          var status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            status = await Permission.manageExternalStorage.request();
          }
          return status.isGranted;
        } else {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          return status.isGranted;
        }
      } catch (e) {
        debugPrint('Error getting device info for permissions: $e');
        // Fallback: Request standard storage permission if SDK check fails
        return await Permission.storage.request().isGranted;
      }
    }
    return true;
  }

  Future<List<DocumentFile>> getDocuments() async {
    bool hasPermission = await requestPermissions();
    if (!hasPermission) return [];

    List<DocumentFile> documents = [];
    
    // We scan common directories for better performance and to avoid system folders
    final List<String> pathsToScan = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Documents/EduSheet', // App specific
    ];

    final supportedExtensions = {'.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'};

    for (String path in pathsToScan) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
          for (var entity in entities) {
            if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();
              if (supportedExtensions.contains(ext)) {
                final stat = await entity.stat();
                documents.add(DocumentFile(
                  name: p.basename(entity.path),
                  path: entity.path,
                  extension: ext,
                  size: stat.size,
                  lastModified: stat.modified,
                  type: DocumentFile.getDocumentType(ext),
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('Error scanning directory $path: $e');
        }
      }
    }

    // Sort by last modified date (newest first)
    documents.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    
    return documents;
  }
}
