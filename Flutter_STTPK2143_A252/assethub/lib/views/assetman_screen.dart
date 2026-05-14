import 'dart:convert';
import 'dart:io';

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
  String get apiUrl => ApiPath.endpoint("insert_asset.php");

  TextEditingController assetNameController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  String selectedCategory = 'Electronic';

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text("Assets Management")),
      body: const Center(child: Text("Assets Management Screen")),
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
                          height: screenHeight * 0.25,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: imageFile != null
                              ? Image.file(imageFile!, fit: BoxFit.cover)
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
                          setState(() {
                            selectedCategory = value!;
                            print(selectedCategory);
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

  Future<void> cropImage(StateSetter setDialogState) async {
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
    }
    cropImage(setDialogState);
    // setDialogState(() {});
    //pick image from gallery
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
    }
    cropImage(setDialogState);
  }

  void confirmInsertDialog() {
    if (imageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    if (assetNameController.text.isEmpty &&
        quantityController.text.isEmpty &&
        priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Insert'),
          content: const Text('Are you sure you want to insert this asset?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                //upload image to server dir and insert into asset table to sqlitedb assethub.db database
                //http request to upload image and insert asset data to database
                try {
                  final response = await http.post(
                    Uri.parse(apiUrl),
                    body: {
                      'name': assetNameController.text,
                      'category': selectedCategory,
                      'quantity': quantityController.text,
                      'price': priceController.text,
                      'description': descriptionController.text,
                      'image': base64Encode(imageFile!.readAsBytesSync()),
                    },
                  );
                  print(response.body);
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'success') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Asset inserted')),
                      );
                      imageFile = null;
                      assetNameController.clear();
                      quantityController.clear();
                      priceController.clear();
                      descriptionController.clear();
                      selectedCategory = 'Electronic';
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(data['message'] ?? 'Error')),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
