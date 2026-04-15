import 'package:flutter/material.dart';

// Step 3:
// This provider stores the shared calculator data and solves the formula.
class ElectricalCalculatorProvider extends ChangeNotifier {
  final TextEditingController voltageController = TextEditingController();
  final TextEditingController currentController = TextEditingController();
  final TextEditingController resistanceController = TextEditingController();

  String process = 'Enter any two values and leave one blank.';
  String answerTitle = 'Result';
  String answerValue = '--';
  String answerDetail = '';

  String get voltage => voltageController.text;
  String get current => currentController.text;
  String get resistance => resistanceController.text;

  void setVoltage(String value) {
    // The controller already holds the text.
    // We only notify Flutter so the UI can rebuild.
    notifyListeners();
  }

  void setCurrent(String value) {
    // The controller already holds the text.
    // We only notify Flutter so the UI can rebuild.
    notifyListeners();
  }

  void setResistance(String value) {
    // The controller already holds the text.
    // We only notify Flutter so the UI can rebuild.
    notifyListeners();
  }

  void calculate() {
    // Read the input text and convert it into numbers.
    final v = double.tryParse(voltage);
    final i = double.tryParse(current);
    final r = double.tryParse(resistance);

    final filledCount = [
      v != null,
      i != null,
      r != null,
    ].where((filled) => filled).length;

    if (filledCount != 2) {
      // The app can only solve one missing value at a time.
      process = 'Please enter exactly two values and leave one box blank.';
      answerTitle = 'Input needed';
      answerValue = '--';
      answerDetail = 'Example: enter I and R to find V.';
      notifyListeners();
      return;
    }

    // Solve V from I and R.
    if (v == null && i != null && r != null) {
      final result = i * r;
      process = 'V = I x R';
      answerTitle = 'Voltage (V)';
      answerValue = '${result.toStringAsFixed(2)} V';
      answerDetail = 'V = ${i.toStringAsFixed(2)} x ${r.toStringAsFixed(2)}';
    // Solve I from V and R.
    } else if (i == null && v != null && r != null) {
      if (r == 0) {
        // Division by zero is not allowed.
        process = 'I = V / R';
        answerTitle = 'Current (I)';
        answerValue = '--';
        answerDetail = 'Resistance cannot be zero.';
        notifyListeners();
        return;
      }
      final result = v / r;
      process = 'I = V / R';
      answerTitle = 'Current (I)';
      answerValue = '${result.toStringAsFixed(2)} A';
      answerDetail = 'I = ${v.toStringAsFixed(2)} / ${r.toStringAsFixed(2)}';
    // Solve R from V and I.
    } else if (r == null && v != null && i != null) {
      if (i == 0) {
        // Division by zero is not allowed.
        process = 'R = V / I';
        answerTitle = 'Resistance (R)';
        answerValue = '--';
        answerDetail = 'Current cannot be zero.';
        notifyListeners();
        return;
      }
      final result = v / i;
      process = 'R = V / I';
      answerTitle = 'Resistance (R)';
      answerValue = '${result.toStringAsFixed(2)} ohms';
      answerDetail = 'R = ${v.toStringAsFixed(2)} / ${i.toStringAsFixed(2)}';
    } else {
      // If the inputs do not match a valid case, show a simple message.
      process = 'Please leave only one box blank.';
      answerTitle = 'Input needed';
      answerValue = '--';
      answerDetail = 'The app can solve only one missing value at a time.';
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  void clear() {
    // Reset everything back to the starting state.
    voltageController.clear();
    currentController.clear();
    resistanceController.clear();
    process = 'Enter any two values and leave one blank.';
    answerTitle = 'Result';
    answerValue = '--';
    answerDetail = '';
    notifyListeners();
  }

  @override
  void dispose() {
    voltageController.dispose();
    currentController.dispose();
    resistanceController.dispose();
    super.dispose();
  }
}
