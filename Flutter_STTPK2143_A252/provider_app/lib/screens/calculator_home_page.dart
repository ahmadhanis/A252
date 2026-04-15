import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/electrical_calculator_provider.dart';

// Step 4:
// The screen sends input to the provider and reads the result with watch().
class CalculatorHomePage extends StatelessWidget {
  const CalculatorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // watch() listens to the provider.
    // When the provider changes, this screen rebuilds and shows new values.
    final calculator = context.watch<ElectricalCalculatorProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900 ? 48.0 : 20.0;
    final contentWidth = width >= 900 ? 560.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Electrical Formula Demo'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'V = I x R',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type any two values and leave one blank.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: calculator.voltageController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: calculator.setVoltage,
                    decoration: const InputDecoration(
                      labelText: 'Voltage (V)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: calculator.currentController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: calculator.setCurrent,
                    decoration: const InputDecoration(
                      labelText: 'Current (I)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: calculator.resistanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: calculator.setResistance,
                    decoration: const InputDecoration(
                      labelText: 'Resistance (R)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(), 
                  const SizedBox(height: 24),
                  const Text(
                    'Process',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(calculator.process),
                  const SizedBox(height: 20),
                  const Text(
                    'Output',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    calculator.answerTitle,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calculator.answerValue,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  if (calculator.answerDetail.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      calculator.answerDetail,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: calculator.calculate,
                          child: const Text('Calculate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: calculator.clear,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
