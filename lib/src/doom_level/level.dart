import 'dart:typed_data';
import '../wad_data.dart';
import 'linedef.dart';
import 'sector.dart';
import 'sidedef.dart';
import 'thing.dart';
import 'vertex.dart';

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
    _loadLinedefs(wadData, levelIndex + 2);
    _loadSidedefs(wadData, levelIndex + 3);
    _loadVertices(wadData, levelIndex + 4);
    _loadSectors(wadData, levelIndex + 8);

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
      final linedef = Linedef()
        ..v1 = byteData.getInt16(i, Endian.little)
        ..v2 = byteData.getInt16(i + 2, Endian.little)
        ..flags = byteData.getInt16(i + 4, Endian.little)
        ..special = byteData.getInt16(i + 6, Endian.little)
        ..tag = byteData.getInt16(i + 8, Endian.little)
        ..s1 = byteData.getInt16(i + 10, Endian.little)
        ..s2 = byteData.getInt16(i + 12, Endian.little);
      linedefs.add(linedef);
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
      final sidedef = Sidedef()
        ..xOffset = byteData.getInt16(i, Endian.little)
        ..yOffset = byteData.getInt16(i + 2, Endian.little)
        ..upperTexture = _readTextureName(data, i + 4)
        ..lowerTexture = _readTextureName(data, i + 12)
        ..middleTexture = _readTextureName(data, i + 20)
        ..sectorID = byteData.getInt16(i + 28, Endian.little);
      sidedefs.add(sidedef);
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

  String _readTextureName(Uint8List data, int offset) {
    final nameBytes = data.sublist(offset, offset + 8);
    final nullIndex = nameBytes.indexOf(0);
    final actualNameBytes = nullIndex >= 0 ? nameBytes.sublist(0, nullIndex) : nameBytes;
    return String.fromCharCodes(actualNameBytes);
  }

  void _cleanupUnusedVertices() {
    var used = List<bool>.filled(vertices.length, false);
    for(final linedef in linedefs) {
      if(linedef.v1 >= 0 && linedef.v1 < vertices.length) {
        used[linedef.v1] = true;
      }
      if(linedef.v2 >= 0 && linedef.v2 < vertices.length) {
        used[linedef.v2] = true;
      }
    }

    for (int i = vertices.length - 1; i >= 0; i--) {
      if (used[i]) {
        break;
      }

      vertices.removeAt(i);
    }
  }
}
