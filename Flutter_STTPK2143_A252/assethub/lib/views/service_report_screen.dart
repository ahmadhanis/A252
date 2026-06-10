import 'dart:convert';
import 'dart:typed_data';

import 'package:assethub/models/service_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ServiceReportScreen extends StatefulWidget {
  final UserModel user;

  const ServiceReportScreen({super.key, required this.user});

  @override
  State<ServiceReportScreen> createState() => _ServiceReportScreenState();
}

class _ServiceReportScreenState extends State<ServiceReportScreen> {
  final List<ServiceRequestModel> _requests = [];
  bool _isLoading = true;
  int? _selectedMonth;
  int? _selectedYear;

  String get _loadServiceApiUrl => ApiPath.endpoint("load_service_requests.php");
  bool get _isAdmin => widget.user.role.toLowerCase() == 'admin';

  List<ServiceRequestModel> get _filteredRequests {
    return _requests.where((request) {
      final parsedDate = _parseDate(request.preferredDate);
      if (parsedDate == null) {
        return _selectedMonth == null && _selectedYear == null;
      }
      if (_selectedMonth != null && parsedDate.month != _selectedMonth) {
        return false;
      }
      if (_selectedYear != null && parsedDate.year != _selectedYear) {
        return false;
      }
      return true;
    }).toList();
  }

  List<int> get _availableYears {
    final years = <int>{};
    for (final request in _requests) {
      final parsedDate = _parseDate(request.preferredDate);
      if (parsedDate != null) {
        years.add(parsedDate.year);
      }
    }
    if (years.isEmpty) {
      years.add(DateTime.now().year);
    }
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    return sortedYears;
  }

  @override
  void initState() {
    super.initState();
    _loadServiceReport();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _filteredRequests;
    final totalRequests = filteredRequests.length;
    final pendingCount = filteredRequests
        .where((request) => request.status == 'Pending')
        .length;
    final inProgressCount = filteredRequests
        .where((request) => request.status == 'In Progress')
        .length;
    final completedCount = filteredRequests
        .where((request) => request.status == 'Completed')
        .length;
    final rejectedCount = filteredRequests
        .where((request) => request.status == 'Rejected')
        .length;
    final statusSummary = _buildStatusSummary(filteredRequests);
    final typeSummary = _buildTypeSummary(filteredRequests);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Request Report'),
        actions: [
          IconButton(
            onPressed: _isLoading || filteredRequests.isEmpty ? null : _printReportPdf,
            tooltip: 'Print PDF',
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(child: Text('No service requests available for report'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildFilterCard(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildResponsiveStatCard(
                      'Total Requests',
                      totalRequests.toString(),
                      Icons.design_services_outlined,
                    ),
                    _buildResponsiveStatCard(
                      'Pending',
                      pendingCount.toString(),
                      Icons.hourglass_top_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildResponsiveStatCard(
                      'In Progress',
                      inProgressCount.toString(),
                      Icons.build_circle_outlined,
                    ),
                    _buildResponsiveStatCard(
                      'Completed',
                      completedCount.toString(),
                      Icons.task_alt_outlined,
                    ),
                    _buildResponsiveStatCard(
                      'Rejected',
                      rejectedCount.toString(),
                      Icons.cancel_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Summary by Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...statusSummary.entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.pie_chart_outline),
                      ),
                      title: Text(entry.key),
                      subtitle: Text('${entry.value.requestCount} requests'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Summary by Service Type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...typeSummary.entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.category_outlined),
                      ),
                      title: Text(entry.key),
                      subtitle: Text('${entry.value.requestCount} requests'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isAdmin ? 'Recent Service Requests' : 'My Recent Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (filteredRequests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No service requests found for the selected month and year'),
                    ),
                  )
                else
                  ...filteredRequests.take(8).map(
                    (request) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.assignment_turned_in_outlined),
                        ),
                        title: Text(request.title),
                        subtitle: Text(
                          '${request.userName} | ${request.serviceType} | ${request.preferredDate}',
                        ),
                        trailing: Text(
                          request.status,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 18),
                SizedBox(width: 8),
                Text(
                  'Report Period',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Months'),
                      ),
                      ...List.generate(
                        12,
                        (index) => DropdownMenuItem<int?>(
                          value: index + 1,
                          child: Text(_monthLabel(index + 1)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedMonth = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Years'),
                      ),
                      ..._availableYears.map(
                        (year) => DropdownMenuItem<int?>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedYear = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildResponsiveStatCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: _buildStatCard(title, value, icon),
    );
  }

  Map<String, _ServiceReportCount> _buildStatusSummary(
    List<ServiceRequestModel> requests,
  ) {
    final summary = <String, _ServiceReportCount>{};

    for (final request in requests) {
      final current = summary.putIfAbsent(
        request.status,
        () => _ServiceReportCount(),
      );
      current.requestCount += 1;
    }

    final sorted = summary.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in sorted) entry.key: entry.value};
  }

  Map<String, _ServiceReportCount> _buildTypeSummary(
    List<ServiceRequestModel> requests,
  ) {
    final summary = <String, _ServiceReportCount>{};

    for (final request in requests) {
      final current = summary.putIfAbsent(
        request.serviceType,
        () => _ServiceReportCount(),
      );
      current.requestCount += 1;
    }

    final sorted = summary.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in sorted) entry.key: entry.value};
  }

  Future<void> _loadServiceReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(_loadServiceApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load service report');
      }

      final data = jsonDecode(response.body);
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to load service report');
      }

      final loadedRequests = List<ServiceRequestModel>.from(
        (data['services'] ?? []).map(
          (item) => ServiceRequestModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(loadedRequests);
        _selectedMonth ??= DateTime.now().month;
        _selectedYear ??= _availableYears.isNotEmpty ? _availableYears.first : DateTime.now().year;
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
    final filteredRequests = _filteredRequests;
    final statusSummary = _buildStatusSummary(filteredRequests);
    final typeSummary = _buildTypeSummary(filteredRequests);
    final generatedAt = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            _isAdmin ? 'Service Request Report' : 'My Service Request Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Report Period: ${_selectedMonth == null ? 'All Months' : _monthLabel(_selectedMonth!)} ${_selectedYear?.toString() ?? 'All Years'}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfSummaryBox('Total Requests', filteredRequests.length.toString()),
              _buildPdfSummaryBox(
                'Pending',
                filteredRequests.where((request) => request.status == 'Pending').length.toString(),
              ),
              _buildPdfSummaryBox(
                'In Progress',
                filteredRequests.where((request) => request.status == 'In Progress').length.toString(),
              ),
              _buildPdfSummaryBox(
                'Completed',
                filteredRequests.where((request) => request.status == 'Completed').length.toString(),
              ),
              _buildPdfSummaryBox(
                'Rejected',
                filteredRequests.where((request) => request.status == 'Rejected').length.toString(),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Summary by Status',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: const ['Status', 'Requests'],
            data: statusSummary.entries
                .map((entry) => [entry.key, entry.value.requestCount.toString()])
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Summary by Service Type',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: const ['Service Type', 'Requests'],
            data: typeSummary.entries
                .map((entry) => [entry.key, entry.value.requestCount.toString()])
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Service Request Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: const ['Title', 'Member', 'Service', 'Preferred Date', 'Status'],
            data: filteredRequests
                .map(
                  (request) => [
                    request.title,
                    request.userName,
                    request.serviceType,
                    request.preferredDate,
                    request.status,
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(String value) {
    return DateTime.tryParse(value);
  }

  String _monthLabel(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
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

class _ServiceReportCount {
  int requestCount = 0;
}
