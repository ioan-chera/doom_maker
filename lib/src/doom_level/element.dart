class Thing {
  int x = 0;
  int y = 0;
  int angle = 0;
  int type = 0;
  int flags = 0;
}

class Vertex {
  int x = 0;
  int y = 0;

  Set<Linedef> get linedefs => Set.unmodifiable(_linedefs);

  final _linedefs = <Linedef>{};
}

class Sector { 
  int floorHeight = 0;
  int ceilingHeight = 0;
  String floorTexture = "";
  String ceilingTexture = "";
  int lightLevel = 0;
  int special = 0;
  int tag = 0;

  Set<Linedef> get linedefs => Set.unmodifiable(_linedefs);

  final _linedefs = <Linedef>{};
  final _sidedefs = <Sidedef>{};
}

class Sidedef {
  Sidedef({ required Sector sector }) : _sector = sector {
    _sector._sidedefs.add(this);
  }

  Sector get sector => _sector;
  set sector(Sector value) {
    if(value == _sector) {
      return;
    }
    _sector._sidedefs.remove(this);
    _sector._linedefs.removeAll(_linedefs);
    _sector = value;
    _sector._sidedefs.add(this);
    _sector._linedefs.addAll(_linedefs);
  }

  Set<Linedef> get linedefs => Set.unmodifiable(_linedefs);

  int xOffset = 0;
  int yOffset = 0;
  String upperTexture = "-";
  String lowerTexture = "-";
  String middleTexture = "-";
  Sector _sector;

  final _linedefs = <Linedef>{};
}

class Linedef {
  Linedef({
    required Vertex vertex1,
    required Vertex vertex2,
  }) : _vertex1 = vertex1, _vertex2 = vertex2 {
    _vertex1._linedefs.add(this);
    _vertex2._linedefs.add(this);
  }

  Vertex get vertex1 => _vertex1;
  Vertex get vertex2 => _vertex2;
  set vertex1(Vertex value) {
    if(_vertex1 == value) {
      return;
    }
    _vertex1._linedefs.remove(this);
    _vertex1 = value;
    _vertex1._linedefs.add(this);
  }
  set vertex2(Vertex value) {
    if(_vertex2 == value) {
      return;
    }
    _vertex2._linedefs.remove(this);
    _vertex2 = value;
    _vertex2._linedefs.add(this);
  }

  Sidedef? get sidedef1 => _sidedef1;
  Sidedef? get sidedef2 => _sidedef2;
  set sidedef1(Sidedef? value) {
    if(_sidedef1 == value) {
      return;
    }
    if(_sidedef1 != null) {
      _sidedef1!._linedefs.remove(this);
      _sidedef1!._sector._linedefs.remove(this);
    }
    _sidedef1 = value;
    if(_sidedef1 != null) {
      _sidedef1!._linedefs.add(this);
      _sidedef1!._sector._linedefs.add(this);
    }
  }
  set sidedef2(Sidedef? value) {
    if(_sidedef2 == value) {
      return;
    }
    if(_sidedef2 != null) {
      _sidedef2!._linedefs.remove(this);
      _sidedef2!._sector._linedefs.remove(this);
    }
    _sidedef2 = value;
    if(_sidedef2 != null) {
      _sidedef2!._linedefs.add(this);
      _sidedef2!._sector._linedefs.add(this);
    }
  }

  Vertex _vertex1;
  Vertex _vertex2;
  int flags = 0;
  int special = 0;
  int tag = 0;
  Sidedef? _sidedef1;
  Sidedef? _sidedef2;
}
