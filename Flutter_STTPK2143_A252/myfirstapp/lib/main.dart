import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrangeAccent,
        title: Text("Welcome to Flutter"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Increment',
            onPressed: _incrementCounter,
            onLongPress: () {
              print("Long Pressed");
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo, Colors.deepOrangeAccent],
          ),
        ),
        child: Column(
          mainAxisAlignment: .spaceAround,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter times',
              style: TextStyle(
                color: Colors.indigo,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                MaterialButton(
                  minWidth: 100,
                  height: 50,
                  onPressed: _incrementCounter,
                  color: Colors.deepOrangeAccent,
                  child: Text("Press Me"),
                ),
                MaterialButton(
                  minWidth: 100,
                  height: 50,
                  onPressed: _incrementCounter,
                  color: Colors.deepOrangeAccent,
                  child: Text("Press Me"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
