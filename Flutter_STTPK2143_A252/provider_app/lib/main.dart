import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/electrical_calculator_provider.dart';
import 'screens/calculator_home_page.dart';

// Step 1:
// Create one shared provider for the calculator.
void main() {
  // runApp() shows the widget tree on screen.
  runApp(const ElectricalCalculatorApp());
}

class ElectricalCalculatorApp extends StatelessWidget {
  const ElectricalCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Step 2:
    // Put the provider above the screen so the UI can use it.
    return ChangeNotifierProvider(
      create: (_) => ElectricalCalculatorProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Electrical Formula Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const CalculatorHomePage(),
      ),
    );
  }
}
