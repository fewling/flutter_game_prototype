// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game_prototype/level_files_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class BeatRecorder extends StatefulWidget {
  const BeatRecorder({Key? key}) : super(key: key);

  @override
  State<BeatRecorder> createState() => _BeatRecorderState();
}

class _BeatRecorderState extends State<BeatRecorder> {
  String? _selectedDirectory;
  String? _savesDirectory;

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

  Future<int>? _processExitCodeFuture;

  @override
  void initState() {
    super.initState();

    _initSavesDirectory();

    _player.setVolume(_volume);

    _player.positionStream.listen((positionState) {
      if (positionState.position != null) {
        _currentPosition = positionState.position!.inMilliseconds.toDouble();
      }
    });

    _player.playbackStream.listen((event) {
      if (event.isCompleted) saveFile();
    });
  }

  @override
  Widget build(BuildContext context) {
    keyAreaFocusNode.requestFocus();

    return Scaffold(
      body: RawKeyboardListener(
        focusNode: keyAreaFocusNode,
        autofocus: true,
        onKey: (rawkeyEvent) {
          // pop screen if pressed esc key
          if (rawkeyEvent.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context, true);
          }

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
        child: soundFilesPaths.isEmpty
            ? Center(
                child: OutlinedButton(
                  onPressed: () => pickMusicFolder(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(width: 5.0, color: Colors.teal),
                  ),
                  child: Text(
                    "Pick a music folder",
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
              )
            : GestureDetector(
                onTap: () => keyAreaFocusNode.requestFocus(),
                child: Column(
                  children: [
                    Flexible(child: buildPlaylist()),
                    // buildPressedKeyList(context),
                    _processExitCodeFuture == null
                        ? Container()
                        : FutureBuilder<int>(
                            future: _processExitCodeFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                return snapshot.data == 0
                                    ? Text('Success')
                                    : Text('Error');
                              } else {
                                return CircularProgressIndicator();
                              }
                            },
                          ),
                    RepaintBoundary(child: buildPlaybackButtons()),
                    RepaintBoundary(child: buildProgressBar()),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.clear),
        onPressed: () => setState(
          () => _pressedKeys.clear(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyStreamController.close();
    _keyScrollController.dispose();
    keyAreaFocusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  ListView buildPlaylist() {
    return ListView.builder(
      itemCount: soundFilesPaths.length,
      itemBuilder: (context, index) {
        return ListTile(
            leading: Icon(Icons.music_note),
            title: Text(
              Platform.isWindows
                  ? soundFilesPaths[index].split('\\').last
                  : soundFilesPaths[index].split('/').last,
              style: TextStyle(fontFamily: "Roboto"),
            ),
            tileColor: playingFile == soundFilesPaths[index]
                ? Colors.green
                : Colors.transparent,
            onTap: () async {
              playingFile = soundFilesPaths[index];

              File file = File(soundFilesPaths[index]);

              Process.start('.\\main.exe', [file.path, _savesDirectory!])
                  .then((value) => _processExitCodeFuture = value.exitCode);

              Media media0 = Media.file(file);
              _player.open(media0);
              _player.play();
              setState(() {});
            });
      },
    );
  }

  Widget buildPressedKeyList(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      height: 100,
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
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: keyBgColors[index % keyBgColors.length],
                    ),
                    child: Text(
                      '$keyName (${duration.inMilliseconds}ms)',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontFamily: "Roboto",
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
        if (snapshot.hasData) playbackState = snapshot.data;

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
              max: positionState.duration!.inMilliseconds.toDouble() + 1.0,
              onChanged: (value) async {
                _currentPosition = value;
                setState(() {});

                _player.seek(Duration(milliseconds: value.toInt()));
              },
            );
          }
        }
        return SizedBox();
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

    final Map<String, dynamic> json = {"file": playingFile};

    List<Map<String, int>> keyList = [];
    for (var item in _pressedKeys) {
      final duration = item.keys.first;

      final key = duration.inMilliseconds;
      final keyName = item.values.first;

      Map<String, int> map = {keyName: key};
      keyList.add(map);
    }
    json["pressed_keys"] = keyList;

    String songName = Platform.isWindows
        ? playingFile.split('\\').last.split('.').first
        : playingFile.split('/').last.split('.').first;

    String fileName = songName +
        " " +
        DateTime.now().toString().replaceAll(':', '-').split('.')[0];

    String filePath = Platform.isWindows
        ? '$_savesDirectory\\$fileName.json'
        : '$_savesDirectory/$fileName.json';

    File file = await File(filePath).create(recursive: true);

    await file
        .writeAsString(jsonEncode(json))
        .then((_) => _pressedKeys.clear());
    setState(() {});
  }

  Future<void> _initSavesDirectory() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    _savesDirectory = "$appDocPath\\flutter_game_prototype";
  }
}
