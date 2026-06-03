import 'dart:convert';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/models/loan_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MainScreen extends StatefulWidget {
  final UserModel user;

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<AssetModel> _assets = [];
  final List<LoanRequestModel> _loans = [];

  bool _isLoading = true;

  bool get _isAdmin => widget.user.role.toLowerCase() == 'admin';
  String get _loadAssetsApiUrl => ApiPath.endpoint("load_assets.php");
  String get _loadLoansApiUrl => ApiPath.endpoint("load_loan_requests.php");

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
    final pendingLoans = _loans.where((loan) => loan.status == 'Pending').length;
    final approvedLoans = _loans
        .where((loan) => loan.status == 'Approved')
        .length;
    final returnedLoans = _loans.where((loan) => loan.status == 'Returned').length;
    final categories = _buildTopCategories();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("AssetHub"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: MyDrawer(user: widget.user),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 16),
                  Text(
                    'App Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        'Asset Records',
                        _assets.length.toString(),
                        Icons.inventory_2_outlined,
                        const Color(0xFFDBEAFE),
                      ),
                      _buildSummaryCard(
                        'Total Quantity',
                        totalQuantity.toString(),
                        Icons.straighten_outlined,
                        const Color(0xFFDCFCE7),
                      ),
                      _buildSummaryCard(
                        _isAdmin ? 'Pending Loans' : 'My Requests',
                        pendingLoans.toString(),
                        Icons.hourglass_top_outlined,
                        const Color(0xFFFEF3C7),
                      ),
                      _buildSummaryCard(
                        'Approved Loans',
                        approvedLoans.toString(),
                        Icons.task_alt_outlined,
                        const Color(0xFFE0E7FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildValueCard(totalValue, returnedLoans),
                  const SizedBox(height: 16),
                  Text(
                    'Top Categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (categories.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No category data available'),
                      ),
                    )
                  else
                    ...categories.map(
                      (category) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              category.name.isEmpty
                                  ? '?'
                                  : category.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(category.name),
                          subtitle: Text(
                            '${category.assetCount} assets | Qty: ${category.totalQuantity}',
                          ),
                          trailing: Text(
                            'RM ${category.totalValue.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _isAdmin ? 'Recent Loan Requests' : 'My Recent Loans',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loans.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No loan requests available'),
                      ),
                    )
                  else
                    ..._loans.take(5).map(
                      (loan) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.assignment_outlined),
                          title: Text(
                            loan.assetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${loan.userName} | ${loan.loanDate} to ${loan.dueDate}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _buildDashboardStatusChip(loan.status),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${widget.user.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.user.role} account | ${widget.user.email}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (widget.user.phone.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Phone: ${widget.user.phone}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: backgroundColor,
            child: Icon(icon, color: const Color(0xFF1E3A8A)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(double totalValue, int returnedLoans) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.payments_outlined, color: Color(0xFF0369A1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Asset Value',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${totalValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Returned',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  returnedLoans.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStatusChip(String status) {
    Color backgroundColor;
    Color foregroundColor;

    switch (status) {
      case 'Approved':
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade900;
        break;
      case 'Rejected':
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade900;
        break;
      case 'Returned':
        backgroundColor = Colors.blue.shade100;
        foregroundColor = Colors.blue.shade900;
        break;
      default:
        backgroundColor = Colors.orange.shade100;
        foregroundColor = Colors.orange.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
    );
  }

  List<_CategorySummary> _buildTopCategories() {
    final summary = <String, _CategorySummary>{};

    for (final asset in _assets) {
      final current = summary.putIfAbsent(
        asset.category,
        () => _CategorySummary(name: asset.category),
      );
      current.assetCount += 1;
      current.totalQuantity += asset.quantity;
      current.totalValue += asset.quantity * asset.price;
    }

    final categories = summary.values.toList()
      ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    return categories.take(5).toList();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firstAssetUri = Uri.parse(_loadAssetsApiUrl).replace(
        queryParameters: const {
          'page': '1',
          'limit': '100',
          'search': '',
          'category': 'All',
        },
      );
      final loansUri = Uri.parse(_loadLoansApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );

      final assetResponse = await http.get(firstAssetUri);
      final loansResponse = await http.get(loansUri);

      if (assetResponse.statusCode != 200 || loansResponse.statusCode != 200) {
        throw Exception('Failed to load dashboard data');
      }

      final firstAssetData = jsonDecode(assetResponse.body);
      final loansData = jsonDecode(loansResponse.body);

      if (firstAssetData['status'] != 'success' || loansData['status'] != 'success') {
        throw Exception('Failed to load dashboard data');
      }

      final totalPages = (firstAssetData['total_pages'] as num?)?.toInt() ?? 1;
      final loadedAssets = List<AssetModel>.from(
        (firstAssetData['assets'] ?? []).map(
          (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
        ),
      );

      for (int page = 2; page <= totalPages; page++) {
        final pageUri = Uri.parse(_loadAssetsApiUrl).replace(
          queryParameters: {
            'page': page.toString(),
            'limit': '100',
            'search': '',
            'category': 'All',
          },
        );
        final response = await http.get(pageUri);
        if (response.statusCode != 200) {
          throw Exception('Failed to load asset page $page');
        }

        final data = jsonDecode(response.body);
        if (data['status'] != 'success') {
          throw Exception(data['message'] ?? 'Failed to load asset page $page');
        }

        loadedAssets.addAll(
          List<AssetModel>.from(
            (data['assets'] ?? []).map(
              (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
            ),
          ),
        );
      }

      final loadedLoans = List<LoanRequestModel>.from(
        (loansData['loans'] ?? []).map(
          (loan) => LoanRequestModel.fromJson(Map<String, dynamic>.from(loan)),
        ),
      );

      if (!mounted) return;
      setState(() {
        _assets
          ..clear()
          ..addAll(loadedAssets);
        _loans
          ..clear()
          ..addAll(loadedLoans);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dashboard load error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _CategorySummary {
  final String name;
  int assetCount = 0;
  int totalQuantity = 0;
  double totalValue = 0;

  _CategorySummary({required this.name});
}
