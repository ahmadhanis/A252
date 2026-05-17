import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:assethub/models/asset_model.dart';
import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
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
  File? imageFile;
  late double screenHeight;
  late double screenWidth;
  List<AssetModel> assets = [];
  bool isLoading = true;
  String get insertApiUrl => ApiPath.endpoint("insert_asset.php");
  String get loadApiUrl => ApiPath.endpoint("load_assets.php");
  String get updateApiUrl => ApiPath.endpoint("update_asset.php");
  String get deleteApiUrl => ApiPath.endpoint("delete_asset.php");
  
  TextEditingController assetNameController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  String selectedCategory = 'Electronic';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text("Assets Management")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : assets.isEmpty
          ? const Center(child: Text("No assets available"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                final imageName = asset.image;
                final imageUrl = imageName.isNotEmpty
                    ? '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/assets/$imageName'
                    : null;
                //  print("Asset Image URL: $imageUrl");
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () {
                      showAssetDetailsDialog(asset);
                    },
                    leading: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.inventory_2, size: 40),
                            ),
                          )
                        : const Icon(Icons.inventory_2, size: 40),
                    title: Text(asset.name),
                    subtitle: Text(
                      '${asset.category} | Qty: ${asset.quantity} | RM ${asset.price}',
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        showAssetMenuDialog(asset);
                      },
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  ),
                );
              },
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
                        items: const [
                          DropdownMenuItem(
                            value: 'Electronic',
                            child: Text('Electronic'),
                          ),
                          DropdownMenuItem(
                            value: 'Hardware',
                            child: Text('Hardware'),
                          ),
                          DropdownMenuItem(value: 'Tool', child: Text('Tool')),
                        ],
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

  Future<void> loadAssets() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(loadApiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('Load Assets Response: $data');
        if (data['status'] == 'success') {
          final loadedAssets = List<AssetModel>.from(
            (data['assets'] ?? []).map(
              (asset) => AssetModel.fromJson(Map<String, dynamic>.from(asset)),
            ),
          );
          setState(() {
            assets = loadedAssets;
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
                        items: const [
                          DropdownMenuItem(
                            value: 'Electronic',
                            child: Text('Electronic'),
                          ),
                          DropdownMenuItem(
                            value: 'Hardware',
                            child: Text('Hardware'),
                          ),
                          DropdownMenuItem(value: 'Tool', child: Text('Tool')),
                        ],
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
        selectedCategory = 'Electronic';
      });
    } else {
      selectedCategory = 'Electronic';
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
}
