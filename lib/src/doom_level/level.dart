import 'dart:typed_data';
import '../wad_data.dart';
import 'element.dart';

class Level {
  var things = <Thing>[];
  var vertices = <Vertex>[];
  var sectors = <Sector>[];
  var sidedefs = <Sidedef>[];
  var linedefs = <Linedef>[];

  Level();

  Level.fromWad(WadData wadData, String levelName) {
    final levelLump = wadData.getLump(levelName);
    if (levelLump == null) {
      return;
    }

    final levelIndex = wadData.lumps.indexOf(levelLump);
    if (levelIndex == -1) {
      return;
    }

    _loadThings(wadData, levelIndex + 1);
    _loadVertices(wadData, levelIndex + 4);
    _loadSectors(wadData, levelIndex + 8);
    _loadSidedefs(wadData, levelIndex + 3);
    _loadLinedefs(wadData, levelIndex + 2);
  
    _cleanupUnusedVertices();
  }

  void _loadThings(WadData wadData, int lumpIndex) {
    if (lumpIndex >= wadData.lumps.length) {
      return;
    }
    final lump = wadData.lumps[lumpIndex];
    if (lump.name != 'THINGS') {
      return;
    }

    final data = lump.data;
    final byteData = ByteData.sublistView(data);

    for (int i = 0; i + 10 <= data.length; i += 10) {
      final thing = Thing()
        ..x = byteData.getInt16(i, Endian.little)
        ..y = byteData.getInt16(i + 2, Endian.little)
        ..angle = byteData.getInt16(i + 4, Endian.little)
        ..type = byteData.getInt16(i + 6, Endian.little)
        ..flags = byteData.getInt16(i + 8, Endian.little);
      things.add(thing);
    }
  }

  void _loadVertices(WadData wadData, int lumpIndex) {
    if (lumpIndex >= wadData.lumps.length) {
      return;
    }
    final lump = wadData.lumps[lumpIndex];
    if (lump.name != 'VERTEXES') {
      return;
    }

    final data = lump.data;
    final byteData = ByteData.sublistView(data);

    for (int i = 0; i + 4 <= data.length; i += 4) {
      final vertex = Vertex()
        ..x = byteData.getInt16(i, Endian.little)
        ..y = byteData.getInt16(i + 2, Endian.little);
      vertices.add(vertex);
    }
  }

  void _loadSectors(WadData wadData, int lumpIndex) {
    if (lumpIndex >= wadData.lumps.length) {
      return;
    }
    final lump = wadData.lumps[lumpIndex];
    if (lump.name != 'SECTORS') {
      return;
    }

    final data = lump.data;
    final byteData = ByteData.sublistView(data);

    for (int i = 0; i + 26 <= data.length; i += 26) {
      final sector = Sector()
        ..floorHeight = byteData.getInt16(i, Endian.little)
        ..ceilingHeight = byteData.getInt16(i + 2, Endian.little)
        ..floorTexture = _readTextureName(data, i + 4)
        ..ceilingTexture = _readTextureName(data, i + 12)
        ..lightLevel = byteData.getInt16(i + 20, Endian.little)
        ..special = byteData.getInt16(i + 22, Endian.little)
        ..tag = byteData.getInt16(i + 24, Endian.little);
      sectors.add(sector);
    }
  }

  void _loadSidedefs(WadData wadData, int lumpIndex) {
    if (lumpIndex >= wadData.lumps.length) {
      return;
    }
    final lump = wadData.lumps[lumpIndex];
    if (lump.name != 'SIDEDEFS') {
      return;
    }

    final data = lump.data;
    final byteData = ByteData.sublistView(data);

    for (int i = 0; i + 30 <= data.length; i += 30) {
      final sectorID = byteData.getInt16(i + 28, Endian.little);
      if(sectorID < 0 || sectorID >= sectors.length) {
        continue;
      }
      final sidedef = Sidedef(sector: sectors[sectorID])
        ..xOffset = byteData.getInt16(i, Endian.little)
        ..yOffset = byteData.getInt16(i + 2, Endian.little)
        ..upperTexture = _readTextureName(data, i + 4)
        ..lowerTexture = _readTextureName(data, i + 12)
        ..middleTexture = _readTextureName(data, i + 20);
      sidedefs.add(sidedef);
    }
  }

  void _loadLinedefs(WadData wadData, int lumpIndex) {
    if (lumpIndex >= wadData.lumps.length) {
      return;
    }
    final lump = wadData.lumps[lumpIndex];
    if (lump.name != 'LINEDEFS') {
      return;
    }

    final data = lump.data;
    final byteData = ByteData.sublistView(data);

    for (int i = 0; i + 14 <= data.length; i += 14) {
      final vertex1ID = byteData.getInt16(i, Endian.little);
      final vertex2ID = byteData.getInt16(i + 2, Endian.little);
      if(vertex1ID < 0 || vertex1ID >= vertices.length || vertex2ID < 0 || vertex2ID >= vertices.length) {
        continue;
      }
      final linedef = Linedef(vertex1: vertices[vertex1ID], vertex2: vertices[vertex2ID])
        ..flags = byteData.getInt16(i + 4, Endian.little)
        ..special = byteData.getInt16(i + 6, Endian.little)
        ..tag = byteData.getInt16(i + 8, Endian.little);

      final side1ID = byteData.getInt16(i + 10, Endian.little);
      final side2ID = byteData.getInt16(i + 12, Endian.little);
      if(side1ID >= 0 && side1ID < sidedefs.length) {
        linedef.sidedef1 = sidedefs[side1ID];
      }
      if(side2ID >= 0 && side2ID < sidedefs.length) {
        linedef.sidedef2 = sidedefs[side2ID];
      }
      linedefs.add(linedef);
    }
  }

  String _readTextureName(Uint8List data, int offset) {
    final nameBytes = data.sublist(offset, offset + 8);
    final nullIndex = nameBytes.indexOf(0);
    final actualNameBytes = nullIndex >= 0 ? nameBytes.sublist(0, nullIndex) : nameBytes;
    return String.fromCharCodes(actualNameBytes);
  }

  void _cleanupUnusedVertices() {
    for (int i = vertices.length - 1; i >= 0; i--) {
      if (vertices[i].linedefs.isNotEmpty) {
        break;
      }

      vertices.removeAt(i);
    }
  }
}
