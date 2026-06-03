import 'dart:convert';
import 'dart:developer';

import 'package:assethub/models/loan_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoanReportScreen extends StatefulWidget {
  final UserModel user;

  const LoanReportScreen({super.key, required this.user});

  @override
  State<LoanReportScreen> createState() => _LoanReportScreenState();
}

class _LoanReportScreenState extends State<LoanReportScreen> {
  final List<LoanRequestModel> _loans = [];
  bool _isLoading = true;

  String get _loadLoanApiUrl => ApiPath.endpoint("load_loan_requests.php");

  bool get _isAdmin => widget.user.role.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadLoanReport();
  }

  @override
  Widget build(BuildContext context) {
    final totalLoans = _loans.length;
    final totalQuantity = _loans.fold<int>(0, (sum, loan) => sum + loan.quantity);
    final pendingCount = _loans.where((loan) => loan.status == 'Pending').length;
    final approvedCount = _loans
        .where((loan) => loan.status == 'Approved')
        .length;
    final returnedCount = _loans.where((loan) => loan.status == 'Returned').length;
    final statusSummary = _buildStatusSummary();
    final categorySummary = _buildCategorySummary();

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Report')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
          ? const Center(child: Text('No loan requests available for report'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Requests',
                        totalLoans.toString(),
                        Icons.assignment_outlined,
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
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        pendingCount.toString(),
                        Icons.hourglass_top_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Approved',
                        approvedCount.toString(),
                        Icons.task_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Returned',
                        returnedCount.toString(),
                        Icons.assignment_returned_outlined,
                      ),
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
                      subtitle: Text(
                        '${entry.value.requestCount} requests | Qty: ${entry.value.totalQuantity}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Summary by Asset Category',
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
                        '${entry.value.requestCount} requests | Qty: ${entry.value.totalQuantity}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isAdmin ? 'Recent Loan Requests' : 'My Recent Requests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._loans.take(8).map(
                  (loan) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.assignment_turned_in_outlined),
                      ),
                      title: Text(loan.assetName),
                      subtitle: Text(
                        '${loan.userName} | ${loan.loanDate} to ${loan.dueDate}',
                      ),
                      trailing: Text(
                        loan.status,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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

  Map<String, _LoanStatusReport> _buildStatusSummary() {
    final summary = <String, _LoanStatusReport>{};

    for (final loan in _loans) {
      final current = summary.putIfAbsent(loan.status, () => _LoanStatusReport());
      current.requestCount += 1;
      current.totalQuantity += loan.quantity;
    }

    final sorted = summary.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in sorted) entry.key: entry.value};
  }

  Map<String, _LoanStatusReport> _buildCategorySummary() {
    final summary = <String, _LoanStatusReport>{};

    for (final loan in _loans) {
      final current = summary.putIfAbsent(
        loan.assetCategory,
        () => _LoanStatusReport(),
      );
      current.requestCount += 1;
      current.totalQuantity += loan.quantity;
    }

    final sorted = summary.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in sorted) entry.key: entry.value};
  }

  Future<void> _loadLoanReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(_loadLoanApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load loan report');
      }

      final data = jsonDecode(response.body);
      log('Loan Report Response: $data');
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to load loan report');
      }

      final loadedLoans = List<LoanRequestModel>.from(
        (data['loans'] ?? []).map(
          (loan) => LoanRequestModel.fromJson(Map<String, dynamic>.from(loan)),
        ),
      );

      if (!mounted) return;
      setState(() {
        _loans
          ..clear()
          ..addAll(loadedLoans);
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
}

class _LoanStatusReport {
  int requestCount = 0;
  int totalQuantity = 0;
}
