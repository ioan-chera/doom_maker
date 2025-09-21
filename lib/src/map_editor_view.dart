import 'doom_level/level.dart';
import 'map_painter.dart';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class MapEditorView extends StatefulWidget {
  final String? filePath;
  final Level level;

  static const routeName = '/map';

  const MapEditorView({
    super.key,
    this.filePath,
    required this.level,
  });

  @override
  State<MapEditorView> createState() => _MapEditorViewState();
}

class _MapEditorViewState extends State<MapEditorView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath != null ? path.basenameWithoutExtension(widget.filePath!) : "(untitled)"),
      ),
      body: CustomPaint(
        painter: MapPainter(
          level: widget.level,
        ),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: GestureDetector(
            onTapDown: (details) {
              print('Tap at: ${details.localPosition}');
            },
            onPanUpdate: (details) {
              print('Pan update: ${details.localPosition}');
            },
          )
        )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context, 
            builder: (context) => SizedBox(
              height: 200,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.brush),
                    title: const Text('Draw Tool'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.crop_square),
                    title: const Text('Select Tool'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Erase Tool'),
                    onTap: () => Navigator.pop(context),
                  )
                ]
              )
            )
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}
