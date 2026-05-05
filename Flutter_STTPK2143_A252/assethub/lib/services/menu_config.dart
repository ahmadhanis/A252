import 'package:flutter/material.dart';

class MenuConfig {
  static const List<Map<String, dynamic>> allMenus = [
    {
      "title": "Home",
      "icon": Icons.home_outlined,
      "roles": ["student", "lecturer", "public", "admin"],
    },
    {
      "title": "Assets",
      "icon": Icons.inventory_2_outlined,
      "roles": ["student", "lecturer", "public", "admin"],
    },
    {
      "title": "My Loans",
      "icon": Icons.assignment_outlined,
      "roles": ["student", "lecturer", "public"],
    },
    {
      "title": "Services",
      "icon": Icons.miscellaneous_services_outlined,
      "roles": ["student", "lecturer", "public"],
    },
    {
      "title": "My Services",
      "icon": Icons.receipt_long_outlined,
      "roles": ["student", "lecturer", "public"],
    },

    {
      "title": "Asset Management",
      "icon": Icons.inventory_outlined,
      "roles": ["admin"],
    },
    {
      "title": "Loan Management",
      "icon": Icons.rule_folder_outlined,
      "roles": ["admin"],
    },
    {
      "title": "Services Management",
      "icon": Icons.design_services_outlined,
      "roles": ["admin"],
    },
    {
      "title": "Profile",
      "icon": Icons.person_outline,
      "roles": ["student", "lecturer", "public", "admin"],
    }
  ];

  static List<Map<String, dynamic>> forRole(String role) {
    final normalizedRole = role.trim().toLowerCase();

    return allMenus.where((menu) {
      final roles = (menu["roles"] as List).map(
        (item) => item.toString().toLowerCase(),
      );
      return roles.contains(normalizedRole);
    }).toList();
  }
}
