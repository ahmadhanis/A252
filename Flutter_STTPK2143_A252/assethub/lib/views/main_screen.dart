import 'package:assethub/models/user_model.dart';
import 'package:assethub/services/menu_config.dart';
import 'package:assethub/widgets/app_drawer.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.user,
  });

  final UserModel user;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final List<Map<String, dynamic>> menus;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    menus = MenuConfig.forRole(widget.user.role);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = menus[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedMenu["title"].toString()),
      ),
      drawer: AppDrawer(
        user: widget.user,
        menus: menus,
        selectedIndex: selectedIndex,
        onMenuTap: (index) {
          setState(() {
            selectedIndex = index;
          });

          Navigator.pop(context);
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedMenu["title"].toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This is the ${selectedMenu["title"]} page.",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
