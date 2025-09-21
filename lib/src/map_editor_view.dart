import 'map_painter.dart';

import 'package:flutter/material.dart';

class MapEditorView extends StatefulWidget {
  final String fileName;

  static const routeName = '/map';

  const MapEditorView({
    super.key,
    required this.fileName,
  });

  @override
  State<MapEditorView> createState() => _MapEditorViewState();
}

class _MapEditorViewState extends State<MapEditorView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () { Navigator.of(context).pop(); },
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {},
            tooltip: 'Open',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () {},
            tooltip: 'Save',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('File Info'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('File: ${widget.fileName}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    )
                  ]
                )
              );
            }
          )
        ]
      ),
      body: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 10.0,
        child: CustomPaint(
          painter: MapPainter(
            fileName: widget.fileName,
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
