import 'dart:convert';
import 'dart:developer';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/models/loan_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoanmanScreen extends StatefulWidget {
  final UserModel user;

  const LoanmanScreen({super.key, required this.user});

  @override
  State<LoanmanScreen> createState() => _LoanmanScreenState();
}

class _LoanmanScreenState extends State<LoanmanScreen> {
  final List<LoanRequestModel> loanRequests = [];
  final List<AssetModel> availableAssets = [];
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController purposeController = TextEditingController();
  final TextEditingController adminNotesController = TextEditingController();

  bool isLoading = true;
  bool isSubmitting = false;
  int? selectedAssetId;
  DateTime? selectedLoanDate;
  DateTime? selectedDueDate;

  bool get isAdmin => widget.user.role.toLowerCase() == 'admin';
  String get loadLoanApiUrl => ApiPath.endpoint("load_loan_requests.php");
  String get requestLoanApiUrl => ApiPath.endpoint("request_loan.php");
  String get updateLoanApiUrl => ApiPath.endpoint("update_loan_request.php");
  String get loadAssetsApiUrl => ApiPath.endpoint("load_assets.php");

  @override
  void initState() {
    super.initState();
    loadLoanData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    purposeController.dispose();
    adminNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Loan Management"),
        actions: [
          IconButton(
            onPressed: loadLoanData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: MyDrawer(user: widget.user),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: availableAssets.isEmpty ? null : showLoanRequestDialog,
              icon: const Icon(Icons.add_task),
              label: const Text('Request Loan'),
            ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCards(),
                Expanded(
                  child: loanRequests.isEmpty
                      ? const Center(child: Text('No loan requests found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: loanRequests.length,
                          itemBuilder: (context, index) {
                            final loan = loanRequests[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                loan.assetName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${loan.assetCategory} | Qty: ${loan.quantity}',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        _buildStatusChip(loan.status),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildLoanDetailRow(
                                      'Member',
                                      '${loan.userName} (${loan.userEmail})',
                                    ),
                                    _buildLoanDetailRow(
                                      'Loan Period',
                                      '${loan.loanDate} until ${loan.dueDate}',
                                    ),
                                    _buildLoanDetailRow('Purpose', loan.purpose),
                                    _buildLoanDetailRow(
                                      'Admin Notes',
                                      loan.adminNotes.isEmpty
                                          ? '-'
                                          : loan.adminNotes,
                                    ),
                                    if (loan.approvedByName.isNotEmpty)
                                      _buildLoanDetailRow(
                                        'Approved By',
                                        loan.approvedByName,
                                      ),
                                    if (loan.returnedAt.isNotEmpty)
                                      _buildLoanDetailRow(
                                        'Returned At',
                                        loan.returnedAt,
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _buildActionButtons(loan),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    final pendingCount = loanRequests
        .where((loan) => loan.status == 'Pending')
        .length;
    final approvedCount = loanRequests
        .where((loan) => loan.status == 'Approved')
        .length;
    final returnedCount = loanRequests
        .where((loan) => loan.status == 'Returned')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            SizedBox(
              width: 220,
              child: _buildInfoCard(
                'Pending Requests',
                pendingCount.toString(),
                Icons.hourglass_top_outlined,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: _buildInfoCard(
                'Approved Loans',
                approvedCount.toString(),
                Icons.task_alt_outlined,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: _buildInfoCard(
                'Returned',
                returnedCount.toString(),
                Icons.assignment_returned_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    switch (status) {
      case 'Approved':
        backgroundColor = Colors.green.shade100;
        break;
      case 'Rejected':
        backgroundColor = Colors.red.shade100;
        break;
      case 'Returned':
        backgroundColor = Colors.blue.shade100;
        break;
      default:
        backgroundColor = Colors.orange.shade100;
    }

    return Chip(
      label: Text(status),
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: Colors.black87,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(LoanRequestModel loan) {
    if (!isAdmin) {
      return [
        Text(
          loan.status == 'Pending' ? 'Awaiting approval' : 'View only',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    if (loan.status == 'Pending') {
      return [
        ElevatedButton(
          onPressed: () => showAdminActionDialog(loan, 'approve'),
          child: const Text('Approve'),
        ),
        OutlinedButton(
          onPressed: () => showAdminActionDialog(loan, 'reject'),
          child: const Text('Reject'),
        ),
      ];
    }

    if (loan.status == 'Approved') {
      return [
        ElevatedButton(
          onPressed: () => showAdminActionDialog(loan, 'return'),
          child: const Text('Mark Returned'),
        ),
      ];
    }

    return [
      Text(
        loan.status,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  Future<void> loadLoanData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loanUri = Uri.parse(loadLoanApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );
      final assetUri = Uri.parse(loadAssetsApiUrl).replace(
        queryParameters: const {
          'page': '1',
          'limit': '100',
          'search': '',
          'category': 'All',
        },
      );

      final loanResponse = await http.get(loanUri);
      final assetResponse = await http.get(assetUri);

      if (loanResponse.statusCode != 200 || assetResponse.statusCode != 200) {
        throw Exception('Failed to load loan management data');
      }

      final loanData = jsonDecode(loanResponse.body);
      final assetData = jsonDecode(assetResponse.body);
      log('Loan Data Response: $loanData');

      if (loanData['status'] != 'success' || assetData['status'] != 'success') {
        throw Exception('Failed to load loan management data');
      }

      final loadedLoans = List<LoanRequestModel>.from(
        (loanData['loans'] ?? []).map(
          (loan) => LoanRequestModel.fromJson(Map<String, dynamic>.from(loan)),
        ),
      );
      final loadedAssets = List<AssetModel>.from(
        (assetData['assets'] ?? []).map(
          (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
        ),
      );

      if (!mounted) return;
      setState(() {
        loanRequests
          ..clear()
          ..addAll(loadedLoans);
        availableAssets
          ..clear()
          ..addAll(loadedAssets.where((asset) => asset.quantity > 0));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loan load error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showLoanRequestDialog() {
    quantityController.clear();
    purposeController.clear();
    selectedAssetId = availableAssets.isNotEmpty ? availableAssets.first.id : null;
    selectedLoanDate = DateTime.now();
    selectedDueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Loan Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedAssetId,
                      decoration: const InputDecoration(labelText: 'Asset'),
                      items: availableAssets
                          .map(
                            (asset) => DropdownMenuItem(
                              value: asset.id,
                              child: Text(
                                '${asset.name} (Available: ${asset.quantity})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedAssetId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: purposeController,
                      decoration: const InputDecoration(labelText: 'Purpose'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Loan Date: ${_formatDate(selectedLoanDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedLoanDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedLoanDate = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Due Date: ${_formatDate(selectedDueDate)}'),
                      trailing: const Icon(Icons.event_available),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate ?? DateTime.now(),
                          firstDate: selectedLoanDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDueDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitLoanRequest,
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> submitLoanRequest() async {
    if (selectedAssetId == null ||
        quantityController.text.isEmpty ||
        purposeController.text.isEmpty ||
        selectedLoanDate == null ||
        selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the loan request form')),
      );
      return;
    }

    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse(requestLoanApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.user.id,
          'asset_id': selectedAssetId,
          'quantity': quantityController.text,
          'purpose': purposeController.text.trim(),
          'loan_date': _formatDate(selectedLoanDate),
          'due_date': _formatDate(selectedDueDate),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan request submitted')),
        );
        await loadLoanData();
      } else {
        throw Exception(data['message'] ?? 'Failed to submit loan request');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void showAdminActionDialog(LoanRequestModel loan, String action) {
    adminNotesController.text = loan.adminNotes;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${_capitalize(action)} Loan Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Member: ${loan.userName}'),
              Text('Asset: ${loan.assetName}'),
              Text('Quantity: ${loan.quantity}'),
              const SizedBox(height: 12),
              TextField(
                controller: adminNotesController,
                decoration: const InputDecoration(
                  labelText: 'Admin Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await updateLoanStatus(loan.id, action, adminNotesController.text);
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: Text(_capitalize(action)),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateLoanStatus(int loanId, String action, String notes) async {
    try {
      final response = await http.post(
        Uri.parse(updateLoanApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'loan_id': loanId,
          'action': action,
          'admin_id': widget.user.id,
          'admin_notes': notes.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Loan request updated')),
        );
        await loadLoanData();
      } else {
        throw Exception(data['message'] ?? 'Failed to update loan request');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update error: $e')));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
