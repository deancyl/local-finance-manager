import 'dart:typed_data';
import 'package:importers/importers.dart';

/// Registry for all available importers.
/// 
/// Provides methods to detect and retrieve importers
/// based on file content.
class ImporterRegistry {
  final List<ImporterBase> _importers = [
    AlipayImporter(),
    WeChatPayImporter(),
    IcbcImporter(),
    CcbImporter(),
    BocImporter(),
    AbcImporter(),
    BocomImporter(),
    CmbImporter(),
    CiticImporter(),
  ];

  /// Detects the appropriate importer for the given file.
  /// 
  /// Returns null if no importer can handle the file.
  ImporterBase? detectImporter({
    required String filename,
    required Uint8List content,
  }) {
    for (final importer in _importers) {
      if (importer.canParse(filename: filename, content: content)) {
        return importer;
      }
    }
    return null;
  }

  /// Get all available importers.
  List<ImporterBase> getAllImporters() => List.unmodifiable(_importers);

  /// Get importer by source ID.
  ImporterBase? getById(String sourceId) {
    for (final importer in _importers) {
      if (importer.sourceId == sourceId) {
        return importer;
      }
    }
    return null;
  }

  /// Get list of supported source names.
  List<String> getSupportedSourceNames() {
    return _importers.map((i) => i.name).toList();
  }
}