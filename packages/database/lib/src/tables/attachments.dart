import 'package:drift/drift.dart';
import 'transactions.dart';

/// Attachments table - file attachments for transactions.
/// 
/// Supports various file types:
/// - Images (receipts, photos)
/// - PDFs (invoices, statements)
/// - Other documents
/// 
/// Files are stored externally (not in database) with references here.
/// Thumbnails are generated for quick preview.
class Attachments extends Table {
  TextColumn get id => text()();
  
  /// Transaction this attachment belongs to
  TextColumn get transactionId => text().references(Transactions, #id)();
  
  /// Original file name
  TextColumn get fileName => text()();
  
  /// File path relative to app's attachment storage
  TextColumn get filePath => text()();
  
  /// MIME type (image/jpeg, application/pdf, etc.)
  TextColumn get fileType => text()();
  
  /// File size in bytes
  IntColumn get fileSize => integer()();
  
  /// Thumbnail path for preview (null if not applicable)
  TextColumn get thumbnailPath => text().nullable()();
  
  /// Thumbnail width in pixels
  IntColumn get thumbnailWidth => integer().nullable()();
  
  /// Thumbnail height in pixels
  IntColumn get thumbnailHeight => integer().nullable()();
  
  /// MD5 hash of the file for deduplication
  TextColumn get fileHash => text().nullable()();
  
  /// User-provided description/notes
  TextColumn get description => text().nullable()();
  
  /// Sort order for multiple attachments
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  
  /// Standard tracking columns
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
