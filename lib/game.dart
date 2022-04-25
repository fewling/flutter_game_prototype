// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class Game extends StatefulWidget {
  const Game({Key? key}) : super(key: key);

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> with SingleTickerProviderStateMixin {
  late Future<Directory> _savesDirFuture;

  final Player _player = Player(id: 69420);

  Map<String, dynamic> _selectedJson = {};
  double _volume = 0.3;
  bool _mute = false;

  final List<Brick> _allBricks = [];
  final List<Brick> _drawingBricks = [];

  late AnimationController _controller;

  String stage = "pick_song";
  final String stageReady = "ready";
  final String stageCountdown = "countdown";
  final String stageGame = "game";

  int _countdownEndTime = 0;
  final int _countdownInterval = 5000;

  double _screenWidth = 0;
  double _screenHeight = 0;

  @override
  void initState() {
    _controller =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    _controller.repeat();

    _player.setVolume(_volume);
    _savesDirFuture = getApplicationDocumentsDirectory();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: buildAppbar(),
      endDrawer: buildEndDrawer(_screenWidth),
      body: buildBodies(),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  PreferredSizeWidget buildAppbar() {
    return AppBar(
      leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_outlined)),
    );
  }

  Drawer buildEndDrawer(double screenWidth) {
    return Drawer(
      child: FutureBuilder<Directory>(
          future: _savesDirFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              Directory appDocDir = snapshot.data!;
              String appDocPath = appDocDir.path;

              String savesDirectory = Platform.isWindows
                  ? "$appDocPath\\flutter_game_prototype"
                  : "$appDocPath/flutter_game_prototype";

              Directory directory = Directory(savesDirectory);

              List<FileSystemEntity> fileEntities =
                  directory.listSync(recursive: true);

              return ListView.builder(
                itemCount: fileEntities.length,
                itemBuilder: (context, index) {
                  File entity = fileEntities[index] as File;

                  String content = entity.readAsStringSync();
                  Map<String, dynamic> json = jsonDecode(content);

                  String filePath = json['file'];
                  String fileName = Platform.isWindows
                      ? filePath.split('\\').last
                      : filePath.split('/').last;

                  return ListTile(
                    title: Text(
                      fileName,
                      style: TextStyle(fontFamily: "Roboto"),
                    ),
                    onTap: () {
                      /// update states:
                      stage = stageReady;
                      _selectedJson = json;
                      setState(() {});

                      prepareBricks(screenWidth);

                      /// Load music:
                      File file = File(filePath);
                      Media media = Media.file(file);
                      _player.open(media, autoStart: false);

                      /// Close the drawer:
                      Navigator.pop(context);
                    },
                  );
                },
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          }),
    );
  }

  void prepareBricks(double screenWidth) {
    _allBricks.clear();
    List pressedKeys = _selectedJson['pressed_keys'];
    for (var item in pressedKeys) {
      String key = item.keys.first;
      int pos = item.values.first;
      double x = Random().nextDouble() * screenWidth;

      final brick = Brick(key, pos, x, 0, screenWidth * 0.1, 20, Colors.red);
      _allBricks.add(brick);
    }
  }

  Widget buildBodies() {
    if (stage == 'pick_song') {
      return Center(
        child: Text('Pick a song =>',
            style: Theme.of(context).textTheme.headline1),
      );
    } else if (stage == stageReady) {
      return Center(
        child: TextButton(
          onPressed: () => setState(() {
            stage = stageCountdown;
            _countdownEndTime =
                DateTime.now().millisecondsSinceEpoch + _countdownInterval;
          }),
          child: Text('Start?', style: Theme.of(context).textTheme.headline1),
        ),
      );
    } else if (stage == stageCountdown) {
      return CountdownTimer(
        endTime: _countdownEndTime,
        onEnd: () {
          setState(() => stage = "game");
          _player.play();
        },
        widgetBuilder: (_, remainingTime) => Center(
          child: Text(
            remainingTime!.sec.toString(),
            style: Theme.of(context).textTheme.headline1,
          ),
        ),
      );
    } else {
      return Column(
        children: [
          Expanded(child: buildPainter()),
          buildBottom(),
        ],
      );
    }
  }

  Widget buildPainter() {
    /// Use AnimatedBuilder to update the painter in 60 fps:
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        /// Extract bricks that should be drawn base on music position:
        /// Then remove the extracted bricks from allBrick list.
        int counter = 0;
        for (var item in _allBricks) {
          int position = item.position;
          int currentPos = _player.position.position!.inMilliseconds;

          if (position - currentPos <= item.fallTime) {
            _drawingBricks.add(item);
            counter += 1;
          }
        }
        _allBricks.removeRange(0, counter);

        /// Remove bricks that are out of screen:
        counter = 0;
        for (var item in _drawingBricks) {
          if (item.y > _screenHeight) {
            counter += 1;
          }
        }
        _drawingBricks.removeRange(0, counter);

        return CustomPaint(
          painter: BrickPainter(_drawingBricks),
          child: Container(constraints: BoxConstraints.expand()),
        );
      },
    );
  }

  Widget buildBottom() {
    return Row(
      children: [
        Expanded(
            flex: 1,
            child: IconButton(
              onPressed: () {
                if (_player.playback.isPlaying) {
                  _player.seek(Duration(milliseconds: 0));
                  _player.pause();
                  setState(() {});
                } else {
                  prepareBricks(_screenWidth);
                  _countdownEndTime = DateTime.now().millisecondsSinceEpoch +
                      _countdownInterval;
                  setState(() => stage = stageCountdown);
                }
              },
              icon: _player.playback.isPlaying
                  ? Icon(Icons.replay)
                  : Icon(Icons.play_arrow),
            )),
        Expanded(
          flex: 15,
          child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                double value = _player.position.position!.inMilliseconds /
                    _player.position.duration!.inMilliseconds;

                if (_player.position.position != null && !value.isNaN) {
                  return LinearProgressIndicator(value: value);
                } else {
                  return LinearProgressIndicator(value: 0);
                }
              }),
        ),
        Expanded(
            flex: 1,
            child: Center(
              child: StreamBuilder<PositionState>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final df = DateFormat('mm:ss');
                      final position = snapshot.data!.position!.inMilliseconds;
                      String elapsed = df.format(
                          DateTime.fromMillisecondsSinceEpoch(position));

                      return Text(elapsed);
                    } else {
                      return Text('0:00');
                    }
                  }),
            )),
        Expanded(
          flex: 1,
          child: IconButton(
            onPressed: () => setState(() {
              _mute = !_mute;
              _mute ? _player.setVolume(0) : _player.setVolume(_volume);
            }),
            icon: Icon(_mute ? Icons.volume_off_sharp : Icons.volume_up_sharp),
          ),
        ),
      ],
    );
  }
}

class BrickPainter extends CustomPainter {
  final List<Brick> _bricks;

  BrickPainter(this._bricks);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    paint.style = PaintingStyle.fill;
    paint.color = Colors.red;
    paint.strokeWidth = 3;

    double lineY = size.height * 0.9;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), paint);

    for (var brick in _bricks) {
      brick.fallTo(lineY);
      final rect = Rect.fromLTWH(brick.x, brick.y, brick.width, brick.height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(BrickPainter oldDelegate) => true;
}

class Brick {
  final String content;
  final int position;
  final double x;
  double y;
  final double width;
  final double height;
  final Color color;

  final double fallTime = 1000;

  Brick(
    this.content,
    this.position,
    this.x,
    this.y,
    this.width,
    this.height,
    this.color,
  );

  void fallTo(double destination) {
    /// AnimationBuilder used above will run 60 fps
    /// Assume top-to-bottom (distance) = 600 units
    /// if falling takes 1000 ms, then every frame falls by 600 / 60 = 10 units units/frame (velocity).
    /// if falling takes 500 ms, then it should double the velocity (600 / 30 = 20 units/frame)/
    /// where 30 = 60fps * (falltime / 1000ms)
    double velocity = destination / (60 * (fallTime / 1000));
    y += velocity;
  }
}
