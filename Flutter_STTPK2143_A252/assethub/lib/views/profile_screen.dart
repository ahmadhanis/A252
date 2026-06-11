import 'dart:convert';

import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/api_path.dart';
import 'package:assethub/main.dart';
import 'package:assethub/views/main_screen.dart';
import 'package:assethub/views/user_main_screen.dart';
import 'package:assethub/widgets/mydrawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  XFile? imageFile;
  Uint8List? imageBytes;
  bool isLoading = false;

  String get updateProfileUrl => ApiPath.endpoint("update_profile.php");

  @override
  void initState() {
    super.initState();
    nameController.text = widget.user.name;
    phoneController.text = widget.user.phone;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String? get _profileImageUrl {
    if (widget.user.profileImage.trim().isEmpty) return null;
    final profileImage = widget.user.profileImage.trim();
    return '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/profiles/$profileImage?v=${profileImage.hashCode}';
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxHeight: 900);
    if (pickedFile == null) return;

    imageFile = pickedFile;
    imageBytes = await pickedFile.readAsBytes();
    if (!kIsWeb) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile!.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Image',
            toolbarColor: Colors.blue.shade700,
            toolbarWidgetColor: Colors.white,
          ),
          IOSUiSettings(title: 'Crop Profile Image'),
        ],
      );
      if (croppedFile != null) {
        imageFile = XFile(croppedFile.path);
        imageBytes = await imageFile!.readAsBytes();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in name and phone number"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final request = http.MultipartRequest("POST", Uri.parse(updateProfileUrl))
        ..fields["id"] = widget.user.id.toString()
        ..fields["name"] = nameController.text.trim()
        ..fields["phone"] = phoneController.text.trim()
        ..fields["old_password"] = ''
        ..fields["new_password"] = ''
        ..fields["confirm_new_password"] = '';

      if (imageFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "image",
            imageBytes!,
            filename: imageFile!.name,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception("HTTP ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      if (data["status"] != "success") {
        throw Exception(data["message"] ?? "Failed to update profile");
      }

      final updatedUser = UserModel.fromJson(
        Map<String, dynamic>.from(data["user"] as Map),
      );

      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => updatedUser.role.toLowerCase() == 'admin'
              ? MainScreen(user: updatedUser)
              : UserMainScreen(user: updatedUser),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmNewPasswordController = TextEditingController();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isSavingPassword = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            Future<void> submitPasswordChange() async {
              final oldPassword = oldPasswordController.text;
              final newPassword = newPasswordController.text;
              final confirmNewPassword = confirmNewPasswordController.text;

              if (oldPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmNewPassword.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Please fill in old password, new password, and confirmation",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("New password must be at least 6 characters"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPassword != confirmNewPassword) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("New password and confirmation do not match"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setDialogState(() => isSavingPassword = true);

              try {
                final request = http.MultipartRequest(
                  "POST",
                  Uri.parse(updateProfileUrl),
                )
                  ..fields["id"] = widget.user.id.toString()
                  ..fields["name"] = widget.user.name
                  ..fields["phone"] = widget.user.phone
                  ..fields["old_password"] = oldPassword
                  ..fields["new_password"] = newPassword
                  ..fields["confirm_new_password"] = confirmNewPassword;

                final streamedResponse = await request.send();
                final response = await http.Response.fromStream(streamedResponse);

                if (response.statusCode != 200) {
                  throw Exception("HTTP ${response.statusCode}");
                }

                final data = jsonDecode(response.body);
                if (data["status"] != "success") {
                  throw Exception(
                    data["message"] ?? "Failed to change password",
                  );
                }

                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password changed successfully"),
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text("Password change failed: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isSavingPassword = false);
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              title: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(
                      Icons.lock_reset_outlined,
                      color: Color(0xFF1D4ED8),
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Change Password",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
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
                        "Enter your current password, then confirm your new password. Your new password must be at least 6 characters.",
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOldPassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "Old Password",
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(
                              () => obscureOldPassword = !obscureOldPassword,
                            );
                          },
                          icon: Icon(
                            obscureOldPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "New Password",
                        prefixIcon: Icon(
                          Icons.lock_reset_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(
                              () => obscureNewPassword = !obscureNewPassword,
                            );
                          },
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmNewPasswordController,
                      obscureText: obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isSavingPassword) {
                          submitPasswordChange();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: "Confirm New Password",
                        prefixIcon: Icon(
                          Icons.verified_user_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(
                              () =>
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword,
                            );
                          },
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingPassword
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  onPressed: isSavingPassword ? null : submitPasswordChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isSavingPassword
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(isSavingPassword ? "Updating..." : "Update Password"),
                ),
              ],
            );
          },
        );
      },
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (imageBytes != null) {
      return CircleAvatar(
        radius: 52,
        backgroundColor: const Color(0xFFE2E8F0),
        child: ClipOval(
          child: kIsWeb && imageFile != null
              ? Image.network(
                  imageFile!.path,
                  key: ValueKey(imageFile!.path),
                  width: 104,
                  height: 104,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Image.memory(
                    imageBytes!,
                    key: ValueKey(imageBytes!.lengthInBytes),
                    width: 104,
                    height: 104,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _buildInitialAvatarContent(),
                  ),
                )
              : Image.memory(
                  imageBytes!,
                  key: ValueKey(imageBytes!.lengthInBytes),
                  width: 104,
                  height: 104,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _buildInitialAvatarContent(),
                ),
        ),
      );
    }

    if (_profileImageUrl != null) {
      return CircleAvatar(
        radius: 52,
        backgroundColor: const Color(0xFFE2E8F0),
        child: ClipOval(
          child: Image.network(
            _profileImageUrl!,
            key: ValueKey(widget.user.profileImage),
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildInitialAvatarContent(),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 52,
      backgroundColor: const Color(0xFFE2E8F0),
      child: _buildInitialAvatarContent(),
    );
  }

  Widget _buildInitialAvatarContent() {
    return Text(
      widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : "U",
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formWidth = screenWidth > 900
        ? 480.0
        : screenWidth > 600
        ? 540.0
        : screenWidth * 0.92;
    final appState = MyApp.of(context);
    final isDarkMode = appState?.isDarkMode ?? false;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("My Profile")),
      drawer: MyDrawer(
        user: widget.user,
        currentSection: DrawerSection.profile,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: formWidth,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
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
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _buildProfileAvatar(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Tap the image to change your profile photo",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      "You can update your name, phone number, and profile image here. Use the change password button for secure password updates.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: widget.user.email,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: widget.user.role,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: "Role",
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SwitchListTile(
                      value: isDarkMode,
                      onChanged: (value) {
                        appState?.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                      title: const Text(
                        "Dark Mode",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isDarkMode
                            ? "Use the dark app appearance"
                            : "Use the light app appearance",
                      ),
                      secondary: Icon(
                        isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: const Text("Change Password"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      icon: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(isLoading ? "Saving..." : "Save Profile"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
