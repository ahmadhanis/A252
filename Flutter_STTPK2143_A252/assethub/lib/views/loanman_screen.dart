import 'dart:convert';
import 'dart:developer';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/models/loan_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/views/loan_report_screen.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LoanmanScreen extends StatefulWidget {
  final UserModel user;

  const LoanmanScreen({super.key, required this.user});

  @override
  State<LoanmanScreen> createState() => _LoanmanScreenState();
}

class _LoanmanScreenState extends State<LoanmanScreen> {
  final List<LoanRequestModel> loanRequests = [];
  final List<AssetModel> allAssets = [];
  final List<AssetModel> availableAssets = [];
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController purposeController = TextEditingController();
  final TextEditingController adminNotesController = TextEditingController();
  final TextEditingController loanSearchController = TextEditingController();

  bool isLoading = true;
  bool isSubmitting = false;
  DateTime? selectedLoanDate;
  DateTime? selectedDueDate;
  String selectedStatusFilter = 'All';
  final List<_LoanBasketItem> loanBasket = [];

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
    loanSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLoans = _getFilteredLoans();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Loan Management"),
        actions: [
          IconButton(
            onPressed: openLoanReportScreen,
            tooltip: 'Loan Report',
            icon: const Icon(Icons.summarize_outlined),
          ),
          IconButton(
            onPressed: loadLoanData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: MyDrawer(
        user: widget.user,
        currentSection: DrawerSection.loans,
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: availableAssets.isEmpty ? null : showLoanRequestDialog,
              icon: const Icon(Icons.add_task),
              label: const Text('Request Loan'),
            ),
      body: _buildResponsiveBody(
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopSection(filteredLoans.length),
                  Expanded(
                    child: filteredLoans.isEmpty
                        ? const Center(child: Text('No loan requests found'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredLoans.length,
                            itemBuilder: (context, index) {
                              final loan = filteredLoans[index];
                              final statusColor = _statusColor(loan.status);
                              final imageUrl = _assetImageUrl(loan.assetId);
                              final colorScheme = Theme.of(context).colorScheme;
                              return Card(
                                color: colorScheme.surface,
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: colorScheme.outlineVariant),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    showLoanDetailsDialog(loan);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            width: 82,
                                            height: 82,
                                            color: colorScheme.surfaceContainerHighest,
                                            child: imageUrl != null
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        Icon(
                                                          _statusIcon(
                                                            loan.status,
                                                          ),
                                                          size: 34,
                                                          color: statusColor,
                                                        ),
                                                  )
                                                : Icon(
                                                    _statusIcon(loan.status),
                                                    size: 34,
                                                    color: statusColor,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      loan.assetName,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildStatusChip(loan.status),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _buildLoanTag(
                                                    loan.assetCategory,
                                                    const Color(0xFFDBEAFE),
                                                    const Color(0xFF1D4ED8),
                                                  ),
                                                  _buildLoanTag(
                                                    'Qty ${loan.quantity}',
                                                    statusColor.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    statusColor,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              _buildCompactDetailRow(
                                                icon: Icons.person_outline,
                                                label:
                                                    '${loan.userName} | ${loan.userPhone.isEmpty ? '-' : loan.userPhone}',
                                              ),
                                              const SizedBox(height: 6),
                                              _buildCompactDetailRow(
                                                icon: Icons.date_range_outlined,
                                                label:
                                                    '${loan.loanDate} to ${loan.dueDate}',
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                loan.purpose,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                  height: 1.3,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  TextButton(
                                                    onPressed: () {
                                                      showLoanDetailsDialog(loan);
                                                    },
                                                    child: const Text(
                                                      'View Details',
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Wrap(
                                                    alignment:
                                                        WrapAlignment.end,
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children:
                                                        _buildActionButtons(loan),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResponsiveBody(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 1500
            ? 1280.0
            : constraints.maxWidth >= 1100
            ? 1120.0
            : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxWidth,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildTopSection(int visibleCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          _buildOverviewBanner(visibleCount),
          const SizedBox(height: 10),
          _buildSummaryCards(),
          const SizedBox(height: 10),
          _buildFilterCard(),
        ],
      ),
    );
  }

  Widget _buildOverviewBanner(int visibleCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdmin ? 'Loan Approval Center' : 'My Loan Requests',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAdmin
                ? 'Review requests, contact borrowers, and update statuses.'
                : 'Track your request progress and borrowing history.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildHeaderPill(Icons.list_alt_outlined, '$visibleCount visible'),
              _buildHeaderPill(
                Icons.filter_alt_outlined,
                selectedStatusFilter == 'All'
                    ? 'All statuses'
                    : selectedStatusFilter,
              ),
              _buildHeaderPill(
                Icons.search_outlined,
                loanSearchController.text.trim().isEmpty
                    ? 'No search'
                    : 'Search active',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            SizedBox(
              width: 176,
              child: _buildInfoCard(
                'Pending Requests',
                pendingCount.toString(),
                Icons.hourglass_top_outlined,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 176,
              child: _buildInfoCard(
                'Approved Loans',
                approvedCount.toString(),
                Icons.task_alt_outlined,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 156,
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
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Icon(icon, size: 16, color: const Color(0xFF1E3A8A)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_outlined, size: 18, color: Color(0xFF1E3A8A)),
              SizedBox(width: 6),
              Text(
                'Search and Filter',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 7,
                child: TextField(
                  controller: loanSearchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Search loan requests',
                    hintText: 'Asset, member, phone, purpose',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    suffixIcon: loanSearchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              loanSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    'All',
                    'Pending',
                    'Approved',
                    'Rejected',
                    'Returned',
                  ].map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ),
                  ).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatusFilter = value ?? 'All';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<LoanRequestModel> _getFilteredLoans() {
    final search = loanSearchController.text.trim().toLowerCase();

    return loanRequests.where((loan) {
      final matchesStatus =
          selectedStatusFilter == 'All' || loan.status == selectedStatusFilter;
      final matchesSearch =
          search.isEmpty ||
          loan.assetName.toLowerCase().contains(search) ||
          loan.assetCategory.toLowerCase().contains(search) ||
          loan.userName.toLowerCase().contains(search) ||
          loan.userEmail.toLowerCase().contains(search) ||
          loan.userPhone.toLowerCase().contains(search) ||
          loan.purpose.toLowerCase().contains(search);

      return matchesStatus && matchesSearch;
    }).toList();
  }


  Widget _buildStatusChip(String status) {
    final baseColor = _statusColor(status);

    return Chip(
      label: Text(status),
      backgroundColor: baseColor.withValues(alpha: 0.12),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(fontSize: 12, color: baseColor),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildLoanTag(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return const Color(0xFF15803D);
      case 'Rejected':
        return const Color(0xFFB91C1C);
      case 'Returned':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFFB45309);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.task_alt_outlined;
      case 'Rejected':
        return Icons.cancel_outlined;
      case 'Returned':
        return Icons.assignment_returned_outlined;
      default:
        return Icons.hourglass_top_outlined;
    }
  }

  String? _assetImageUrl(int assetId) {
    try {
      final asset = allAssets.firstWhere((item) => item.id == assetId);
      if (asset.image.isEmpty) return null;
      return '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/assets/${asset.image}';
    } catch (_) {
      return null;
    }
  }

  Widget _buildCompactDetailRow({
    required IconData icon,
    required String label,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
        ],
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
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Approve', style: TextStyle(fontSize: 12)),
        ),
        OutlinedButton(
          onPressed: () => showAdminActionDialog(loan, 'reject'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Reject', style: TextStyle(fontSize: 12)),
        ),
      ];
    }

    if (loan.status == 'Approved') {
      return [
        ElevatedButton(
          onPressed: () => showAdminActionDialog(loan, 'return'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Mark Returned', style: TextStyle(fontSize: 12)),
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

  void showLoanDetailsDialog(LoanRequestModel loan) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final statusColor = _statusColor(loan.status);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Loan Request Details'),
                    const SizedBox(height: 4),
                    Text(
                      loan.assetName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(loan.status),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width > 640
                ? 520
                : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogSectionTitle('Loan Summary'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLoanDetailRow(
                                'Category',
                                loan.assetCategory,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildLoanDetailRow(
                                'Quantity',
                                loan.quantity.toString(),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLoanDetailRow(
                                'Loan Date',
                                loan.loanDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildLoanDetailRow(
                                'Due Date',
                                loan.dueDate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDialogSectionTitle('Borrower'),
                  const SizedBox(height: 8),
                  _buildBorrowerProfileCard(loan),
                  const SizedBox(height: 12),
                  _buildLoanDetailRow(
                    'Member',
                    '${loan.userName} (${loan.userEmail})',
                  ),
                  _buildLoanDetailRow(
                    'Phone Number',
                    loan.userPhone.isEmpty ? '-' : loan.userPhone,
                  ),
                  if (loan.userPhone.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _launchPhoneCall(loan.userPhone),
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _launchWhatsApp(loan.userPhone),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildDialogSectionTitle('Purpose and Notes'),
                  const SizedBox(height: 8),
                  _buildLoanDetailRow('Purpose', loan.purpose),
                  _buildLoanDetailRow(
                    'Admin Notes',
                    loan.adminNotes.isEmpty ? '-' : loan.adminNotes,
                  ),
                  const SizedBox(height: 14),
                  _buildDialogSectionTitle('Audit Trail'),
                  const SizedBox(height: 8),
                  _buildLoanDetailRow('Requested At', loan.createdAt),
                  if (loan.approvedByName.isNotEmpty)
                    _buildLoanDetailRow('Approved By', loan.approvedByName),
                  if (loan.approvedAt.isNotEmpty)
                    _buildLoanDetailRow('Approved At', loan.approvedAt),
                  if (loan.returnedAt.isNotEmpty)
                    _buildLoanDetailRow('Returned At', loan.returnedAt),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBorrowerProfileCard(LoanRequestModel loan) {
    final profileImageName = loan.userProfileImage.trim();
    final profileImageUrl = profileImageName.isEmpty
        ? null
        : '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/profiles/$profileImageName?v=${profileImageName.hashCode}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFDBEAFE),
            child: profileImageUrl == null
                ? _buildBorrowerInitial(loan.userName)
                : ClipOval(
                    child: Image.network(
                      profileImageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildBorrowerInitial(loan.userName),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loan.userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                if (loan.userPhone.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    loan.userPhone,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowerInitial(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _buildDialogSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
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
        allAssets
          ..clear()
          ..addAll(loadedAssets);
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

  void openLoanReportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanReportScreen(user: widget.user),
      ),
    );
  }

  void showLoanRequestDialog() {
    purposeController.clear();
    quantityController.clear();
    loanBasket.clear();
    selectedLoanDate = DateTime.now();
    selectedDueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text('New Loan Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Pick an asset, enter the quantity, and select the loan period for approval.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Basket (${loanBasket.length} items)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: availableAssets.isEmpty
                              ? null
                              : () => showAssetBasketPickerDialog(setDialogState),
                          icon: const Icon(Icons.search_outlined),
                          label: const Text('Search Items'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loanBasket.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'No items in basket yet. Search and add assets before submitting.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      ...loanBasket.map(
                        (item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.asset.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.asset.category} | Qty: ${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    loanBasket.removeWhere(
                                      (basketItem) =>
                                          basketItem.asset.id == item.asset.id,
                                    );
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: purposeController,
                      decoration: _buildDialogInputDecoration('Purpose'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    _buildDatePickerTile(
                      title: 'Loan Date',
                      value: _formatDate(selectedLoanDate),
                      icon: Icons.calendar_month_outlined,
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
                    const SizedBox(height: 10),
                    _buildDatePickerTile(
                      title: 'Due Date',
                      value: _formatDate(selectedDueDate),
                      icon: Icons.event_available_outlined,
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
                ElevatedButton.icon(
                  onPressed: submitLoanRequest,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showAssetBasketPickerDialog(StateSetter parentSetState) {
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filteredAssets = availableAssets.where((asset) {
              final search = searchController.text.trim().toLowerCase();
              if (search.isEmpty) return true;
              return asset.name.toLowerCase().contains(search) ||
                  asset.category.toLowerCase().contains(search) ||
                  asset.description.toLowerCase().contains(search);
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              title: const Text('Search Items'),
              content: SizedBox(
                width: MediaQuery.of(dialogContext).size.width > 640
                    ? 520
                    : double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Browse Available Assets',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search by name, category, or description and add items into your loan basket.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setPickerState(() {}),
                      decoration: _buildDialogInputDecoration('Search assets').copyWith(
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${filteredAssets.length} item${filteredAssets.length == 1 ? '' : 's'} found',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Basket: ${loanBasket.length}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 400,
                      child: filteredAssets.isEmpty
                          ? Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_outlined,
                                    size: 40,
                                    color: Colors.black38,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'No matching assets found',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Try another keyword or browse all items.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredAssets.length,
                              itemBuilder: (context, index) {
                                final asset = filteredAssets[index];
                                final imageUrl = _assetImageUrl(asset.id);
                                final alreadyInBasket = loanBasket.any(
                                  (item) => item.asset.id == asset.id,
                                );
                                final stockColor = asset.quantity <= 2
                                    ? const Color(0xFFB91C1C)
                                    : asset.quantity <= 5
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF166534);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Container(
                                            width: 64,
                                            height: 64,
                                            color: const Color(0xFFF1F5F9),
                                            child: imageUrl != null
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, _, _) => const Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons
                                                        .inventory_2_outlined,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                asset.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  _buildLoanTag(
                                                    asset.category,
                                                    const Color(0xFFDBEAFE),
                                                    const Color(0xFF1D4ED8),
                                                  ),
                                                  _buildLoanTag(
                                                    'Available ${asset.quantity}',
                                                    stockColor.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    stockColor,
                                                  ),
                                                ],
                                              ),
                                              if (asset.description
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  asset.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          children: [
                                            if (alreadyInBasket)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDCFCE7,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: const Text(
                                                  'In Basket',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF166534),
                                                  ),
                                                ),
                                              ),
                                            if (alreadyInBasket) ...[
                                              FilledButton(
                                                onPressed: () =>
                                                    _showAddToBasketDialog(
                                                      asset,
                                                      parentSetState,
                                                      dialogContext,
                                                    ),
                                                style: FilledButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                child: const Text('Update'),
                                              ),
                                              const SizedBox(height: 6),
                                              OutlinedButton(
                                                onPressed: () {
                                                  parentSetState(() {
                                                    loanBasket.removeWhere(
                                                      (item) =>
                                                          item.asset.id ==
                                                          asset.id,
                                                    );
                                                  });
                                                  setPickerState(() {});
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                child: const Text('Remove'),
                                              ),
                                            ] else
                                              FilledButton(
                                                onPressed:
                                                    () => _showAddToBasketDialog(
                                                      asset,
                                                      parentSetState,
                                                      dialogContext,
                                                    ),
                                                style: FilledButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                                child: const Text('Add'),
                                              ),
                                          ],
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddToBasketDialog(
    AssetModel asset,
    StateSetter parentSetState,
    BuildContext pickerContext,
  ) {
    final quantityTextController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Add to Basket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Available: ${asset.quantity}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityTextController,
                decoration: _buildDialogInputDecoration('Quantity'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity =
                    int.tryParse(quantityTextController.text.trim()) ?? 0;
                if (quantity <= 0 || quantity > asset.quantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Enter a quantity between 1 and ${asset.quantity}',
                      ),
                    ),
                  );
                  return;
                }

                parentSetState(() {
                  final existingIndex = loanBasket.indexWhere(
                    (item) => item.asset.id == asset.id,
                  );
                  if (existingIndex >= 0) {
                    loanBasket[existingIndex] = _LoanBasketItem(
                      asset: asset,
                      quantity: quantity,
                    );
                  } else {
                    loanBasket.add(
                      _LoanBasketItem(asset: asset, quantity: quantity),
                    );
                  }
                });
                Navigator.pop(dialogContext);
                Navigator.pop(pickerContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatePickerTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(value),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildDialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Future<void> submitLoanRequest() async {
    if (loanBasket.isEmpty ||
        purposeController.text.isEmpty ||
        selectedLoanDate == null ||
        selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the loan request form')),
      );
      return;
    }

    if (widget.user.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please register with a phone number before requesting a loan'),
        ),
      );
      return;
    }

    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      for (final item in loanBasket) {
        final response = await http.post(
          Uri.parse(requestLoanApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': widget.user.id,
            'asset_id': item.asset.id,
            'quantity': item.quantity,
            'purpose': purposeController.text.trim(),
            'loan_date': _formatDate(selectedLoanDate),
            'due_date': _formatDate(selectedDueDate),
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode != 200 || data['status'] != 'success') {
          throw Exception(
            data['message'] ??
                'Failed to submit loan request for ${item.asset.name}',
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loanBasket.length} loan request${loanBasket.length > 1 ? 's' : ''} submitted',
          ),
        ),
      );
      await loadLoanData();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text('${_capitalize(action)} Loan Request'),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width > 640
                ? 460
                : double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Member: ${loan.userName}'),
                      const SizedBox(height: 4),
                      Text('Asset: ${loan.assetName}'),
                      const SizedBox(height: 4),
                      Text('Quantity: ${loan.quantity}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adminNotesController,
                  decoration: _buildDialogInputDecoration('Admin Notes'),
                  maxLines: 3,
                ),
              ],
            ),
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
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneForCall(phoneNumber);
    final callUri = Uri(scheme: 'tel', path: normalizedPhone);
    await _launchExternalUri(callUri, 'Unable to start phone call');
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneForWhatsApp(phoneNumber);
    final whatsappUri = Uri.parse('https://wa.me/$normalizedPhone');
    await _launchExternalUri(whatsappUri, 'Unable to open WhatsApp');
  }

  Future<void> _launchExternalUri(Uri uri, String errorMessage) async {
    try {
      final didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  String _normalizePhoneForCall(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _normalizePhoneForWhatsApp(String phoneNumber) {
    var digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '6$digits';
    }
    return digits;
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

class _LoanBasketItem {
  final AssetModel asset;
  final int quantity;

  const _LoanBasketItem({
    required this.asset,
    required this.quantity,
  });
}
