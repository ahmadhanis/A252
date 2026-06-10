import 'package:assethub/models/user_model.dart';
import 'package:assethub/views/assetman_screen.dart';
import 'package:assethub/views/login_screen.dart';
import 'package:assethub/views/loanman_screen.dart';
import 'package:assethub/views/main_screen.dart';
import 'package:assethub/views/profile_screen.dart';
import 'package:assethub/views/servicereq_screen.dart';
import 'package:assethub/views/user_main_screen.dart';
import 'package:assethub/services/api_path.dart';
import 'package:flutter/material.dart';

enum DrawerSection {
  dashboard,
  assets,
  loans,
  services,
  profile,
}

class MyDrawer extends StatefulWidget {
  final UserModel user;
  final DrawerSection currentSection;

  const MyDrawer({
    super.key,
    required this.user,
    required this.currentSection,
  });

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  String? get _profileImageUrl {
    if (widget.user.profileImage.trim().isEmpty) return null;
    final profileImage = widget.user.profileImage.trim();
    return '${ApiPath.baseUrl.replaceFirst('/api', '')}/uploads/profiles/$profileImage?v=${profileImage.hashCode}';
  }

  Widget _buildDrawerAvatar() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_profileImageUrl == null) {
      return CircleAvatar(
        backgroundColor: colorScheme.surface,
        child: Text(
          widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : "U",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: colorScheme.surface,
      child: ClipOval(
        child: Image.network(
          _profileImageUrl!,
          key: ValueKey(widget.user.profileImage),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Text(
            widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : "U",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSection(
    DrawerSection targetSection,
    WidgetBuilder builder,
  ) {
    Navigator.pop(context);

    if (widget.currentSection == targetSection) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: builder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              accountName: Text(widget.user.name),
              accountEmail: Text(widget.user.email),
              currentAccountPicture: _buildDrawerAvatar(),
              decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          const TextSpan(
                            text: "Login As: ",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: widget.user.role,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              selected: widget.currentSection == DrawerSection.dashboard,
              leading: const Icon(Icons.home_outlined),
              title: const Text("Dashboard"),
              onTap: () {
                _navigateToSection(
                  DrawerSection.dashboard,
                  (context) => widget.user.role.toLowerCase() == 'admin'
                      ? MainScreen(user: widget.user)
                      : UserMainScreen(user: widget.user),
                );
              },
            ),
            if (widget.user.role.toLowerCase() == 'admin')
              ListTile(
                selected: widget.currentSection == DrawerSection.assets,
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text("Assets Management"),
                onTap: () {
                  _navigateToSection(
                    DrawerSection.assets,
                    (context) => AssetmanScreen(user: widget.user),
                  );
                },
              ),
            ListTile(
              selected: widget.currentSection == DrawerSection.loans,
              leading: const Icon(Icons.assignment_return_outlined),
              title: const Text("Loan Management"),
              onTap: () {
                _navigateToSection(
                  DrawerSection.loans,
                  (context) => LoanmanScreen(user: widget.user),
                );
              },
            ),
            ListTile(
              selected: widget.currentSection == DrawerSection.services,
              leading: const Icon(Icons.design_services_outlined),
              title: const Text("Service Requests"),
              onTap: () {
                _navigateToSection(
                  DrawerSection.services,
                  (context) => ServicereqScreen(user: widget.user),
                );
              },
            ),
            ListTile(
              selected: widget.currentSection == DrawerSection.profile,
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("My Profile"),
              onTap: () {
                _navigateToSection(
                  DrawerSection.profile,
                  (context) => ProfileScreen(user: widget.user),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: logoutUser,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> logoutUser() async {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
