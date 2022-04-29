import 'dart:collection';
import 'dart:io';

import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:flutter_game_prototype/game/brick.dart';
import 'package:intl/intl.dart';

class NewGameScreen extends StatefulWidget {
  final File musicFile;
  final List<Brick> allBricks;

  const NewGameScreen(this.allBricks, this.musicFile, {Key? key})
      : super(key: key);

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen>
    with SingleTickerProviderStateMixin {
  late List<Brick> _allBricks;

  final FocusNode _focusNode = FocusNode();

  final Player _player = Player(id: 123);
  double _volume = 0.3;
  bool _mute = false;

  late String stage;
  final String stageCountdown = "countdown";
  final String stageStart = "game";

  int _countdownEndTime = 0;
  final int _countdownInterval = 3000;

  late AnimationController _controller;

  final List<Brick> _drawingBricks = [];

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

  final List<LogicalKeyboardKey> availableKeys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyL,
  ];
  final Set<LogicalKeyboardKey> pressedKeys = {};

  bool _levelCompleted = false;
  bool _isPlaying = false;

  @override
  void initState() {
    _allBricks = cloneAllBricks();
    stage = stageCountdown;

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _controller.repeat();

    _countdownEndTime =
        DateTime.now().millisecondsSinceEpoch + _countdownInterval;

    Media media = Media.file(widget.musicFile);
    _player.open(media, autoStart: false);
    _player.setVolume(_volume);
    _player.playbackStream.listen((event) {
      setState(() => _isPlaying = event.isPlaying);

      if (event.isCompleted) {
        if (!_levelCompleted) {
          _levelCompleted = true;

          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text("Song completed!"),
                  content: Text(scores.toString()),
                  actions: <Widget>[
                    TextButton(
                      child: const Text("OK"),
                      onPressed: () {
                        scores.forEach((key, _) => scores[key] = 0);
                        _levelCompleted = false;
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              });
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    _focusNode.requestFocus();
    _player.setVolume(_volume);

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (keyEvent) {
        if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }

        if (keyEvent is RawKeyUpEvent) {
          if (pressedKeys.contains(keyEvent.logicalKey)) {
            pressedKeys.remove(keyEvent.logicalKey);
          }
        }

        for (var keyboardKey in availableKeys) {
          if (keyEvent.isKeyPressed(keyboardKey) &&
              !pressedKeys.contains(keyboardKey)) {
            pressedKeys.add(keyboardKey);
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
        body: stage == stageCountdown
            ? CountdownTimer(
                endTime: _countdownEndTime,
                onEnd: () {
                  setState(() => stage = stageStart);
                  _player.play();
                },
                widgetBuilder: (_, remainingTime) => Center(
                  child: Text(
                    remainingTime!.sec.toString(),
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(child: _buildGame(screenWidth, screenHeight)),
                  _buildKeyboard(screenWidth),
                  const SizedBox(height: 20),
                  _buildBottom(),
                ],
              ),
      ),
    );
  }

  Widget _buildGame(double screenWidth, double screenHeight) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            ..._buildFallingBricks(screenHeight),

            /// Draw the detination line indicator:
            Positioned(
              bottom: screenHeight * 0.05,
              child: Container(
                color: Colors.redAccent,
                height: 10,
                width: screenWidth,
              ),
            ),

            /// Draw the score:
            Positioned(
              top: screenHeight * 0.02,
              right: screenWidth * 0.02,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  scores.length,
                  (index) {
                    String key = scores.keys.elementAt(index);
                    return Row(
                      children: [
                        Text("$key x "),
                        const SizedBox(width: 5),
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

  List<Widget> _buildFallingBricks(double screenHeight) {
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
      brick.fallTo(screenHeight * 0.95);
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

  Widget _buildKeyboard(double screenWidth) {
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
                            fontSize: screenWidth * 0.03, color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        });
  }

  Widget _buildBottom() {
    return Row(
      children: [
        Expanded(
            flex: 1,
            child: TextButton(
              onPressed: () {
                if (_isPlaying) {
                  _player.seek(const Duration(milliseconds: 0));
                  _player.pause();

                  setState(() {});
                } else {
                  _allBricks = cloneAllBricks();

                  _countdownEndTime = DateTime.now().millisecondsSinceEpoch +
                      _countdownInterval;

                  scores.forEach((key, _) => scores[key] = 0);

                  stage = stageCountdown;

                  setState(() {});
                }
              },
              child: _isPlaying
                  ? const Icon(Icons.replay)
                  : const Icon(Icons.play_arrow),
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
                      return const Text('0:00');
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

  List<Brick> cloneAllBricks() {
    final List<Brick> bricks = [];
    for (var brick in widget.allBricks) {
      final b = Brick(
        brick.content,
        brick.position,
        brick.x,
        brick.y,
        brick.width,
        brick.height,
        brick.color,
      );
      bricks.add(b);
    }
    return bricks;
  }
}
