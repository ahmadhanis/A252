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
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // clean background
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
            const Text(
              "MCMC AssetHub",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A), // dark blue
              ),
            ),

            const SizedBox(height: 10),

            // 🔹 TAGLINE (optional)
            const Text(
              "Smart Inventory System",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
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