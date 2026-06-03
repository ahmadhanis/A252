import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/views/asset_report_screen.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class AssetmanScreen extends StatefulWidget {
  final UserModel user;
  const AssetmanScreen({super.key, required this.user});

  @override
  State<AssetmanScreen> createState() => _AssetmanScreenState();
}

class _AssetmanScreenState extends State<AssetmanScreen> {
  static const int itemsPerPage = 10;
  static const List<String> assetCategories = [
    'Electronic',
    'Hardware',
    'Tool',
    'Machine',
    'Computer',
    'Peripheral',
    '3D Printing',
    'Laser Cutting',
    'CNC',
    'Hand Tool',
    'Power Tool',
    'Measuring Equipment',
    'Safety Equipment',
    'Furniture',
    'Material',
    'Consumable',
    'Robotics',
    'IoT Device',
    'Audio Visual',
    'Storage',
  ];

  File? imageFile;
  late double screenHeight;
  late double screenWidth;
  List<AssetModel> assets = [];
  bool isLoading = true;
  int currentPage = 1;
  int totalItems = 0;
  int totalPages = 1;
  int summaryVisibleItems = 0;
  int summaryStockCount = 0;
  double summaryTotalValue = 0;
  String get insertApiUrl => ApiPath.endpoint("insert_asset.php");
  String get loadApiUrl => ApiPath.endpoint("load_assets.php");
  String get updateApiUrl => ApiPath.endpoint("update_asset.php");
  String get deleteApiUrl => ApiPath.endpoint("delete_asset.php");

  TextEditingController assetNameController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String selectedCategory = assetCategories.first;
  String selectedFilterCategory = 'All';

  @override
  void initState() {
    super.initState();
    loadAssets();
  }

  @override
  void dispose() {
    assetNameController.dispose();
    quantityController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Assets Management"),
        actions: [
          IconButton(
            tooltip: 'Asset Report',
            onPressed: openAssetReportScreen,
            icon: const Icon(Icons.summarize_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopSection(),
          Expanded(child: _buildAssetsContent()),
          if (!isLoading) _buildPaginationControls(),
        ],
      ),
      drawer: MyDrawer(user: widget.user),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showNewAssetDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          _buildOverviewBanner(),
          const SizedBox(height: 8),
          _buildQuickStats(),
          const SizedBox(height: 8),
          _buildSearchSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewBanner() {
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
          const Text(
            'Makerspace Asset Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track equipment, materials, and tools in one place.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildHeaderPill(
                Icons.inventory_2_outlined,
                '$totalItems assets',
              ),
              _buildHeaderPill(
                Icons.category_outlined,
                selectedFilterCategory == 'All'
                    ? 'All categories'
                    : selectedFilterCategory,
              ),
              _buildHeaderPill(
                Icons.manage_search_outlined,
                searchController.text.trim().isEmpty
                    ? 'No active search'
                    : 'Filtered results',
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

  Widget _buildQuickStats() {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 138,
            child: _buildStatCard(
              'Visible Items',
              summaryVisibleItems.toString(),
              Icons.view_list_outlined,
              const Color(0xFFDBEAFE),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 138,
            child: _buildStatCard(
              'Stock Count',
              summaryStockCount.toString(),
              Icons.layers_outlined,
              const Color(0xFFDCFCE7),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 152,
            child: _buildStatCard(
              'Total Value',
              'RM ${summaryTotalValue.toStringAsFixed(2)}',
              Icons.payments_outlined,
              const Color(0xFFFEF3C7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconBackground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: iconBackground,
            child: Icon(icon, size: 16, color: const Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  void showNewAssetDialog() {
    imageFile = null;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Asset'),
              content: SizedBox(
                width: screenWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //image picker
                      GestureDetector(
                        onTap: () {
                          //show dialog to choose between camera and gallery
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Select Image Source'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Camera'),
                                      onTap: () {
                                        //pick image from camera
                                        Navigator.pop(context);
                                        openCameraPicker(setDialogState);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Gallery'),
                                      onTap: () {
                                        //pick image from gallery
                                        Navigator.pop(context);
                                        openGalleryPicker(setDialogState);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          height: screenHeight * 0.20,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: imageFile != null
                              ? Image.file(imageFile!, fit: BoxFit.fitWidth)
                              : const Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      TextField(
                        decoration: InputDecoration(labelText: 'Asset Name'),
                        controller: assetNameController,
                      ),

                      const SizedBox(height: 8),
                      //dropdown button for asset category
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Asset Category',
                        ),
                        initialValue: selectedCategory,
                        items: assetCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      //quantity field
                      TextField(
                        decoration: InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                        controller: quantityController,
                      ),
                      const SizedBox(height: 8),
                      //price
                      TextField(
                        decoration: InputDecoration(labelText: 'Price'),
                        keyboardType: TextInputType.number,
                        controller: priceController,
                      ),
                      //description field
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                        controller: descriptionController,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    //save asset to database
                    // Navigator.of(context).pop();
                    confirmInsertDialog();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showAssetDetailsDialog(AssetModel asset) {
    final imageUrl = asset.image.isNotEmpty
        ? '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/assets/${asset.image}'
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(asset.name),
          content: SizedBox(
            width: screenWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.inventory_2, size: 56),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildDetailRow('Asset ID', asset.id.toString()),
                  _buildDetailRow('Category', asset.category),
                  _buildDetailRow('Quantity', asset.quantity.toString()),
                  _buildDetailRow('Price', 'RM ${asset.price}'),
                  _buildDetailRow(
                    'Description',
                    asset.description.isEmpty
                        ? 'No description'
                        : asset.description,
                  ),
                  _buildDetailRow('Created At', asset.createdAt),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
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
                flex: 5,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedFilterCategory,
                  decoration: InputDecoration(
                    labelText: 'Filter by category',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: ['All', ...assetCategories]
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedFilterCategory = value ?? 'All';
                    });
                    applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) {
                    setState(() {});
                  },
                  onSubmitted: (_) => applyFilters(),
                  decoration: InputDecoration(
                    labelText: 'Search assets',
                    hintText: 'Name, category or description',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              applyFilters();
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
              FilledButton(
                onPressed: applyFilters,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Icon(Icons.search),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (assets.isEmpty) {
      return const Center(child: Text('No assets found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        final imageName = asset.image;
        final imageUrl = imageName.isNotEmpty
            ? '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/assets/$imageName'
            : null;
        final stockColor = asset.quantity <= 2
            ? const Color(0xFFB91C1C)
            : asset.quantity <= 5
            ? const Color(0xFFB45309)
            : const Color(0xFF166534);

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              showAssetDetailsDialog(asset);
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
                      color: const Color(0xFFF1F5F9),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.inventory_2_outlined,
                                size: 34,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              size: 34,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                asset.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                showAssetMenuDialog(asset);
                              },
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildAssetTag(
                              asset.category,
                              const Color(0xFFDBEAFE),
                              const Color(0xFF1D4ED8),
                            ),
                            _buildAssetTag(
                              'Qty ${asset.quantity}',
                              stockColor.withValues(alpha: 0.12),
                              stockColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          asset.description.isEmpty
                              ? 'No description available'
                              : asset.description,
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
                            const Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'RM ${asset.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                showAssetDetailsDialog(asset);
                              },
                              child: const Text('View Details'),
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
    );
  }

  Widget _buildAssetTag(String label, Color backgroundColor, Color textColor) {
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

  Widget _buildPaginationControls() {
    final startItem = totalItems == 0
        ? 0
        : ((currentPage - 1) * itemsPerPage) + 1;
    final endItem = totalItems == 0 ? 0 : startItem + assets.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalItems',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: currentPage > 1
                    ? () => loadAssets(page: currentPage - 1)
                    : null,
                child: const Icon(Icons.arrow_back_ios_new_outlined),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text('Page $currentPage / $totalPages'),
              ),
              OutlinedButton(
                onPressed: currentPage < totalPages
                    ? () => loadAssets(page: currentPage + 1)
                    : null,
                child: const Icon(Icons.arrow_forward_ios_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> applyFilters() async {
    currentPage = 1;
    await loadAssets(page: 1);
  }

  void openAssetReportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AssetReportScreen()),
    );
  }

  Future<void> loadAssets({int? page}) async {
    final pageToLoad = page ?? currentPage;

    setState(() {
      isLoading = true;
    });

    try {
      final uri = Uri.parse(loadApiUrl).replace(
        queryParameters: {
          'page': pageToLoad.toString(),
          'limit': itemsPerPage.toString(),
          'search': searchController.text.trim(),
          'category': selectedFilterCategory,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('Load Assets Response: $data');
        if (data['status'] == 'success') {
          final loadedAssets = List<AssetModel>.from(
            (data['assets'] ?? []).map(
              (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
            ),
          );
          final totals = await _loadAssetSummary(
            firstPageData: data,
            firstPageAssets: loadedAssets,
          );
          setState(() {
            assets = loadedAssets;
            totalItems = data['total_items'] ?? loadedAssets.length;
            totalPages = data['total_pages'] ?? 1;
            currentPage = data['current_page'] ?? pageToLoad;
            summaryVisibleItems = totals.itemCount;
            summaryStockCount = totals.stockCount;
            summaryTotalValue = totals.totalValue;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load assets');
        }
      } else {
        throw Exception('Failed to load assets');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> cropImage(StateSetter setDialogState) async {
    if (imageFile == null) return;
    if (kIsWeb) return; // skip cropping on web
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile!.path,
      aspectRatio: CropAspectRatio(ratioX: 5, ratioY: 3),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Please Crop Your Image',
          toolbarColor: Colors.deepPurple,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(title: 'Cropper'),
      ],
    );

    if (croppedFile != null) {
      imageFile = File(croppedFile.path);
      setDialogState(() {});
    }
  }

  Future<void> openGalleryPicker(StateSetter setDialogState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 900,
    );

    if (pickedFile != null) {
      imageFile = File(pickedFile.path);
      await cropImage(setDialogState);
    }
  }

  Future<void> openCameraPicker(StateSetter setDialogState) async {
    //pick image from camera
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxHeight: 900,
    );

    if (pickedFile != null) {
      imageFile = File(pickedFile.path);
      await cropImage(setDialogState);
    }
  }

  void confirmInsertDialog() {
    if (imageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    if (assetNameController.text.isEmpty ||
        quantityController.text.isEmpty ||
        priceController.text.isEmpty ||
        descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final navigator = Navigator.of(dialogContext);
        final messenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Confirm Insert'),
          content: const Text('Are you sure you want to insert this asset?'),
          actions: [
            TextButton(
              onPressed: () {
                navigator.pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                //upload image to server dir and insert into asset table to sqlitedb assethub.db database
                //http request to upload image and insert asset data to database
                try {
                  final response = await http.post(
                    Uri.parse(insertApiUrl),
                    body: {
                      'name': assetNameController.text,
                      'category': selectedCategory,
                      'quantity': quantityController.text,
                      'price': priceController.text,
                      'description': descriptionController.text,
                      'image': base64Encode(imageFile!.readAsBytesSync()),
                    },
                  );
                  if (!mounted) return;
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'success') {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Asset inserted')),
                      );
                      resetAssetForm();
                      currentPage = 1;
                      await loadAssets(page: 1);
                      if (!mounted) return;
                      navigator.pop();
                      Navigator.of(context).pop();
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text(data['message'] ?? 'Error')),
                      );
                    }
                  }
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void showAssetMenuDialog(AssetModel asset) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(asset.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Asset'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement edit functionality
                  showEditDialog(asset);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Asset'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement delete functionality
                  showDeleteAssetDialog(asset);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void showEditDialog(AssetModel asset) {
    imageFile = null;
    assetNameController.text = asset.name;
    quantityController.text = asset.quantity.toString();
    priceController.text = asset.price.toString();
    descriptionController.text = asset.description;
    selectedCategory = asset.category;
    final imageName = asset.image;
    final imageUrl = imageName.isNotEmpty
        ? '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/assets/$imageName'
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Asset ${asset.name}'),
              content: SizedBox(
                width: screenWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //image picker
                      GestureDetector(
                        onTap: () {
                          //show dialog to choose between camera and gallery
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Select Image Source'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Camera'),
                                      onTap: () {
                                        //pick image from camera
                                        Navigator.pop(context);
                                        openCameraPicker(setDialogState);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Gallery'),
                                      onTap: () {
                                        //pick image from gallery
                                        Navigator.pop(context);
                                        openGalleryPicker(setDialogState);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          height: screenHeight * 0.20,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: imageFile != null
                              ? Image.file(imageFile!, fit: BoxFit.fitWidth)
                              : imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.fitWidth,
                                  errorBuilder: (_, error, stackTrace) =>
                                      const Icon(Icons.image, size: 50),
                                )
                              : const Icon(Icons.image, size: 50),
                        ),
                      ),
                      TextField(
                        decoration: InputDecoration(labelText: 'Asset Name'),
                        controller: assetNameController,
                      ),

                      const SizedBox(height: 8),
                      //dropdown button for asset category
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Asset Category',
                        ),
                        initialValue: selectedCategory,
                        items: assetCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      //quantity field
                      TextField(
                        decoration: InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                        controller: quantityController,
                      ),
                      const SizedBox(height: 8),
                      //price
                      TextField(
                        decoration: InputDecoration(labelText: 'Price'),
                        keyboardType: TextInputType.number,
                        controller: priceController,
                      ),
                      //description field
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                        controller: descriptionController,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    imageFile = null;
                  },
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    //save asset to database
                    // Navigator.of(context).pop();
                    AssetModel updatedAsset = AssetModel(
                      id: asset.id,
                      name: assetNameController.text,
                      category: selectedCategory,
                      quantity: int.tryParse(quantityController.text) ?? 0,
                      price: double.tryParse(priceController.text) ?? 0.0,
                      description: descriptionController.text,
                      image: asset.image,
                      createdAt: asset.createdAt,
                    );
                    confirmUpdateDialog(updatedAsset);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void confirmUpdateDialog(AssetModel updatedAsset) {
    if (updatedAsset.name.isEmpty ||
        updatedAsset.quantity <= 0 ||
        updatedAsset.price <= 0 ||
        updatedAsset.description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields')),
      );
      return;
    }

    final imgf = imageFile == null
        ? 'NA'
        : base64Encode(imageFile!.readAsBytesSync());

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final navigator = Navigator.of(dialogContext);
        final messenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Confirm Update'),
          content: const Text('Are you sure you want to update this asset?'),
          actions: [
            TextButton(
              onPressed: () {
                navigator.pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Implement update functionality similar to insert but with update API endpoint
                // and include asset ID in the request
                try {
                  final response = await http.post(
                    Uri.parse(updateApiUrl),
                    body: {
                      'id': updatedAsset.id.toString(),
                      'name': updatedAsset.name,
                      'category': updatedAsset.category,
                      'quantity': updatedAsset.quantity.toString(),
                      'price': updatedAsset.price.toString(),
                      'description': updatedAsset.description,
                      'image': imgf,
                    },
                  );
                  if (!mounted) return;
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'success') {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Asset updated')),
                      );
                      resetAssetForm();
                      await loadAssets();
                      if (!mounted) return;
                      navigator.pop();
                      Navigator.of(context).pop();
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text(data['message'] ?? 'Error')),
                      );
                    }
                  }
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void resetAssetForm() {
    imageFile = null;
    assetNameController.clear();
    quantityController.clear();
    priceController.clear();
    descriptionController.clear();
    if (mounted) {
      setState(() {
        selectedCategory = assetCategories.first;
      });
    } else {
      selectedCategory = assetCategories.first;
    }
  }

  void showDeleteAssetDialog(AssetModel asset) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this asset?'),
          actions: [
            TextButton(
              onPressed: () {
                navigator.pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Implement delete functionality by sending a request to the delete API endpoint
                // and include asset ID in the request
                deleteAsset(asset.id, navigator, messenger);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteAsset(
    int id,
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(deleteApiUrl),
        body: {'id': id.toString()},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          messenger.showSnackBar(
            const SnackBar(content: Text('Asset deleted')),
          );
          await loadAssets();
          navigator.pop();
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Error')),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<_AssetSummaryTotals> _loadAssetSummary({
    required Map<String, dynamic> firstPageData,
    required List<AssetModel> firstPageAssets,
  }) async {
    final totalPagesFromApi = (firstPageData['total_pages'] as num?)?.toInt() ?? 1;
    final collectedAssets = <AssetModel>[...firstPageAssets];

    if (totalPagesFromApi > 1) {
      for (int page = 2; page <= totalPagesFromApi; page++) {
        final pageUri = Uri.parse(loadApiUrl).replace(
          queryParameters: {
            'page': page.toString(),
            'limit': '100',
            'search': searchController.text.trim(),
            'category': selectedFilterCategory,
          },
        );
        final response = await http.get(pageUri);
        if (response.statusCode != 200) {
          throw Exception('Failed to load asset summary page $page');
        }

        final data = jsonDecode(response.body);
        if (data['status'] != 'success') {
          throw Exception(
            data['message'] ?? 'Failed to load asset summary page $page',
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
    }

    final stockCount = collectedAssets.fold<int>(
      0,
      (sum, asset) => sum + asset.quantity,
    );
    final totalValue = collectedAssets.fold<double>(
      0,
      (sum, asset) => sum + (asset.quantity * asset.price),
    );

    return _AssetSummaryTotals(
      itemCount: (firstPageData['total_items'] as num?)?.toInt() ?? collectedAssets.length,
      stockCount: stockCount,
      totalValue: totalValue,
    );
  }
}

class _AssetSummaryTotals {
  final int itemCount;
  final int stockCount;
  final double totalValue;

  const _AssetSummaryTotals({
    required this.itemCount,
    required this.stockCount,
    required this.totalValue,
  });
}
