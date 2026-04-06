import 'package:flutter/material.dart';

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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text("My Input App", style: TextStyle(fontSize: 30))),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController numaController = TextEditingController();
  TextEditingController numbController = TextEditingController();

  String name = "Something";
  double result = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Enter your name',
                ),
                controller: nameController,
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    name = nameController.text;
                  });
                },
                child: Text('Press Me'),
              ),
              SizedBox(height: 10),
              Text(
                name,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Divider(height: 2, thickness: 2, color: Colors.blueGrey),
              SizedBox(height: 30),
              Text(
                "Simple Calculator",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: numaController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: 'Enter First Number',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: numbController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: 'Enter Second Number',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      double a = double.tryParse(numaController.text) ?? 0.0;
                      double b = double.tryParse(numbController.text) ?? 0.0;
                      setState(() {
                        result = a + b;
                      });
                    },
                    child: Text('+'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      double a = double.tryParse(numaController.text) ?? 0.0;
                      double b = double.tryParse(numbController.text) ?? 0.0;
                      setState(() {
                        result = a - b;
                      });
                    },
                    child: Text('-'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      double a = double.tryParse(numaController.text) ?? 0.0;
                      double b = double.tryParse(numbController.text) ?? 0.0;
                      setState(() {
                        result = a * b;
                      });
                    },
                    child: Text('*'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      double a = double.tryParse(numaController.text) ?? 0.0;
                      double b = double.tryParse(numbController.text) ?? 0.0;
                      setState(() {
                        result = a / b;
                      });
                    },
                    child: Text('/'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text('Result: ${result.toStringAsFixed(2)}'),
              SizedBox(height: 200),
            ],
          ),
        ),
      ),
    );
  }
}
