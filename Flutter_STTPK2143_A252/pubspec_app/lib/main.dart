import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

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
      home: const MyHomePage(title: 'Pubspec App'),
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
  final player = AudioPlayer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Text('Hello UUM',style: GoogleFonts.playwriteAr(fontSize: 24),),
            Image.asset('assets/images/logo_uum.png', scale: 2),
            Image.network(
              'https://miro.medium.com/v2/resize:fit:828/format:webp/1*cWklGlA01JspimzBenSUKA.jpeg',
              scale: 4,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(onPressed: playMe, icon: Icon(Icons.play_arrow)),
                IconButton(onPressed: player.pause, icon: Icon(Icons.pause)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void playMe() {
    player.play(AssetSource('audios/bongo.wav'));
  }
}
