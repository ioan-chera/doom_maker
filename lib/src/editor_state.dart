import 'doom_level/edit_mode.dart';
import 'doom_level/level.dart';
import 'doom_level/element.dart';

class EditorState {
  EditorState({
    required this.level
  });

  EditMode get mode => _mode;
  set mode(EditMode value) {
    
    final current = _mode;
    if(current == value) {
      return;
    }
    switch(current) {
      case EditMode.vertex:
        _setSelectionFromVertices(value);
      case EditMode.linedef:
        _setSelectionFromLinedefs(value);
      case EditMode.sector:
        _setSelectionFromSectors(value);
      case EditMode.thing:
        // TODO
    }

    // Update selection
    _mode = value;
  }

  void _setSelectionFromVertices(EditMode target) {
    if(selectedVertices.isEmpty) {
      return;
    }
    
    switch(target) {
      case EditMode.vertex:
        return;
      case EditMode.linedef:
        selectedLinedefs.clear();
        for(final linedef in level.linedefs) {
          if(selectedVertices.contains(linedef.vertex1) && selectedVertices.contains(linedef.vertex2)) {
            selectedLinedefs.add(linedef);
          }
        }
      case EditMode.sector:
        _setSelectionFromVertices(EditMode.linedef);
        _setSelectionFromLinedefs(target);
      case EditMode.thing:
        _setSelectionFromVertices(EditMode.linedef);
        _setSelectionFromLinedefs(EditMode.sector);
        _setSelectionFromSectors(target);
    }
  }

  void _setSelectionFromLinedefs(EditMode target) {
    if(selectedLinedefs.isEmpty) {
      return;
    }
    switch(target) {
      case EditMode.vertex:
        selectedVertices.clear();
        for(final linedef in selectedLinedefs) {
          selectedVertices.add(linedef.vertex1);
          selectedVertices.add(linedef.vertex2);
        }
      case EditMode.linedef:
        return;
      case EditMode.sector:
        selectedSectors.clear();
        for(final sector in level.sectors) {
          if(selectedLinedefs.containsAll(sector.linedefs)) {
            selectedSectors.add(sector);
          }
        }
      case EditMode.thing:
        _setSelectionFromLinedefs(EditMode.sector);
        _setSelectionFromSectors(target);
    }
  }

  void _setSelectionFromSectors(EditMode target) {
    if(selectedSectors.isEmpty) {
      return;
    }
    switch(target) {
      case EditMode.vertex:
        _setSelectionFromSectors(EditMode.linedef);
        _setSelectionFromLinedefs(target);
      case EditMode.linedef:
        selectedLinedefs.clear();
        for(final sector in selectedSectors) {
          selectedLinedefs.addAll(sector.linedefs);
        }
      case EditMode.sector:
        return;
      case EditMode.thing:
        // TODO: nanobsp
    }
  }

  final Level level;
  var panning = (x: 0.0, y: 0.0);
  var scale = 1.0;
  var grid = 64;
  var _mode = EditMode.vertex;
  var selectedThings = <Thing>{};
  var selectedVertices = <Vertex>{};
  var selectedSectors = <Sector>{};
  var selectedLinedefs = <Linedef>{};
  var highlighted = -1;  
}
