import 'dart:convert';

import 'package:assethub/models/service_request_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/views/service_report_screen.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ServicereqScreen extends StatefulWidget {
  final UserModel user;

  const ServicereqScreen({super.key, required this.user});

  @override
  State<ServicereqScreen> createState() => _ServicereqScreenState();
}

class _ServicereqScreenState extends State<ServicereqScreen> {
  static const List<String> serviceTypes = [
    'Laser Cutting',
    '3D Design',
    '3D Printing',
    'Soldering',
    'Assembly',
    'CNC Machining',
    'Electronics Repair',
    'PCB Fabrication',
    'Prototyping',
    'Woodworking',
    'Acrylic Fabrication',
    'Consultation',
    'Training',
    'Other',
  ];

  final List<ServiceRequestModel> serviceRequests = [];
  final TextEditingController searchController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();
  final TextEditingController adminNotesController = TextEditingController();

  bool isLoading = true;
  bool isSubmitting = false;
  String selectedStatusFilter = 'All';
  String selectedServiceType = serviceTypes.first;
  DateTime? selectedPreferredDate;

  bool get isAdmin => widget.user.role.toLowerCase() == 'admin';
  String get loadServiceApiUrl => ApiPath.endpoint("load_service_requests.php");
  String get requestServiceApiUrl => ApiPath.endpoint("request_service.php");
  String get updateServiceApiUrl => ApiPath.endpoint("update_service_request.php");

  @override
  void initState() {
    super.initState();
    loadServiceRequests();
  }

  @override
  void dispose() {
    searchController.dispose();
    titleController.dispose();
    detailsController.dispose();
    adminNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _getFilteredRequests();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Service Requests'),
        actions: [
          IconButton(
            onPressed: openServiceReportScreen,
            tooltip: 'Service Report',
            icon: const Icon(Icons.summarize_outlined),
          ),
          IconButton(
            onPressed: loadServiceRequests,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: MyDrawer(
        user: widget.user,
        currentSection: DrawerSection.services,
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: showServiceRequestDialog,
              icon: const Icon(Icons.add_task),
              label: const Text('Request Service'),
            ),
      body: _buildResponsiveBody(
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopSection(filteredRequests.length),
                  Expanded(
                    child: filteredRequests.isEmpty
                        ? const Center(child: Text('No service requests found'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredRequests.length,
                            itemBuilder: (context, index) {
                              final request = filteredRequests[index];
                              final statusColor = _statusColor(request.status);
                              final colorScheme = Theme.of(context).colorScheme;

                              return Card(
                                color: colorScheme.surface,
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: colorScheme.outlineVariant),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => showServiceDetailsDialog(request),
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
                                            color: statusColor.withValues(alpha: 0.12),
                                            child: Icon(
                                              _serviceIcon(request.serviceType),
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
                                                      request.title,
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
                                                  _buildStatusChip(request.status),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _buildTag(
                                                    request.serviceType,
                                                    const Color(0xFFDBEAFE),
                                                    const Color(0xFF1D4ED8),
                                                  ),
                                                  _buildTag(
                                                    request.preferredDate,
                                                    statusColor.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    statusColor,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              _buildCompactRow(
                                                icon: Icons.person_outline,
                                                label:
                                                    '${request.userName} | ${request.userPhone.isEmpty ? '-' : request.userPhone}',
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                request.details,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                  height: 1.3,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  TextButton(
                                                    onPressed: () {
                                                      showServiceDetailsDialog(
                                                        request,
                                                      );
                                                    },
                                                    child: const Text(
                                                      'View Details',
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children:
                                                        _buildActionButtons(
                                                          request,
                                                        ),
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
    final pendingCount = serviceRequests
        .where((request) => request.status == 'Pending')
        .length;
    final inProgressCount = serviceRequests
        .where((request) => request.status == 'In Progress')
        .length;
    final completedCount = serviceRequests
        .where((request) => request.status == 'Completed')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Container(
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
                  isAdmin ? 'Service Request Center' : 'My Service Requests',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Manage fabrication and support requests from members.'
                      : 'Request makerspace services like laser cutting, 3D printing, and assembly.',
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
                    _buildHeaderPill(
                      Icons.design_services_outlined,
                      '$visibleCount visible',
                    ),
                    _buildHeaderPill(
                      Icons.filter_alt_outlined,
                      selectedStatusFilter == 'All'
                          ? 'All statuses'
                          : selectedStatusFilter,
                    ),
                    _buildHeaderPill(
                      Icons.search_outlined,
                      searchController.text.trim().isEmpty
                          ? 'No search'
                          : 'Search active',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SizedBox(
                  width: 176,
                  child: _buildInfoCard(
                    'Pending',
                    pendingCount.toString(),
                    Icons.hourglass_top_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 176,
                  child: _buildInfoCard(
                    'In Progress',
                    inProgressCount.toString(),
                    Icons.build_circle_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 176,
                  child: _buildInfoCard(
                    'Completed',
                    completedCount.toString(),
                    Icons.task_alt_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildFilterCard(),
        ],
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
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Search requests',
                    hintText: 'Service, title, member, phone',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
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
                    'In Progress',
                    'Completed',
                    'Rejected',
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

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Chip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.12),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(fontSize: 12, color: color),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildTag(String label, Color backgroundColor, Color textColor) {
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

  Widget _buildCompactRow({required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  List<ServiceRequestModel> _getFilteredRequests() {
    final search = searchController.text.trim().toLowerCase();

    return serviceRequests.where((request) {
      final matchesStatus =
          selectedStatusFilter == 'All' ||
          request.status == selectedStatusFilter;
      final matchesSearch =
          search.isEmpty ||
          request.serviceType.toLowerCase().contains(search) ||
          request.title.toLowerCase().contains(search) ||
          request.details.toLowerCase().contains(search) ||
          request.userName.toLowerCase().contains(search) ||
          request.userEmail.toLowerCase().contains(search) ||
          request.userPhone.toLowerCase().contains(search);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<Widget> _buildActionButtons(ServiceRequestModel request) {
    if (!isAdmin) {
      return [
        Text(
          request.status == 'Pending' ? 'Awaiting review' : 'View only',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    return [
      OutlinedButton(
        onPressed: () => showUpdateStatusDialog(request),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Update', style: TextStyle(fontSize: 12)),
      ),
    ];
  }

  void showServiceDetailsDialog(ServiceRequestModel request) {
    final statusColor = _statusColor(request.status);
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Service Request Details'),
                    const SizedBox(height: 4),
                    Text(
                      request.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(request.status),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width > 640
                ? 520
                : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
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
                        Text(
                          'Request Summary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionInfoRow(
                                'Service Type',
                                request.serviceType,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionInfoRow(
                                'Preferred Date',
                                request.preferredDate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildActionInfoRow(
                    'Member',
                    '${request.userName} (${request.userEmail})',
                  ),
                  _buildActionInfoRow(
                    'Phone Number',
                    request.userPhone.isEmpty ? '-' : request.userPhone,
                  ),
                  _buildActionInfoRow('Details', request.details),
                  _buildActionInfoRow(
                    'Admin Notes',
                    request.adminNotes.isEmpty ? '-' : request.adminNotes,
                  ),
                  _buildActionInfoRow('Created At', request.createdAt),
                  _buildActionInfoRow('Updated At', request.updatedAt),
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

  void showServiceRequestDialog() {
    titleController.clear();
    detailsController.clear();
    selectedServiceType = serviceTypes.first;
    selectedPreferredDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text('New Service Request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Request services such as laser cutting, 3D printing, soldering, assembly, or consultation.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedServiceType,
                      decoration: _buildDialogInputDecoration('Service Type'),
                      items: serviceTypes
                          .map(
                            (service) => DropdownMenuItem(
                              value: service,
                              child: Text(service),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedServiceType = value ?? serviceTypes.first;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: _buildDialogInputDecoration('Request Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: detailsController,
                      decoration: _buildDialogInputDecoration('Details'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 10),
                    _buildDatePickerTile(
                      title: 'Preferred Date',
                      value: _formatDate(selectedPreferredDate),
                      icon: Icons.calendar_month_outlined,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedPreferredDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedPreferredDate = picked;
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
                  onPressed: submitServiceRequest,
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

  void showUpdateStatusDialog(ServiceRequestModel request) {
    adminNotesController.text = request.adminNotes;
    String dialogStatus = request.status;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text('Update Service Request'),
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
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Member: ${request.userName}'),
                          const SizedBox(height: 4),
                          Text('Service: ${request.serviceType}'),
                          const SizedBox(height: 4),
                          Text('Title: ${request.title}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: dialogStatus,
                      decoration: _buildDialogInputDecoration('Status'),
                      items: const [
                        'Pending',
                        'In Progress',
                        'Completed',
                        'Rejected',
                      ].map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      ).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          dialogStatus = value ?? request.status;
                        });
                      },
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
                    await updateServiceRequest(
                      request.id,
                      dialogStatus,
                      adminNotesController.text,
                    );
                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> loadServiceRequests() async {
    setState(() {
      isLoading = true;
    });

    try {
      final uri = Uri.parse(loadServiceApiUrl).replace(
        queryParameters: {
          'role': widget.user.role,
          'user_id': widget.user.id.toString(),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load service requests');
      }

      final data = jsonDecode(response.body);
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to load service requests');
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
        serviceRequests
          ..clear()
          ..addAll(loadedRequests);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Service load error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> submitServiceRequest() async {
    if (titleController.text.trim().isEmpty ||
        detailsController.text.trim().isEmpty ||
        selectedPreferredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the service request form')),
      );
      return;
    }

    if (widget.user.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please register with a phone number before requesting a service'),
        ),
      );
      return;
    }

    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse(requestServiceApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.user.id,
          'service_type': selectedServiceType,
          'title': titleController.text.trim(),
          'details': detailsController.text.trim(),
          'preferred_date': _formatDate(selectedPreferredDate),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service request submitted')),
        );
        await loadServiceRequests();
      } else {
        throw Exception(data['message'] ?? 'Failed to submit service request');
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

  Future<void> updateServiceRequest(
    int serviceId,
    String status,
    String notes,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(updateServiceApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': serviceId,
          'status': status,
          'admin_notes': notes.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Service request updated')),
        );
        await loadServiceRequests();
      } else {
        throw Exception(data['message'] ?? 'Failed to update service request');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update error: $e')));
    }
  }

  Widget _buildDatePickerTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color,
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
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'In Progress':
        return const Color(0xFF1D4ED8);
      case 'Completed':
        return const Color(0xFF15803D);
      case 'Rejected':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFFB45309);
    }
  }

  IconData _serviceIcon(String serviceType) {
    switch (serviceType) {
      case 'Laser Cutting':
        return Icons.cut_outlined;
      case '3D Design':
        return Icons.draw_outlined;
      case '3D Printing':
        return Icons.precision_manufacturing_outlined;
      case 'Soldering':
        return Icons.electrical_services_outlined;
      case 'Assembly':
        return Icons.handyman_outlined;
      case 'CNC Machining':
        return Icons.settings_outlined;
      case 'Electronics Repair':
        return Icons.build_outlined;
      case 'PCB Fabrication':
        return Icons.memory_outlined;
      case 'Prototyping':
        return Icons.architecture_outlined;
      case 'Woodworking':
        return Icons.carpenter_outlined;
      case 'Acrylic Fabrication':
        return Icons.layers_outlined;
      case 'Consultation':
        return Icons.support_agent_outlined;
      case 'Training':
        return Icons.school_outlined;
      default:
        return Icons.design_services_outlined;
    }
  }

  void openServiceReportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceReportScreen(user: widget.user),
      ),
    );
  }
}
