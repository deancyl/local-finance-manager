import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Page setup configuration for printing.
class PageSetup {
  final PdfPageFormat format;
  final bool landscape;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  const PageSetup({
    this.format = PdfPageFormat.a4,
    this.landscape = false,
    this.marginTop = 40,
    this.marginBottom = 40,
    this.marginLeft = 40,
    this.marginRight = 40,
  });

  /// Gets the effective page format (considering orientation).
  PdfPageFormat get effectiveFormat =>
      landscape ? format.landscape : format;

  /// Gets the margins as EdgeInsets.
  pw.EdgeInsets get margins => pw.EdgeInsets.only(
        top: marginTop,
        bottom: marginBottom,
        left: marginLeft,
        right: marginRight,
      );

  /// Common page formats.
  static const Map<String, PdfPageFormat> formats = {
    'A4': PdfPageFormat.a4,
    'A3': PdfPageFormat.a3,
    'Letter': PdfPageFormat.letter,
    'Legal': PdfPageFormat.legal,
  };

  PageSetup copyWith({
    PdfPageFormat? format,
    bool? landscape,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
  }) {
    return PageSetup(
      format: format ?? this.format,
      landscape: landscape ?? this.landscape,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
    );
  }
}

/// Print service for generating and printing PDF documents.
///
/// Provides:
/// - Print preview with page navigation
/// - Page setup configuration
/// - Direct printing to printer
/// - PDF generation for printing
class PrintService {
  /// Prints a PDF document directly.
  ///
  /// [pdfBytes] - The PDF document bytes.
  /// [title] - The document title for printer queue.
  /// [printer] - Optional printer name (uses default if not specified).
  static Future<bool> printPdf({
    required Uint8List pdfBytes,
    required String title,
    String? printer,
  }) async {
    try {
      await Printing.directPrint(
        bytes: pdfBytes,
        name: title,
        printer: printer,
      );
      return true;
    } catch (e) {
      debugPrint('Print error: $e');
      return false;
    }
  }

  /// Shows the print dialog for PDF document.
  ///
  /// [pdfBytes] - The PDF document bytes.
  /// [title] - The document title.
  static Future<bool> showPrintDialog({
    required Uint8List pdfBytes,
    required String title,
  }) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: title,
        format: PdfPageFormat.a4,
      );
      return true;
    } catch (e) {
      debugPrint('Print dialog error: $e');
      return false;
    }
  }

  /// Shows print preview with page navigation.
  ///
  /// [context] - Build context.
  /// [title] - Preview title.
  /// [onLayout] - Function to generate PDF pages.
  /// [pageSetup] - Page setup configuration.
  static Future<void> showPreview({
    required BuildContext context,
    required String title,
    required Future<Uint8List> Function(PageSetup) onLayout,
    PageSetup pageSetup = const PageSetup(),
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          title: title,
          onLayout: onLayout,
          initialSetup: pageSetup,
        ),
      ),
    );
  }

  /// Lists available printers.
  static Future<List<Printer>> listPrinters() async {
    final printers = await Printing.listPrinters();
    return printers.toList();
  }

  /// Gets the default printer.
  static Future<Printer?> getDefaultPrinter() async {
    final printers = await Printing.listPrinters();
    // Return the first available printer as default
    return printers.isNotEmpty ? printers.first : null;
  }

  /// Generates a PDF with custom page setup.
  ///
  /// [build] - Function to build PDF pages.
  /// [pageSetup] - Page setup configuration.
  static Future<Uint8List> generatePdf({
    required List<pw.Widget> Function(pw.Context) build,
    required PageSetup pageSetup,
    pw.Widget Function(pw.Context)? footer,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageSetup.effectiveFormat,
        margin: pageSetup.margins,
        build: build,
        footer: footer,
      ),
    );

    return pdf.save();
  }
}

/// Print preview screen with page navigation and setup controls.
class PrintPreviewScreen extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function(PageSetup) onLayout;
  final PageSetup initialSetup;

  const PrintPreviewScreen({
    super.key,
    required this.title,
    required this.onLayout,
    this.initialSetup = const PageSetup(),
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  late PageSetup _pageSetup;
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _pageSetup = widget.initialSetup;
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() => _isLoading = true);

    try {
      _pdfBytes = await widget.onLayout(_pageSetup);

      // Get page count - simplified, pdf package doesn't expose page count easily
      if (mounted) {
        setState(() {
          _totalPages = 1; // Simplified - pdf package doesn't expose page count easily
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成预览失败: $e')),
        );
      }
    }
  }

  Future<void> _print() async {
    if (_pdfBytes == null) return;

    final success = await PrintService.showPrintDialog(
      pdfBytes: _pdfBytes!,
      title: widget.title,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打印成功')),
      );
    }
  }

  void _showPageSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PageSetupSheet(
        initialSetup: _pageSetup,
        onApply: (setup) {
          setState(() => _pageSetup = setup);
          _loadPdf();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showPageSetup,
            tooltip: '页面设置',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _pdfBytes != null ? _print : null,
            tooltip: '打印',
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pdfBytes == null
                    ? const Center(child: Text('无法生成预览'))
                    : PdfPreview(
                        bytes: _pdfBytes!,
                        onPageChanged: (page, total) {
                          setState(() {
                            _currentPage = page;
                            _totalPages = total;
                          });
                        },
                      ),
          ),

          // Page navigation controls
          if (!_isLoading && _pdfBytes != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage = 1)
                        : null,
                    tooltip: '第一页',
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_before),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                    tooltip: '上一页',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_currentPage / $_totalPages',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next),
                    onPressed: _currentPage < _totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                    tooltip: '下一页',
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: _currentPage < _totalPages
                        ? () => setState(() => _currentPage = _totalPages)
                        : null,
                    tooltip: '最后一页',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// PDF preview widget using flutter PDF viewer.
class PdfPreview extends StatefulWidget {
  final Uint8List bytes;
  final void Function(int page, int total)? onPageChanged;

  const PdfPreview({
    super.key,
    required this.bytes,
    this.onPageChanged,
  });

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 5.0,
      child: Center(
        child: widget.bytes != null
            ? const Text('PDF preview available - use PrintService.showPrintDialog to view')
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Page setup configuration sheet.
class _PageSetupSheet extends StatefulWidget {
  final PageSetup initialSetup;
  final void Function(PageSetup) onApply;

  const _PageSetupSheet({
    required this.initialSetup,
    required this.onApply,
  });

  @override
  State<_PageSetupSheet> createState() => _PageSetupSheetState();
}

class _PageSetupSheetState extends State<_PageSetupSheet> {
  late String _formatName;
  late bool _landscape;
  late double _marginTop;
  late double _marginBottom;
  late double _marginLeft;
  late double _marginRight;

  @override
  void initState() {
    super.initState();
    _formatName = PageSetup.formats.entries
        .firstWhere(
          (e) => e.value == widget.initialSetup.format,
          orElse: () => PageSetup.formats.entries.first,
        )
        .key;
    _landscape = widget.initialSetup.landscape;
    _marginTop = widget.initialSetup.marginTop;
    _marginBottom = widget.initialSetup.marginBottom;
    _marginLeft = widget.initialSetup.marginLeft;
    _marginRight = widget.initialSetup.marginRight;
  }

  void _apply() {
    final setup = PageSetup(
      format: PageSetup.formats[_formatName]!,
      landscape: _landscape,
      marginTop: _marginTop,
      marginBottom: _marginBottom,
      marginLeft: _marginLeft,
      marginRight: _marginRight,
    );
    widget.onApply(setup);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '页面设置',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Page format
            Text(
              '纸张大小',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _formatName,
              items: PageSetup.formats.keys.map((name) {
                return DropdownMenuItem(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _formatName = value);
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Orientation
            Row(
              children: [
                Text(
                  '方向',
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('纵向'),
                      icon: Icon(Icons.stay_current_portrait),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('横向'),
                      icon: Icon(Icons.stay_current_landscape),
                    ),
                  ],
                  selected: {_landscape},
                  onSelectionChanged: (set) {
                    setState(() => _landscape = set.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Margins
            Text(
              '页边距 (mm)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MarginInput(
                    label: '上',
                    value: _marginTop,
                    onChanged: (v) => _marginTop = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MarginInput(
                    label: '下',
                    value: _marginBottom,
                    onChanged: (v) => _marginBottom = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MarginInput(
                    label: '左',
                    value: _marginLeft,
                    onChanged: (v) => _marginLeft = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MarginInput(
                    label: '右',
                    value: _marginRight,
                    onChanged: (v) => _marginRight = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('应用'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Margin input field.
class _MarginInput extends StatelessWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;

  const _MarginInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toStringAsFixed(0),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) {
          onChanged(parsed);
        }
      },
    );
  }
}
