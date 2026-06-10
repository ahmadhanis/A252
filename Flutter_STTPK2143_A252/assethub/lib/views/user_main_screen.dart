import 'dart:convert';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/models/loan_request_model.dart';
import 'package:assethub/models/service_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/views/loanman_screen.dart';
import 'package:assethub/views/servicereq_screen.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserMainScreen extends StatefulWidget {
  final UserModel user;

  const UserMainScreen({super.key, required this.user});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  final List<AssetModel> _assets = [];
  final List<LoanRequestModel> _loans = [];
  final List<ServiceRequestModel> _services = [];
  bool _isLoading = true;

  String get _loadAssetsApiUrl => ApiPath.endpoint("load_assets.php");
  String get _loadLoansApiUrl => ApiPath.endpoint("load_loan_requests.php");
  String get _loadServicesApiUrl => ApiPath.endpoint("load_service_requests.php");

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final pendingLoans = _loans.where((loan) => loan.status == 'Pending').length;
    final activeLoans = _loans.where((loan) => loan.status == 'Approved').length;
    final pendingServices = _services
        .where((service) => service.status == 'Pending')
        .length;
    final inProgressServices = _services
        .where((service) => service.status == 'In Progress')
        .length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("AssetHub"),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: MyDrawer(
        user: widget.user,
        currentSection: DrawerSection.dashboard,
      ),
      body: _buildResponsiveBody(
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 16),
                  Text(
                    'My Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = [
                        _buildSummaryCard(
                          'Available Assets',
                          _assets.length.toString(),
                          Icons.inventory_2_outlined,
                          const Color(0xFFDBEAFE),
                        ),
                        _buildSummaryCard(
                          'Pending Loans',
                          pendingLoans.toString(),
                          Icons.hourglass_top_outlined,
                          const Color(0xFFFEF3C7),
                        ),
                        _buildSummaryCard(
                          'Active Loans',
                          activeLoans.toString(),
                          Icons.assignment_return_outlined,
                          const Color(0xFFDCFCE7),
                        ),
                        _buildSummaryCard(
                          'Service Requests',
                          _services.length.toString(),
                          Icons.design_services_outlined,
                          const Color(0xFFE0E7FF),
                        ),
                      ];

                      if (constraints.maxWidth >= 900) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cards.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 2.8,
                              ),
                          itemBuilder: (context, index) => cards[index],
                        );
                      }

                      return Column(
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            cards[i],
                            if (i != cards.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                    Card(
                      color: colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(
                                Icons.bolt_outlined,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Requests In Progress',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    inProgressServices.toString(),
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
                                Text(
                                  'Pending Services',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pendingServices.toString(),
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
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 640;
                        if (stacked) {
                          return Column(
                            children: [
                              _buildActionTile(
                                label: 'Loan Request',
                                icon: Icons.assignment_return_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          LoanmanScreen(user: widget.user),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildActionTile(
                                label: 'Service Request',
                                icon: Icons.design_services_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ServicereqScreen(user: widget.user),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _buildActionTile(
                                label: 'Loan Request',
                                icon: Icons.assignment_return_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          LoanmanScreen(user: widget.user),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionTile(
                                label: 'Service Request',
                                icon: Icons.design_services_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ServicereqScreen(user: widget.user),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'My Recent Loans',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loans.isEmpty)
                      Card(
                        color: colorScheme.surface,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No loan requests available'),
                        ),
                      )
                    else
                      ..._loans.take(4).map(
                        (loan) => Card(
                          color: colorScheme.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.assignment_outlined),
                            title: Text(
                              loan.assetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${loan.loanDate} to ${loan.dueDate}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _buildStatusChip(loan.status),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'My Recent Services',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_services.isEmpty)
                      Card(
                        color: colorScheme.surface,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No service requests available'),
                        ),
                      )
                    else
                      ..._services.take(4).map(
                        (service) => Card(
                          color: colorScheme.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.design_services_outlined),
                            title: Text(
                              service.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${service.serviceType} | ${service.preferredDate}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _buildStatusChip(service.status),
                          ),
                        ),
                      ),
                  ],
                ),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 4),
          Text(
            'Phone: ${widget.user.phone}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: backgroundColor,
            child: Icon(icon, color: const Color(0xFF1E3A8A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Icon(icon, color: const Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color foregroundColor;

    switch (status) {
      case 'Approved':
      case 'Completed':
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade900;
        break;
      case 'Rejected':
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade900;
        break;
      case 'Returned':
      case 'In Progress':
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

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final assetUri = Uri.parse(_loadAssetsApiUrl).replace(
        queryParameters: const {
          'page': '1',
          'limit': '100',
          'search': '',
          'category': 'All',
        },
      );
      final loanUri = Uri.parse(_loadLoansApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );
      final serviceUri = Uri.parse(_loadServicesApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );

      final assetResponse = await http.get(assetUri);
      final loanResponse = await http.get(loanUri);
      final serviceResponse = await http.get(serviceUri);

      if (assetResponse.statusCode != 200 ||
          loanResponse.statusCode != 200 ||
          serviceResponse.statusCode != 200) {
        throw Exception('Failed to load user dashboard data');
      }

      final assetData = jsonDecode(assetResponse.body);
      final loanData = jsonDecode(loanResponse.body);
      final serviceData = jsonDecode(serviceResponse.body);

      if (assetData['status'] != 'success' ||
          loanData['status'] != 'success' ||
          serviceData['status'] != 'success') {
        throw Exception('Failed to load user dashboard data');
      }

      final loadedAssets = List<AssetModel>.from(
        (assetData['assets'] ?? []).map(
          (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
        ),
      );
      final loadedLoans = List<LoanRequestModel>.from(
        (loanData['loans'] ?? []).map(
          (loan) => LoanRequestModel.fromJson(Map<String, dynamic>.from(loan)),
        ),
      );
      final loadedServices = List<ServiceRequestModel>.from(
        (serviceData['services'] ?? []).map(
          (service) => ServiceRequestModel.fromJson(
            Map<String, dynamic>.from(service),
          ),
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
        _services
          ..clear()
          ..addAll(loadedServices);
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
