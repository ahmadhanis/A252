import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AssetReportScreen extends StatefulWidget {
  const AssetReportScreen({super.key});

  @override
  State<AssetReportScreen> createState() => _AssetReportScreenState();
}

class _AssetReportScreenState extends State<AssetReportScreen> {
  final List<AssetModel> _assets = [];
  bool _isLoading = true;

  String get loadApiUrl => ApiPath.endpoint("load_assets.php");

  @override
  void initState() {
    super.initState();
    _loadFullAssetReport();
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantity = _assets.fold<int>(
      0,
      (sum, asset) => sum + asset.quantity,
    );
    final totalValue = _assets.fold<double>(
      0,
      (sum, asset) => sum + (asset.price * asset.quantity),
    );
    final categorySummary = _buildCategorySummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lab Asset Report"),
        actions: [
          IconButton(
            onPressed: _isLoading || _assets.isEmpty ? null : _printReportPdf,
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
          ? const Center(child: Text("No assets available for report"))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Asset Records',
                        _assets.length.toString(),
                        Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Quantity',
                        totalQuantity.toString(),
                        Icons.format_list_numbered,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  'Estimated Lab Asset Value',
                  'RM ${totalValue.toStringAsFixed(2)}',
                  Icons.payments_outlined,
                ),
                const SizedBox(height: 16),
                Text(
                  'Summary by Category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...categorySummary.entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.category_outlined),
                      ),
                      title: Text(entry.key),
                      subtitle: Text(
                        '${entry.value.assetCount} assets | Qty: ${entry.value.totalQuantity}',
                      ),
                      trailing: Text(
                        'RM ${entry.value.totalValue.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, _CategoryReport> _buildCategorySummary() {
    final summary = <String, _CategoryReport>{};

    for (final asset in _assets) {
      final current = summary.putIfAbsent(
        asset.category,
        () => _CategoryReport(),
      );
      current.assetCount += 1;
      current.totalQuantity += asset.quantity;
      current.totalValue += asset.quantity * asset.price;
    }

    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in sortedEntries) entry.key: entry.value};
  }

  Future<void> _loadFullAssetReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firstPageUri = Uri.parse(loadApiUrl).replace(
        queryParameters: const {
          'page': '1',
          'limit': '100',
          'search': '',
          'category': 'All',
        },
      );
      final firstResponse = await http.get(firstPageUri);
      if (firstResponse.statusCode != 200) {
        throw Exception('Failed to load asset report');
      }

      final firstData = jsonDecode(firstResponse.body);
      log('Asset Report Response: $firstData');
      if (firstData['status'] != 'success') {
        throw Exception(firstData['message'] ?? 'Failed to load asset report');
      }

      final totalPages = (firstData['total_pages'] as num?)?.toInt() ?? 1;
      final collectedAssets = List<AssetModel>.from(
        (firstData['assets'] ?? []).map(
          (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
        ),
      );

      for (int page = 2; page <= totalPages; page++) {
        final pageUri = Uri.parse(loadApiUrl).replace(
          queryParameters: {
            'page': page.toString(),
            'limit': '100',
            'search': '',
            'category': 'All',
          },
        );
        final response = await http.get(pageUri);
        if (response.statusCode != 200) {
          throw Exception('Failed to load asset report page $page');
        }

        final data = jsonDecode(response.body);
        if (data['status'] != 'success') {
          throw Exception(
            data['message'] ?? 'Failed to load asset report page $page',
          );
        }

        collectedAssets.addAll(
          List<AssetModel>.from(
            (data['assets'] ?? []).map(
              (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _assets
          ..clear()
          ..addAll(collectedAssets);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report load error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _printReportPdf() async {
    try {
      final pdfBytes = await _buildReportPdf();
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export error: $e')));
    }
  }

  Future<Uint8List> _buildReportPdf() async {
    final pdf = pw.Document();
    final totalQuantity = _assets.fold<int>(
      0,
      (sum, asset) => sum + asset.quantity,
    );
    final totalValue = _assets.fold<double>(
      0,
      (sum, asset) => sum + (asset.price * asset.quantity),
    );
    final categorySummary = _buildCategorySummary();
    final generatedAt = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Lab Asset Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated on ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfSummaryBox('Asset Records', _assets.length.toString()),
              _buildPdfSummaryBox('Total Quantity', totalQuantity.toString()),
              _buildPdfSummaryBox(
                'Total Value',
                'RM ${totalValue.toStringAsFixed(2)}',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Summary by Category',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Category', 'Assets', 'Quantity', 'Value (RM)'],
            data: categorySummary.entries
                .map(
                  (entry) => [
                    entry.key,
                    entry.value.assetCount.toString(),
                    entry.value.totalQuantity.toString(),
                    entry.value.totalValue.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Asset Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Asset', 'Category', 'Qty', 'Unit Price', 'Value'],
            data: _assets
                .map(
                  (asset) => [
                    asset.name,
                    asset.category,
                    asset.quantity.toString(),
                    'RM ${asset.price.toStringAsFixed(2)}',
                    'RM ${(asset.price * asset.quantity).toStringAsFixed(2)}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSummaryBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _CategoryReport {
  int assetCount = 0;
  int totalQuantity = 0;
  double totalValue = 0;
}
