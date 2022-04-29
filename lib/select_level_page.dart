import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game_prototype/beats_recorder.dart';
import 'package:flutter_game_prototype/game/game.dart';
import 'package:path_provider/path_provider.dart';

import 'game/brick.dart';

class SelectLevelPage extends StatefulWidget {
  const SelectLevelPage({Key? key}) : super(key: key);

  @override
  State<SelectLevelPage> createState() => _SelectLevelPageState();
}

class _SelectLevelPageState extends State<SelectLevelPage> {
  List<FileSystemEntity>? _fileEntities;

  @override
  void initState() {
    _getLevelFiles();

    super.initState();
  }

  Future<void> _getLevelFiles() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    String savesDirectory = "$appDocPath\\flutter_game_prototype";
    Directory directory = Directory(savesDirectory);
    _fileEntities = directory.listSync(recursive: true);

    final List<FileSystemEntity> deleteFiles = [];

    for (var item in _fileEntities!) {
      if (item is File) {
        if (!item.path.endsWith('.json')) {
          deleteFiles.add(item);
        }
      }
    }

    for (var item in deleteFiles) {
      _fileEntities!.remove(item);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a level'),
      ),
      body: buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: Icon(Icons.arrow_back_ios_new_rounded),
      ),
    );
  }

  Widget buildBody() {
    if (_fileEntities == null) {
      return Center(child: CircularProgressIndicator());
    } else if (_fileEntities!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "You don't have any level files yet.",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 24),
            Text(
              "Tap the button below to create one.",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 48),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (context) => BeatRecorder()));
                _getLevelFiles();
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Create',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: ListView.separated(
        itemCount: _fileEntities!.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey),
        itemBuilder: (context, index) {
          File entity = _fileEntities![index] as File;

          String content = entity.readAsStringSync();
          Map<String, dynamic> json = jsonDecode(content);

          String filePath = json['file'];
          String fileName = Platform.isWindows
              ? filePath.split('\\').last
              : filePath.split('/').last;

          return ListTile(
            leading: Icon(Icons.music_note_outlined),
            title: Text(
              fileName,
              style: TextStyle(fontFamily: "Roboto", fontSize: 24),
            ),
            onTap: () {
              final allBricks =
                  _prepareAllBricks(MediaQuery.of(context).size.width, json);

              File file = File(filePath);

              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NewGameScreen(allBricks, file)));
            },
          );
        },
      ),
    );
  }

  List<Brick> _prepareAllBricks(double screenWidth, Map<String, dynamic> json) {
    final List<Brick> allBricks = [];

    List pressedKeys = json['pressed_keys'];

    for (var item in pressedKeys) {
      String key = item.keys.first;
      int pos = item.values.first;

      double x = 0;
      switch (key) {
        case 'A':
          x = 0;
          break;
        case 'S':
          x = screenWidth / 6;
          break;
        case 'D':
          x = screenWidth / 6 * 2;
          break;
        case 'J':
          x = screenWidth / 6 * 3;
          break;
        case 'K':
          x = screenWidth / 6 * 4;
          break;
        case 'L':
          x = screenWidth / 6 * 5;
          break;
      }

      final brick = Brick(
          key.toUpperCase(), pos, x, 0, screenWidth / 6, 20, Colors.white);
      allBricks.add(brick);
    }

    return allBricks;
  }
}
