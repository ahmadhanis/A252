import 'package:flutter/material.dart';
import 'package:input_app/splashscreen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.purple,
        appBarTheme: AppBarTheme(backgroundColor: Colors.tealAccent.shade400),
        brightness: Brightness.light,
      ),
      home: SplashScreen(),
    );
  }
}



