import 'package:assethub/models/user_model.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.user,
    required this.menus,
    required this.selectedIndex,
    required this.onMenuTap,
  });

  final UserModel user;
  final List<Map<String, dynamic>> menus;
  final int selectedIndex;
  final ValueChanged<int> onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user.name),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(user.email),
                // const SizedBox(height: 4),
                Text(
                  user.role,
                  style: const TextStyle(
                    // fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: menus.length,
              itemBuilder: (context, index) {
                final menu = menus[index];
                final isSelected = selectedIndex == index;

                return ListTile(
                  leading: Icon(menu["icon"] as IconData),
                  title: Text(menu["title"].toString()),
                  selected: isSelected,
                  onTap: () => onMenuTap(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
