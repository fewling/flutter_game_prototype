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
  String? _selectedDirectory;

  List<String> soundFilesPaths = [];
  List<String> supportedFormat = ['mp3', 'wav', 'flac', 'ogg', 'm4a'];

  final Player _player = Player(id: 69420);
  String playingFile = '';
  double _volume = 0.3;
  bool _mute = false;
  double _currentPosition = 0;

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

  final List<Map<Duration, String>> _pressedKeys = [];
  final ScrollController _keyScrollController = ScrollController();
  final StreamController<Map<Duration, String>> _keyStreamController =
      StreamController();

  @override
  void initState() {
    super.initState();

    _player.setVolume(_volume);

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
    return RawKeyboardListener(
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
      child: Scaffold(
        body: GestureDetector(
          onTap: () => keyAreaFocusNode.requestFocus(),
          child: Column(
            children: [
              Flexible(
                child: soundFilesPaths.isEmpty
                    ? Center(
                        child: TextButton(
                            onPressed: () => pickMusicFolder(),
                            child: Text("Pick a music folder")),
                      )
                    : ListView.builder(
                        itemCount: soundFilesPaths.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                              leading: Icon(Icons.music_note),
                              title: Text(Platform.isWindows
                                  ? soundFilesPaths[index].split('\\').last
                                  : soundFilesPaths[index].split('/').last),
                              tileColor: playingFile == soundFilesPaths[index]
                                  ? Colors.green
                                  : Colors.transparent,
                              onTap: () {
                                playingFile = soundFilesPaths[index];

                                File file = File(soundFilesPaths[index]);
                                Media media0 = Media.file(file);
                                _player.open(media0);
                                _player.play();
                                setState(() {});
                              });
                        },
                      ),
              ),
              buildPressedKeyList(context),
              buildPlaybackButtons(),
              buildProgressBar(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.clear),
          onPressed: () => setState(
            () => _pressedKeys.clear(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyStreamController.close();
    _keyScrollController.dispose();
    keyAreaFocusNode.dispose();
    super.dispose();
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
              onPressed: () => setState(() {
                _mute = !_mute;

                _mute ? _player.setVolume(0) : _player.setVolume(_volume);
              }),
              icon:
                  Icon(_mute ? Icons.volume_off_sharp : Icons.volume_up_sharp),
            ),
            Slider(
              value: _volume,
              min: 0,
              max: 1,
              onChanged: (value) {
                _player.setVolume(value);
                _volume = value;
                setState(() {});
              },
            ),
            Text((_volume * 100.0).toStringAsFixed(0) + '%'),
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

  Future<void> pickMusicFolder() async {
    _selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select folder where you store your music files",
      lockParentWindow: true,
    );

    if (_selectedDirectory != null) {
      soundFilesPaths.clear();
      Directory directory = Directory(_selectedDirectory!);
      await _fetchFiles(directory);
      setState(() {});
    }
  }

  _fetchFiles(Directory directory) async {
    final List<FileSystemEntity> entities = await directory.list().toList();

    for (var item in entities) {
      if (item is Directory) {
        _fetchFiles(item);
      } else if (item is File) {
        final String fileName = item.path.split('/').last;
        final String fileExtension = fileName.split('.').last.toLowerCase();

        if (supportedFormat.contains(fileExtension)) {
          if (!soundFilesPaths.contains(fileName)) {
            soundFilesPaths.add(item.path);
          }
        }
      }
    }
    setState(() {});
  }

  Future<void> saveFile() async {
    if (_pressedKeys.isEmpty) return;

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    List<Map<String, dynamic>> list = [];

    list.add({"file": playingFile});

    for (var item in _pressedKeys) {
      final duration = item.keys.first;

      final key = duration.inMilliseconds;
      final keyName = item.values.first;

      Map<String, int> map = {keyName: key};
      list.add(map);
    }

    String songName = Platform.isWindows
        ? playingFile.split('\\').last.split('.').first
        : playingFile.split('/').last.split('.').first;

    String fileName = songName +
        " " +
        DateTime.now().toString().replaceAll(':', '-').split('.')[0];

    File file =
        await File('$appDocPath\\flutter_game_prototype\\$fileName.json')
            .create(recursive: true);

    // await file.writeAsString(list.toString()).then((_) => _pressedKeys.clear());
    await file
        .writeAsString(jsonEncode(list))
        .then((_) => _pressedKeys.clear());
    setState(() {});
  }
}
