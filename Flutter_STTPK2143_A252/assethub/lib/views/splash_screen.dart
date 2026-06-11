import 'package:assethub/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Delay 3 seconds then navigate
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 🔹 LOGO
            Image.asset(
              'assets/logo.png', // put your logo here
              width: 160,
            ),

            const SizedBox(height: 20),

            // 🔹 APP NAME
            Text(
              "MCMC AssetHub",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 TAGLINE (optional)
            Text(
              "Smart Inventory System",
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),

            const SizedBox(height: 40),

            // 🔹 LOADING
            const CircularProgressIndicator(
              color: Color(0xFFFACC15), // yellow accent
            ),
          ],
        ),
      ),
    );
  }
}
