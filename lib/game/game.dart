// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'brick.dart';

class Game extends StatefulWidget {
  const Game({Key? key}) : super(key: key);

  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> with SingleTickerProviderStateMixin {
  late Future<Directory> _savesDirFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Player _player = Player(id: 69420);

  Map<String, dynamic> _selectedJson = {};
  final double _volume = 0.3;
  bool _mute = false;

  final List<Brick> _allBricks = [];
  final List<Brick> _drawingBricks = [];

  late AnimationController _controller;

  String stage = "pick_song";
  final String stageReady = "ready";
  final String stageCountdown = "countdown";
  final String stageGame = "game";

  int _countdownEndTime = 0;
  final int _countdownInterval = 3000;

  double _screenWidth = 0;
  double _screenHeight = 0;

  final List<LogicalKeyboardKey> availableKeys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyL,
  ];

  final FocusNode _focusNode = FocusNode();

  final LinkedHashMap<String, int> scores = {
    "perfect": 0,
    "good": 0,
    "bad": 0,
    "missed": 0,
  } as LinkedHashMap<String, int>;

  final double gravity = 0.1;
  final double accelerate = 0.5;
  final Map<String, double> _keyVelocities = {
    "A": -0.1,
    "S": -0.1,
    "D": -0.1,
    "J": -0.1,
    "K": -0.1,
    "L": -0.1,
  };
  final Map<String, double> _keyProgresses = {
    "A": 0,
    "S": 0,
    "D": 0,
    "J": 0,
    "K": 0,
    "L": 0,
  };

  @override
  void initState() {
    _controller =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    _controller.repeat();

    _player.setVolume(_volume);
    _savesDirFuture = getApplicationDocumentsDirectory();

    _player.playbackStream.listen((event) {
      if (event.isCompleted) {
        // TODO: handle end of level

        scores.forEach((key, _) => scores[key] = 0);

        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("Song completed!"),
                content: Text(scores.toString()),
                actions: <Widget>[
                  TextButton(
                    child: Text("OK"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            });
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _focusNode.requestFocus();

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (keyEvent) {
        for (var keyboardKey in availableKeys) {
          if (keyEvent.isKeyPressed(keyboardKey)) {
            String label = keyboardKey.keyLabel.toUpperCase();
            _keyVelocities[label] = _keyVelocities[label]! + accelerate;

            for (var i = 0; i < _drawingBricks.length; i++) {
              Brick brick = _drawingBricks[i];

              if (brick.content == label) {
                double remainedDist = brick.remainingDist() / brick.totalDist;

                print(remainedDist);

                if (remainedDist <= 0.3) {
                  scores['perfect'] = scores['perfect']! + 1;
                } else if (remainedDist <= 0.5) {
                  scores['good'] = scores['good']! + 1;
                } else {
                  scores['bad'] = scores['bad']! + 1;
                }
                // print('$remainedDist ${brick.result}');
                _drawingBricks.removeAt(i);
                break;
              }
            }
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppbar(),
        endDrawer: _buildEndDrawer(_screenWidth),
        body: _buildBodies(),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _controller.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppbar() {
    return AppBar(
      leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_outlined)),
      actions: [
        IconButton(
          icon: Icon(Icons.playlist_play_sharp),
          onPressed: () => _scaffoldKey.currentState!.openEndDrawer(),
        ),
      ],
    );
  }

  Drawer _buildEndDrawer(double screenWidth) {
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

                      _prepareAllBricks(screenWidth);

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

  void _prepareAllBricks(double screenWidth) {
    _allBricks.clear();
    List pressedKeys = _selectedJson['pressed_keys'];
    for (var item in pressedKeys) {
      String key = item.keys.first;
      int pos = item.values.first;

      double x = 0;
      switch (key) {
        case 'A':
          x = 0;
          break;
        case 'S':
          x = _screenWidth / 6;
          break;
        case 'D':
          x = _screenWidth / 6 * 2;
          break;
        case 'J':
          x = _screenWidth / 6 * 3;
          break;
        case 'K':
          x = _screenWidth / 6 * 4;
          break;
        case 'L':
          x = _screenWidth / 6 * 5;
          break;
      }

      final brick = Brick(
          key.toUpperCase(), pos, x, 0, screenWidth / 6, 20, Colors.white);
      _allBricks.add(brick);
    }
  }

  Widget _buildBodies() {
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
          Expanded(child: _buildGame()),
          _buildKeyboard(),
          SizedBox(height: 20),
          _buildBottom(),
        ],
      );
    }
  }

  Widget _buildKeyboard() {
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            children: List.generate(
              availableKeys.length,
              (index) {
                String key = availableKeys[index].keyLabel;

                _keyVelocities[key] = _keyVelocities[key]! - gravity;
                _keyProgresses[key] =
                    _keyProgresses[key]! + _keyVelocities[key]!;

                // constrain progress between 0 ~ 1:
                if (_keyProgresses[key]! > 1) {
                  _keyProgresses[key] = 1;
                } else if (_keyProgresses[key]! < 0) {
                  _keyProgresses[key] = 0;
                }

                if (_keyVelocities[key]! > 1) {
                  _keyVelocities[key] = 1;
                } else if (_keyVelocities[key]! < -0.1) {
                  _keyVelocities[key] = -0.1;
                }

                return Expanded(
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) => LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.red, Colors.white],
                        stops: [
                          _keyProgresses[availableKeys[index].keyLabel]!,
                          0.0
                        ],
                      ).createShader(bounds),
                      child: Text(
                        availableKeys[index].keyLabel,
                        style: TextStyle(
                            fontSize: _screenWidth * 0.03, color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        });
  }

  Widget _buildGame() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            ..._buildFallingBricks(),

            /// Draw the detination line indicator:
            Positioned(
              bottom: _screenHeight * 0.05,
              child: Container(
                color: Colors.redAccent,
                height: 10,
                width: _screenWidth,
              ),
            ),

            /// Draw the score:
            Positioned(
              top: _screenHeight * 0.02,
              right: _screenWidth * 0.02,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  scores.length,
                  (index) {
                    String key = scores.keys.elementAt(index);
                    return Row(
                      children: [
                        Text("$key x "),
                        SizedBox(width: 5),
                        Text(scores[key].toString()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildFallingBricks() {
    /// Extract bricks that should be drawn base on music position:
    /// Then remove the extracted bricks from allBrick list.
    int counter = 0;
    for (var brick in _allBricks) {
      int position = brick.position;
      int currentPos = _player.position.position!.inMilliseconds;

      if (position - currentPos <= brick.fallTime) {
        _drawingBricks.add(brick);
        counter += 1;
      }
    }
    _allBricks.removeRange(0, counter);

    /// Remove bricks that are out of screen:
    List<Brick> bricksToRemove = [];
    for (var item in _drawingBricks) {
      if (item.isOutOfScreen) {
        bricksToRemove.add(item);
        scores['missed'] = scores['missed']! + 1;
      }
    }
    for (var element in bricksToRemove) {
      _drawingBricks.remove(element);
    }

    /// Make bricks fall:
    for (var brick in _drawingBricks) {
      brick.fallTo(_screenHeight * 0.95);
    }

    return List.generate(
      _drawingBricks.length,
      (index) => Positioned(
        left: _drawingBricks[index].x,
        top: _drawingBricks[index].y - _drawingBricks[index].height,
        child: _drawingBricks[index],
      ),
    );
  }

  Widget _buildBottom() {
    return Row(
      children: [
        Expanded(
            flex: 1,
            child: TextButton(
              onPressed: () {
                if (_player.playback.isPlaying) {
                  _player.seek(Duration(milliseconds: 0));
                  _player.pause();
                  setState(() {});
                } else {
                  _prepareAllBricks(_screenWidth);
                  _countdownEndTime = DateTime.now().millisecondsSinceEpoch +
                      _countdownInterval;
                  setState(() => stage = stageCountdown);
                }
              },
              child: _player.playback.isPlaying
                  ? Icon(Icons.replay)
                  : Icon(Icons.play_arrow),
              style: TextButton.styleFrom(primary: Colors.white),
            )),
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
                      String total = df.format(
                          DateTime.fromMillisecondsSinceEpoch(
                              _player.position.duration!.inMilliseconds));

                      return Text('$elapsed/$total');
                    } else {
                      return Text('0:00');
                    }
                  }),
            )),
        Expanded(
          flex: 1,
          child: TextButton(
            onPressed: () => setState(() {
              _mute = !_mute;
              _mute ? _player.setVolume(0) : _player.setVolume(_volume);
            }),
            child: Icon(_mute ? Icons.volume_off_sharp : Icons.volume_up_sharp),
            style: TextButton.styleFrom(primary: Colors.white),
          ),
        ),
      ],
    );
  }
}
