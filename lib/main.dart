// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  DartVLC.initialize();
  runApp(MaterialApp(
    home: Home(),
    theme: ThemeData.dark(),
  ));
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final Player _player = Player(id: 69420);
  double _currentPosition = 0;
  String _mediaFileName = '';

  final List<LogicalKeyboardKey> availableKeys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyL,
  ];
  final List<Color> keyBgColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
  ];

  final FocusNode keyAreaFocusNode = FocusNode();
  final FocusNode progressBarFocusNode = FocusNode();

  final List<Map<Duration, String>> _pressedKeys = [];
  final ScrollController _keyScrollController = ScrollController();
  final StreamController<Map<Duration, String>> _keyStreamController =
      StreamController();

  @override
  void initState() {
    super.initState();

    _player.positionStream.listen((positionState) {
      if (positionState.position != null) {
        _currentPosition = positionState.position!.inMilliseconds.toDouble();
      }
    });

    _player.playbackStream.listen((event) {
      if (event.isCompleted) {
        saveFile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          buildPressedKeyList(context),
          buildKeyContainers(),
          buildPlaybackButtons(),
          buildProgressBar(),
        ],
      ),
      floatingActionButton: buildFab(context),
    );
  }

  SizedBox buildPressedKeyList(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: StreamBuilder<Map<Duration, String>>(
            stream: _keyStreamController.stream,
            builder: (context, snapshot) {
              return ListView.builder(
                controller: _keyScrollController,
                physics: BouncingScrollPhysics(),
                itemCount: _pressedKeys.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final Map<Duration, String> key = _pressedKeys[index];
                  final Duration duration = key.keys.first;
                  final String keyName = key[duration]!;

                  return Container(
                    margin: EdgeInsets.all(5),
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: keyBgColors[index % keyBgColors.length],
                    ),
                    child: Text(
                      '$keyName (${duration.inMilliseconds}ms)',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              );
            }),
      ),
    );
  }

  Widget buildKeyContainers() {
    return Expanded(
      child: GestureDetector(
        onTap: () => keyAreaFocusNode.requestFocus(),
        child: RawKeyboardListener(
          focusNode: keyAreaFocusNode,
          autofocus: true,
          onKey: (rawkeyEvent) {
            if (_player.playback.isPlaying) {
              for (var keyboardKey in availableKeys) {
                if (rawkeyEvent.isKeyPressed(keyboardKey)) {
                  Map<Duration, String> map = {
                    Duration(milliseconds: _currentPosition.toInt()):
                        rawkeyEvent.logicalKey.keyLabel,
                  };

                  _pressedKeys.add(map);
                  _keyStreamController.add(map);
                  _keyScrollController
                      .jumpTo(_keyScrollController.position.maxScrollExtent);
                }
              }
            }
          },
          child: Row(
            children: List.generate(availableKeys.length, (index) {
              return Expanded(
                child: Container(
                  height: double.infinity,
                  color: keyBgColors[index],
                  child: Center(
                    child: Text(
                      availableKeys[index].keyLabel,
                      style: TextStyle(fontSize: 100),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  StreamBuilder<PlaybackState> buildPlaybackButtons() {
    return StreamBuilder(
      stream: _player.playbackStream,
      builder: (context, snapshot) {
        PlaybackState? playbackState;
        if (snapshot.hasData) {
          playbackState = snapshot.data;
        }

        return Row(
          children: [
            SizedBox(width: 8),
            Text(
              playbackState == null ? '' : _mediaFileName,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 16),
            IconButton(
              onPressed: playbackState == null
                  ? null
                  : () => playbackState!.isPlaying
                      ? _player.pause()
                      : _player.play(),
              icon: playbackState == null || playbackState.isPlaying
                  ? Icon(Icons.pause)
                  : Icon(Icons.play_arrow),
            ),
            SizedBox(width: 16),
            IconButton(
              onPressed: () {
                print(_pressedKeys);
              },
              icon: Icon(Icons.volume_up_sharp),
            ),
          ],
        );
      },
    );
  }

  StreamBuilder<PositionState> buildProgressBar() {
    return StreamBuilder(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final positionState = snapshot.data as PositionState;
          if (positionState.position != null) {
            return Slider(
              focusNode: progressBarFocusNode,
              value: _currentPosition,
              min: 0,
              max: positionState.duration!.inMilliseconds.toDouble(),
              onChanged: (value) async {
                _currentPosition = value;
                setState(() {});

                _player.seek(Duration(milliseconds: value.toInt()));
              },
            );
          }
        }

        return Text('Select a music file');
      },
    );
  }

  FloatingActionButton buildFab(BuildContext context) {
    return FloatingActionButton(
      child: Icon(Icons.music_note),
      onPressed: () async {
        FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: FileType.audio);

        if (result != null) {
          File file = File(result.files.single.path!);
          _mediaFileName = file.path.split('\\').last;

          Media media0 = Media.file(file);
          _player.open(media0);
          _player.play();
        }
      },
    );
  }

  Future<void> saveFile() async {
    if (_pressedKeys.isEmpty) return;

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    List<Map<int, String>> list = [];

    for (var item in _pressedKeys) {
      final duration = item.keys.first;

      final key = duration.inMilliseconds;
      final keyName = item.values.first;

      Map<int, String> map = {key: keyName};
      list.add(map);
    }

    String fileName =
        DateTime.now().toString().replaceAll(':', '-').split('.')[0];

    File file = await File('$appDocPath\\flutter_game_prototype\\$fileName.txt')
        .create(recursive: true);

    file.writeAsString(list.toString()).then((_) => _pressedKeys.clear());
  }
}
