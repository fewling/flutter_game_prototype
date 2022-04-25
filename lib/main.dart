// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_game_prototype/beats_recorder.dart';
import 'package:flutter_game_prototype/game/game.dart';

void main() {
  DartVLC.initialize();
  runApp(MaterialApp(
    home: Home(),
    theme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: "PressStart2P",
    ),
    debugShowCheckedModeBanner: false,
  ));
}

class Home extends StatelessWidget {
  Home({Key? key}) : super(key: key);

  final menuButtonStyle = TextButton.styleFrom().copyWith(
    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
      (states) => states.contains(MaterialState.hovered)
          ? Colors.deepPurple[600]
          : Colors.transparent,
    ),
    shape: MaterialStateProperty.resolveWith<OutlinedBorder?>(
      (_) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.gif"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text("Beats Maker", style: Theme.of(context).textTheme.headline1),
            Column(
              children: [
                TextButton(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Play',
                        style: Theme.of(context).textTheme.headline2),
                  ),
                  style: menuButtonStyle,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Game(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 24),
                TextButton(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Create',
                        style: Theme.of(context).textTheme.headline2),
                  ),
                  style: menuButtonStyle,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BeatRecorder(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
